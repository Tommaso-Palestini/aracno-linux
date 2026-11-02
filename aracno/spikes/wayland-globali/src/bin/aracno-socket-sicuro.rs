//! Crea un socket Wayland "etichettato" (wp_security_context_v1) per un filo:
//! chi si collega da lì è un client in sandbox, e il compositor gli nasconde i
//! protocolli privilegiati (come per Flatpak). Resta in vita finché il socket serve:
//! quando esce, il compositor smette di accettare nuove connessioni su quel socket.
//!
//! uso: aracno-socket-sicuro PERCORSO_SOCKET NOME_FILO
use std::os::unix::net::{UnixListener, UnixStream};
use wayland_client::protocol::wl_registry;
use wayland_client::{Connection, Dispatch, QueueHandle};
use wayland_protocols::wp::security_context::v1::client::{
    wp_security_context_manager_v1::WpSecurityContextManagerV1,
    wp_security_context_v1::WpSecurityContextV1,
};

#[derive(Default)]
struct Stato {
    gestore: Option<(u32, u32)>, // nome, versione del global
}

impl Dispatch<wl_registry::WlRegistry, ()> for Stato {
    fn event(s: &mut Self, _: &wl_registry::WlRegistry, e: wl_registry::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_registry::Event::Global { name, interface, version } = e {
            if interface == "wp_security_context_manager_v1" {
                s.gestore = Some((name, version));
            }
        }
    }
}
impl Dispatch<WpSecurityContextManagerV1, ()> for Stato {
    fn event(_: &mut Self, _: &WpSecurityContextManagerV1, _: <WpSecurityContextManagerV1 as wayland_client::Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}
impl Dispatch<WpSecurityContextV1, ()> for Stato {
    fn event(_: &mut Self, _: &WpSecurityContextV1, _: <WpSecurityContextV1 as wayland_client::Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

/// Con PrivateUsers=pick il filo si collega come un utente mappato (UID alto), non come
/// noi: il socket deve essere scrivibile da "altri". È sicuro solo se la cartella che lo
/// contiene è privata (0700, come /run/user/UID): sull'host nessun altro utente ci arriva,
/// il filo sì perché il socket gli viene montato direttamente. Altrimenti non si allarga.
fn apri_al_filo(percorso: &str) {
    use std::os::unix::fs::PermissionsExt;
    let cartella = std::path::Path::new(percorso).parent().unwrap_or(std::path::Path::new("/"));
    let privata = std::fs::metadata(cartella)
        .map(|m| m.permissions().mode() & 0o077 == 0)
        .unwrap_or(false);
    if !privata {
        eprintln!("{} non è privata (0700): permessi del socket lasciati come sono", cartella.display());
        return;
    }
    if let Err(e) = std::fs::set_permissions(percorso, std::fs::Permissions::from_mode(0o777)) {
        eprintln!("permessi del socket: {e}");
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (percorso, filo) = match args.as_slice() {
        [_, p, f] => (p.clone(), f.clone()),
        _ => {
            eprintln!("uso: aracno-socket-sicuro PERCORSO_SOCKET NOME_FILO");
            std::process::exit(2);
        }
    };
    let conn = Connection::connect_to_env().expect("nessun compositor raggiungibile");
    let mut coda = conn.new_event_queue();
    let qh = coda.handle();
    let registro = conn.display().get_registry(&qh, ());
    let mut stato = Stato::default();
    coda.roundtrip(&mut stato).expect("roundtrip");
    let Some((nome, versione)) = stato.gestore else {
        eprintln!("il compositor non offre wp_security_context_manager_v1");
        std::process::exit(1);
    };
    let gestore: WpSecurityContextManagerV1 = registro.bind(nome, versione.min(1), &qh, ());

    let _ = std::fs::remove_file(&percorso);
    let ascolto = UnixListener::bind(&percorso).expect("bind del socket");
    apri_al_filo(&percorso);
    // close_fd: quando il nostro capo si chiude (uscita del programma), il compositor
    // vede l'hangup e smette di accettare connessioni su questo socket
    let (nostro, per_compositor) = UnixStream::pair().expect("socketpair");
    let contesto = gestore.create_listener(
        std::os::fd::AsFd::as_fd(&ascolto),
        std::os::fd::AsFd::as_fd(&per_compositor),
        &qh,
        (),
    );
    contesto.set_sandbox_engine("io.github.tommaso_palestini.aracno".into());
    contesto.set_app_id(format!("io.github.tommaso_palestini.aracno.{filo}"));
    contesto.set_instance_id(filo.clone());
    contesto.commit();
    coda.roundtrip(&mut stato).expect("roundtrip dopo commit");
    drop(per_compositor);
    eprintln!("socket sicuro per {filo}: {percorso}");
    // resta in vita: il socket vale finché questo processo (e `nostro`) esiste
    let _tieni = (nostro, ascolto);
    loop {
        std::thread::park();
    }
}
