//! aracno-menu — il menù a ragnatela (spec: docs/spec/SPEC-aracno-menu.md, ADR-0007).
//! T8: istanza unica, layer-shell o ripiego, Esc. T9: fili a ragnatela, frecce, Tab,
//! Invio o clic per lo switch tramite aracnod, chiusura a switch fatto.
//!
//! Ogni apertura è un processo nuovo; chiudere il menù (Esc, oppure lanciare di nuovo
//! `aracno-menu` col tasto rapido) fa uscire il processo. Non si nasconde né si chiude
//! mai la finestra: su COSMIC (cosmic-comp 1.0.0, gtk4-layer-shell 1.0.4) rimuovere una
//! superficie layer-shell fa chiudere la connessione al compositor (T8, 2026-11-02,
//! log WAYLAND_DEBUG). Uscire subito evita il problema; il compositor fa pulizia da sé.
//! Avvio misurato: 75–91 ms a cache calda, 540 ms la prima volta dopo il boot.
//! Nessun privilegio: l'unico canale verso il sistema è D-Bus verso aracnod.

#![forbid(unsafe_code)]

mod radial;
mod view;

use aracno_proto::client::{self, messaggio, ManagerProxy};
use gtk::glib;
use gtk::prelude::*;
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::rc::Rc;
use std::time::Instant;
use radial::Direzione;
use view::{Scelta, Vista};

const APP_ID: &str = "io.github.tommaso_palestini.AracnoMenu";

fn main() -> glib::ExitCode {
    let avvio = Instant::now();
    let app = gtk::Application::builder().application_id(APP_ID).build();
    // Istanza unica: un secondo avvio manda `activate` al processo già aperto ed esce.
    // Menù già aperto → si chiude (tasto rapido = apri/chiudi).
    app.connect_activate(move |app| {
        if app.windows().is_empty() {
            crea(app, avvio);
        } else {
            chiudi();
        }
    });
    app.run()
}

/// Chiude il menù uscendo dal processo, senza smontare la superficie (vedi sopra).
fn chiudi() -> ! {
    std::process::exit(0)
}

fn crea(app: &gtk::Application, avvio: Instant) {
    let win = gtk::ApplicationWindow::new(app);
    win.set_title(Some("Aracno"));
    let modo = prepara_superficie(&win);

    let vista = Rc::new(Vista::new());
    win.set_child(Some(&vista.radice));
    // Il filo selezionato si vede subito, non solo dopo il primo tasto.
    win.set_focus_visible(true);


    // Fase di cattura: le frecce le gestisce la ragnatela (radial::vicino), non la
    // navigazione standard di GTK. Tab e Invio restano quelli di GTK.
    let tasti = gtk::EventControllerKey::new();
    tasti.set_propagation_phase(gtk::PropagationPhase::Capture);
    let v = vista.clone();
    let w = win.clone();
    tasti.connect_key_pressed(move |_, key, _, _| {
        use gtk::gdk::Key;
        let dir = match key {
            Key::Escape => chiudi(),
            Key::Up => Direzione::Su,
            Key::Down => Direzione::Giu,
            Key::Left => Direzione::Sinistra,
            Key::Right => Direzione::Destra,
            Key::Return | Key::KP_Enter | Key::Tab | Key::ISO_Left_Tab => {
                eprintln!("aracno-menu: tasto {} con selezionato {:?}", key.name().unwrap_or_default(), v.selezionato());
                return glib::Propagation::Proceed;
            }
            _ => return glib::Propagation::Proceed,
        };
        if v.muovi(dir) {
            // Le frecce le intercettiamo prima di GTK, che quindi non accende da solo
            // l'evidenziazione del focus: senza questo la selezione si spostava senza
            // vedersi (T9, 2026-11-02: "le frecce non funzionano finché non premo Tab").
            w.set_focus_visible(true);
            glib::Propagation::Stop
        } else {
            glib::Propagation::Proceed
        }
    });
    win.add_controller(tasti);

    // M1: tempo dall'avvio del processo (il tasto rapido) alla finestra visibile.
    win.connect_map(move |_| {
        // @ms assoluti: il test li confronta con l'istante del tasto (avvio del secondo processo)
        let ora = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_millis());
        eprintln!(
            "aracno-menu: visibile in {} ms ({modo}) @{ora}",
            avvio.elapsed().as_millis()
        );
    });
    mostra(&win, vista);
}

/// Layer-shell sopra tutto, oppure (GNOME, X11) una finestra a schermo intero.
fn prepara_superficie(win: &gtk::ApplicationWindow) -> &'static str {
    // is_supported() della libreria 1.0.4 dà un CRITICAL se il display non è Wayland (T2).
    let su_wayland =
        gtk::gdk::Display::default().is_some_and(|d| d.type_().name() == "GdkWaylandDisplay");
    if su_wayland && gtk4_layer_shell::is_supported() {
        win.init_layer_shell();
        win.set_namespace(Some("aracno-menu"));
        win.set_layer(Layer::Overlay);
        win.set_keyboard_mode(KeyboardMode::Exclusive);
        for edge in [Edge::Top, Edge::Bottom, Edge::Left, Edge::Right] {
            win.set_anchor(edge, true);
        }
        win.set_exclusive_zone(-1); // copre anche i pannelli
        "layer-shell"
    } else {
        win.fullscreen();
        "ripiego a schermo intero"
    }
}

/// Mostra la finestra e chiede ad aracnod lo stato attuale dei fili.
fn mostra(win: &gtk::ApplicationWindow, vista: Rc<Vista>) {
    vista.in_attesa();
    win.present();
    glib::spawn_future_local(async move {
        let esito = async {
            let conn = zbus::Connection::system()
                .await
                .map_err(|e| messaggio(&e))?;
            let p = ManagerProxy::new(&conn).await.map_err(|e| messaggio(&e))?;
            client::fili(&p).await.map(|f| (f, p))
        }
        .await;
        match esito {
            Ok((fili, p)) => {
                let scelta = scelta(vista.clone(), p);
                vista.mostra_fili(&fili, scelta);
            }
            Err(e) => vista.mostra_errore(&e),
        }
    });
}

/// Invio o clic su un filo: se è già attivo si chiude e basta, altrimenti Switch.
/// A switch fatto il menù si chiude; in caso di errore resta aperto col messaggio.
fn scelta(vista: Rc<Vista>, p: ManagerProxy<'static>) -> Scelta {
    Rc::new(move |f: &client::Filo| {
        if f.stato == aracno_proto::StrandState::Active {
            chiudi();
        }
        vista.in_switch(&f.nome);
        let (v, p, nome) = (vista.clone(), p.clone(), f.nome.clone());
        glib::spawn_future_local(async move {
            match p.switch(&nome).await {
                Ok(ms) => {
                    eprintln!("aracno-menu: switch {nome} ok in {ms} ms");
                    chiudi();
                }
                Err(e) => {
                    eprintln!("aracno-menu: switch {nome} fallito: {e}");
                    v.mostra_errore(&messaggio(&e));
                }
            }
        });
    })
}
