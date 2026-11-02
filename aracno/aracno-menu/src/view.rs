//! Widget del menù (T8: elenco testuale; la raggiera arriva in T9).
//! Lo stato si mostra sempre come simbolo e testo, mai solo come colore.

use aracno_proto::client::{mib, ordina, simbolo, stato_it, Filo};
use aracno_proto::StrandState;
use gtk::prelude::*;

/// Testo di una riga: "● debian — attivo — 22 MiB" (niente RAM se spento).
pub fn testo_riga(f: &Filo) -> String {
    let mut t = format!("{} {} — {}", simbolo(f.stato), f.nome, stato_it(f.stato));
    if f.stato != StrandState::Off {
        t.push_str(&format!(" — {}", mib(f.ram)));
    }
    t
}

pub struct Vista {
    pub radice: gtk::Box,
    elenco: gtk::Box,
    avviso: gtk::Label,
}

impl Vista {
    pub fn new() -> Self {
        let radice = gtk::Box::new(gtk::Orientation::Vertical, 24);
        radice.set_valign(gtk::Align::Center);
        radice.set_halign(gtk::Align::Center);

        let titolo = gtk::Label::new(Some("aracno"));
        titolo.add_css_class("title-1");
        let elenco = gtk::Box::new(gtk::Orientation::Vertical, 8);
        let avviso = gtk::Label::new(None);
        avviso.set_wrap(true);
        avviso.set_visible(false);
        let aiuto = gtk::Label::new(Some("Esc per chiudere"));
        aiuto.add_css_class("dim-label");

        radice.append(&titolo);
        radice.append(&elenco);
        radice.append(&avviso);
        radice.append(&aiuto);
        Self { radice, elenco, avviso }
    }

    fn svuota(&self) {
        while let Some(c) = self.elenco.first_child() {
            self.elenco.remove(&c);
        }
    }

    pub fn in_attesa(&self) {
        self.svuota();
        self.avviso.set_visible(false);
        self.elenco.append(&gtk::Label::new(Some("…")));
    }

    pub fn mostra_fili(&self, fili: &[Filo]) {
        self.svuota();
        self.avviso.set_visible(false);
        let mut fili = fili.to_vec();
        ordina(&mut fili);
        if fili.is_empty() {
            self.elenco.append(&gtk::Label::new(Some("nessun filo")));
        }
        for f in &fili {
            let l = gtk::Label::new(Some(&testo_riga(f)));
            l.set_xalign(0.0);
            if f.stato == StrandState::Active {
                l.add_css_class("heading");
            } else {
                l.add_css_class("dim-label");
            }
            self.elenco.append(&l);
        }
    }

    /// M4: errore chiaro, il menù resta aperto.
    pub fn mostra_errore(&self, msg: &str) {
        self.svuota();
        self.avviso.set_text(&format!("⚠ {msg}"));
        self.avviso.set_visible(true);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn righe() {
        let f = |nome: &str, stato, ram| Filo { nome: nome.into(), stato, ram, limite: 0 };
        assert_eq!(testo_riga(&f("debian", StrandState::Active, 23_146_496)), "● debian — attivo — 22 MiB");
        assert_eq!(testo_riga(&f("arch", StrandState::Frozen, 1 << 20)), "◌ arch — congelato — 1 MiB");
        assert_eq!(testo_riga(&f("fedora", StrandState::Off, 0)), "· fedora — spento");
    }
}
