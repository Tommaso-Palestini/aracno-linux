//! Widget del menù: i fili come pulsanti disposti a ragnatela (radial.rs) intorno
//! al centro. Lo stato si mostra sempre come simbolo e testo, mai solo come colore.
//! I pulsanti sono widget veri: si raggiungono con Tab e frecce e il lettore di
//! schermo legge nome, stato e RAM.

use crate::radial::{self, Direzione, Rett};
use aracno_proto::client::{mib, ordina, simbolo, stato_it, Filo};
use aracno_proto::StrandState;
use gtk::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

pub const NODO_W: f64 = 200.0;
pub const NODO_H: f64 = 84.0;
pub const CENTRO_W: f64 = 180.0;
pub const CENTRO_H: f64 = 64.0;

/// Testo del nodo su due righe: "● debian" e "attivo · 22 MiB" (niente RAM se spento).
pub fn testo_nodo(f: &Filo) -> String {
    let mut t = format!("{} {}\n{}", simbolo(f.stato), f.nome, stato_it(f.stato));
    if f.stato != StrandState::Off {
        t.push_str(&format!(" · {}", mib(f.ram)));
    }
    t
}

/// Testo per il lettore di schermo: "debian, attivo, 22 MiB".
pub fn testo_accessibile(f: &Filo) -> String {
    let mut t = format!("{}, {}", f.nome, stato_it(f.stato));
    if f.stato != StrandState::Off {
        t.push_str(&format!(", {}", mib(f.ram)));
    }
    t
}

/// Cosa fare quando l'utente sceglie un filo (Invio o clic).
pub type Scelta = Rc<dyn Fn(&Filo)>;

pub struct Vista {
    pub radice: gtk::Overlay,
    fisso: gtk::Fixed,
    centro: gtk::Label,
    avviso: gtk::Label,
    nodi: RefCell<Vec<(gtk::Button, Filo, Rett)>>,
}

impl Vista {
    pub fn new() -> Self {
        let fisso = gtk::Fixed::new();
        fisso.set_hexpand(true);
        fisso.set_vexpand(true);
        let centro = gtk::Label::new(Some("aracno"));
        centro.add_css_class("title-1");
        centro.set_size_request(CENTRO_W as i32, CENTRO_H as i32);

        let fondo = gtk::Box::new(gtk::Orientation::Vertical, 8);
        fondo.set_valign(gtk::Align::End);
        fondo.set_halign(gtk::Align::Center);
        fondo.set_margin_bottom(32);
        let avviso = gtk::Label::new(None);
        avviso.set_wrap(true);
        avviso.set_visible(false);
        let aiuto = gtk::Label::new(Some("frecce o Tab per scegliere · Invio per passare al filo · Esc per chiudere"));
        aiuto.add_css_class("dim-label");
        fondo.append(&avviso);
        fondo.append(&aiuto);

        let radice = gtk::Overlay::new();
        radice.set_child(Some(&fisso));
        radice.add_overlay(&fondo);
        Self { radice, fisso, centro, avviso, nodi: RefCell::new(Vec::new()) }
    }

    /// Dimensioni dell'area: quella allocata, oppure il monitor se non è ancora nota.
    fn area(&self) -> (f64, f64) {
        let (w, h) = (self.fisso.width(), self.fisso.height());
        if w > 0 && h > 0 {
            return (w as f64, h as f64);
        }
        gtk::gdk::Display::default()
            .and_then(|d| d.monitors().item(0))
            .and_then(|m| m.downcast::<gtk::gdk::Monitor>().ok())
            .map(|m| (m.geometry().width() as f64, m.geometry().height() as f64))
            .unwrap_or((1366.0, 768.0))
    }

    fn svuota(&self) {
        while let Some(c) = self.fisso.first_child() {
            self.fisso.remove(&c);
        }
        self.nodi.borrow_mut().clear();
    }

    fn metti_centro(&self, testo: &str) {
        let (l, a) = self.area();
        let c = radial::centro(l, a, CENTRO_W, CENTRO_H);
        self.centro.set_text(testo);
        self.fisso.put(&self.centro, c.x, c.y);
    }

