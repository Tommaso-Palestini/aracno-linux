//! Elenca i protocolli Wayland offerti dal compositor a questo client, uno per riga:
//! "nome versione". Usa WAYLAND_DISPLAY e XDG_RUNTIME_DIR come qualsiasi programma.
use wayland_client::protocol::wl_registry;
use wayland_client::{Connection, Dispatch, QueueHandle};

struct Globali(Vec<(String, u32)>);

impl Dispatch<wl_registry::WlRegistry, ()> for Globali {
    fn event(
        stato: &mut Self,
        _: &wl_registry::WlRegistry,
        evento: wl_registry::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global { interface, version, .. } = evento {
            stato.0.push((interface, version));
        }
    }
}

fn main() {
    let conn = match Connection::connect_to_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("nessun compositor raggiungibile: {e}");
            std::process::exit(1);
        }
    };
    let mut coda = conn.new_event_queue();
    conn.display().get_registry(&coda.handle(), ());
    let mut g = Globali(Vec::new());
    coda.roundtrip(&mut g).expect("roundtrip");
    g.0.sort();
    for (nome, versione) in g.0 {
        println!("{nome} {versione}");
    }
}
