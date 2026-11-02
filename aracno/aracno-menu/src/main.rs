//! aracno-menu — il menù a ragnatela (spec: docs/spec/SPEC-aracno-menu.md, ADR-0007).
//! T8: istanza unica, layer-shell o ripiego, elenco testuale da ListStrands, Esc.
//!
//! Ogni apertura è un processo nuovo; chiudere il menù (Esc, oppure lanciare di nuovo
//! `aracno-menu` col tasto rapido) fa uscire il processo. Non si nasconde né si chiude
//! mai la finestra: su COSMIC (cosmic-comp 1.0.0, gtk4-layer-shell 1.0.4) rimuovere una
//! superficie layer-shell fa chiudere la connessione al compositor (T8, 2026-11-02,
//! log WAYLAND_DEBUG). Uscire subito evita il problema; il compositor fa pulizia da sé.
//! Avvio misurato: 75–91 ms a cache calda, 540 ms la prima volta dopo il boot.
//! Nessun privilegio: l'unico canale verso il sistema è D-Bus verso aracnod.

#![forbid(unsafe_code)]

mod view;

use aracno_proto::client::{self, messaggio, ManagerProxy};
use gtk::glib;
use gtk::prelude::*;
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::rc::Rc;
use std::time::Instant;
use view::Vista;

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

    let tasti = gtk::EventControllerKey::new();
    tasti.connect_key_pressed(|_, key, _, _| {
        if key == gtk::gdk::Key::Escape {
            chiudi();
        }
        glib::Propagation::Proceed
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
            client::fili(&p).await
        }
        .await;
        match esito {
            Ok(fili) => vista.mostra_fili(&fili),
            Err(e) => vista.mostra_errore(&e),
        }
    });
}