    pub fn in_attesa(&self) {
        self.svuota();
        self.avviso.set_visible(false);
        self.metti_centro("…");
    }

    pub fn mostra_fili(&self, fili: &[Filo], scelta: Scelta) {
        self.svuota();
        self.avviso.set_visible(false);
        self.metti_centro("aracno");
        let mut fili = fili.to_vec();
        ordina(&mut fili); // il filo attivo è il primo, quindi in alto
        if fili.is_empty() {
            self.metti_centro("nessun filo");
            return;
        }
        let (l, a) = self.area();
        let posti = radial::posizioni(fili.len(), l, a, NODO_W, NODO_H);
        let mut nodi = self.nodi.borrow_mut();
        for (f, r) in fili.into_iter().zip(posti) {
            let b = gtk::Button::with_label(&testo_nodo(&f));
            b.set_size_request(NODO_W as i32, NODO_H as i32);
            if let Some(l) = b.child().and_downcast::<gtk::Label>() {
                l.set_justify(gtk::Justification::Center);
            }
            b.add_css_class(match f.stato {
                StrandState::Active => "suggested-action",
                StrandState::Frozen => "flat",
                StrandState::Off => "flat",
            });
            b.update_property(&[gtk::accessible::Property::Label(&testo_accessibile(&f))]);
            let s = scelta.clone();
            let filo = f.clone();
            b.connect_clicked(move |_| s(&filo));
            self.fisso.put(&b, r.x, r.y);
            nodi.push((b, f, r));
        }
        // il primo elemento selezionato è il filo attivo (spec)
        if let Some((b, _, _)) = nodi.first() {
            b.grab_focus();
        }
    }

    /// Sposta il focus con una freccia. Vero se la freccia è stata usata.
    pub fn muovi(&self, dir: Direzione) -> bool {
        let nodi = self.nodi.borrow();
        let Some(da) = nodi.iter().position(|(b, _, _)| b.has_focus()) else {
            return match nodi.first() {
                Some((b, _, _)) => b.grab_focus(),
                None => false,
            };
        };
        let rett: Vec<Rett> = nodi.iter().map(|(_, _, r)| *r).collect();
        if let Some(j) = radial::vicino(&rett, da, dir) {
            nodi[j].0.grab_focus();
        }
        true
    }

    /// Durante lo switch: pulsanti bloccati, indicatore sul filo scelto.
    pub fn in_switch(&self, nome: &str) {
        for (b, f, _) in self.nodi.borrow().iter() {
            b.set_sensitive(false);
            if f.nome == nome {
                b.set_label(&format!("{}\n…", f.nome));
            }
        }
    }

    /// M4: errore chiaro, il menù resta aperto e si può riprovare.
    pub fn mostra_errore(&self, msg: &str) {
        for (b, f, _) in self.nodi.borrow().iter() {
            b.set_sensitive(true);
            b.set_label(&testo_nodo(f));
        }
        self.avviso.set_text(&format!("⚠ {msg}"));
        self.avviso.set_visible(true);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn f(nome: &str, stato: StrandState, ram: u64) -> Filo {
        Filo { nome: nome.into(), stato, ram, limite: 0 }
    }

    #[test]
    fn testi_dei_nodi() {
        assert_eq!(testo_nodo(&f("debian", StrandState::Active, 23_146_496)), "● debian\nattivo · 22 MiB");
        assert_eq!(testo_nodo(&f("arch", StrandState::Frozen, 1 << 20)), "◌ arch\ncongelato · 1 MiB");
        assert_eq!(testo_nodo(&f("fedora", StrandState::Off, 0)), "· fedora\nspento");
    }

    #[test]
    fn testi_accessibili() {
        assert_eq!(testo_accessibile(&f("debian", StrandState::Active, 23_146_496)), "debian, attivo, 22 MiB");
        assert_eq!(testo_accessibile(&f("fedora", StrandState::Off, 0)), "fedora, spento");
    }
}
