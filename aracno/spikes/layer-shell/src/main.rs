//! T2 — una finestra a tutto schermo sopra il desktop con layer-shell, oppure
//! (se il compositor non lo supporta) una normale finestra a schermo intero.
//! Criteri: copre lo schermo sopra le altre finestre, riceve la tastiera, Esc chiude.
//! Stampa quale modo ha usato e quanto tempo passa dall'avvio alla finestra visibile.
use gtk::prelude::*;
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::time::Instant;

fn main() -> gtk::glib::ExitCode {
    let t0 = Instant::now();
    let app = gtk::Application::builder()
        .application_id("io.github.tommaso_palestini.AracnoSpike")
        .build();
    app.connect_activate(move |app| build(app, t0));
    app.run()
}

fn build(app: &gtk::Application, t0: Instant) {
    let win = gtk::ApplicationWindow::new(app);
    // is_supported() della libreria 1.0.4 dà un avviso CRITICAL se il display non è
    // Wayland (es. X11): si controlla prima il tipo di display.
    let su_wayland = gtk::gdk::Display::default()
        .is_some_and(|d| d.type_().name() == "GdkWaylandDisplay");
    let layer = su_wayland && gtk4_layer_shell::is_supported();

    if layer {
        win.init_layer_shell();
        win.set_namespace(Some("aracno-menu"));
        win.set_layer(Layer::Overlay);
        win.set_keyboard_mode(KeyboardMode::Exclusive);
        for edge in [Edge::Top, Edge::Bottom, Edge::Left, Edge::Right] {
            win.set_anchor(edge, true);
        }
        win.set_exclusive_zone(-1); // copre anche i pannelli
    } else {
        win.fullscreen();
    }

    let modo = if layer { "layer-shell (overlay)" } else { "ripiego: finestra a schermo intero" };
    let label = gtk::Label::new(Some(&format!(
        "Aracno — prova T2\n\nmodo: {modo}\n\nscrivi qualcosa per provare la tastiera, Esc per chiudere"
    )));
    label.set_justify(gtk::Justification::Center);
    let tasti = gtk::Label::new(Some("tasti ricevuti: 0"));
    let vbox = gtk::Box::new(gtk::Orientation::Vertical, 24);
    vbox.set_valign(gtk::Align::Center);
    vbox.append(&label);
    vbox.append(&tasti);
    win.set_child(Some(&vbox));

    let keys = gtk::EventControllerKey::new();
    let w = win.clone();
    let contati = std::cell::Cell::new(0u32);
    keys.connect_key_pressed(move |_, key, _, _| {
        if key == gtk::gdk::Key::Escape {
            w.close();
            return gtk::glib::Propagation::Stop;
        }
        contati.set(contati.get() + 1);
        tasti.set_text(&format!("tasti ricevuti: {} (ultimo: {})", contati.get(),
            key.name().map(|n| n.to_string()).unwrap_or_default()));
        gtk::glib::Propagation::Stop
    });
    win.add_controller(keys);

    win.connect_map(move |_| {
        println!("modo: {modo}; visibile dopo {} ms dall'avvio", t0.elapsed().as_millis());
    });
    win.present();
}
