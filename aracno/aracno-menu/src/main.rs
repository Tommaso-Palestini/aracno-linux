//! aracno-menu — il menù a ragnatela (spec: docs/spec/SPEC-aracno-menu.md, ADR-0007).
//! T8: istanza unica, layer-shell o ripiego, elenco testuale da ListStrands, Esc.
//!
//! Il processo resta in vita dopo la prima apertura: lanciare di nuovo `aracno-menu`
//! (il tasto rapido) mostra o nasconde la finestra già pronta. Così solo la prima
//! apertura paga l'avvio a freddo (129–207 ms in T2, al limite di M1).
//! Nessun privilegio: l'unico canale verso il sistema è D-Bus verso aracnod.

#![forbid(unsafe_code)]

mod view;

use aracno_proto::client::{self, messaggio, ManagerProxy};
use gtk::glib;
use gtk::prelude::*;
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::cell::{Cell, OnceCell};
use std::rc::Rc;
use std::time::Instant;
use view::Vista;

const APP_ID: &str = "io.github.tommaso_palestini.AracnoMenu";

struct Menu {
    win: gtk::ApplicationWindow,
    vista: Rc<Vista>,
    /// Istante dell'ultima richiesta di apertura, per misurare M1.
    richiesta: Rc<Cell<Instant>>,
}

fn main() -> glib::ExitCode {
    let app = gtk::Application::builder().application_id(APP_ID).build();
    // Istanza unica: un secondo avvio manda `activate` al processo già aperto ed esce.
    let menu: Rc<OnceCell<Menu>> = Rc::new(OnceCell::new());
    app.connect_activate(move |app| match menu.get() {
        Some(m) if m.win.is_visible() => m.win.set_visible(false),
        Some(m) => {
            m.richiesta.set(Instant::now());
            mostra(m);
        }
        None => {
            let m = menu.get_or_init(|| crea(app));
            mostra(m);
        }
    });
    app.run()
}

fn crea(app: &gtk::Application) -> Menu {
    let richiesta = Rc::new(Cell::new(Instant::now()));
    // Il processo resta vivo anche a finestra nascosta (la guardia non si rilascia mai).
    std::mem::forget(app.hold());

    let win = gtk::ApplicationWindow::new(app);
    win.set_title(Some("Aracno"));
    let modo = prepara_superficie(&win);

    let vista = Rc::new(Vista::new());
    win.set_child(Some(&vista.radice));

    let tasti = gtk::EventControllerKey::new();
    let w = win.clone();
    tasti.connect_key_pressed(move |_, key, _, _| {
        if key == gtk::gdk::Key::Escape {
            w.set_visible(false);
            return glib::Propagation::Stop;
        }
        glib::Propagation::Proceed
    });
    win.add_controller(tasti);

    // M1: tempo dalla richiesta (avvio o tasto rapido) alla finestra visibile.
    let r = richiesta.clone();
    win.connect_map(move |_| {
        // @ms assoluti: il test li confronta con l'istante del tasto (avvio del secondo processo)
        let ora = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_millis());
        eprintln!(
            "aracno-menu: visibile in {} ms ({modo}) @{ora}",
            r.get().elapsed().as_millis()
        );
    });
    Menu { win, vista, richiesta }
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
fn mostra(m: &Menu) {
    m.vista.in_attesa();
    m.win.present();
    let vista = m.vista.clone();
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
