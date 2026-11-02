//! Widget del menù: i fili come pulsanti disposti a ragnatela (radial.rs) intorno
//! al centro, sopra una ragnatela leggera disegnata con cairo. Lo stato si mostra
//! sempre come simbolo e testo, mai solo come colore. I pulsanti sono widget veri:
//! si raggiungono con Tab e frecce e il lettore di schermo legge nome, stato e RAM.
//! Aspetto in data/style.css (T10).

use crate::radial::{self, Direzione, Rett};
use aracno_proto::client::{mib, ordina, simbolo, stato_it, tr, Filo};
use aracno_proto::StrandState;
use gtk::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;
use std::time::Duration;

pub const NODO_W: f64 = 200.0;
pub const NODO_H: f64 = 84.0;
pub const CENTRO_W: f64 = 220.0;
pub const CENTRO_H: f64 = 88.0;

/// Durata dell'animazione d'apertura (tutti i nodi, compreso lo sfasamento).
const APERTURA: Duration = Duration::from_millis(300);
/// Quanti pixel percorre un nodo lungo il suo filo mentre arriva.
const CORSA: f64 = 28.0;

// Colori per cairo, gli stessi ruoli di data/style.css.
const INCHIOSTRO: (f64, f64, f64) = (0.922, 0.906, 0.875); // #ebe7df
const RUGIADA: (f64, f64, f64) = (0.561, 0.827, 0.780); // #8fd3c7

/// Seconda riga del nodo: "◌ congelato · 7 MiB" (niente RAM se spento).
pub fn testo_stato(f: &Filo) -> String {
    let mut t = format!("{} {}", simbolo(f.stato), stato_it(f.stato));
    if f.stato != StrandState::Off {
        t.push_str(&format!(" · {}", mib(f.ram)));
    }
    t
}

/// Riga sotto "aracno" al centro: dove sei adesso.
pub fn testo_dove(fili: &[Filo]) -> String {
    match fili.iter().find(|f| f.stato == StrandState::Active) {
        Some(f) => tr("sei su {}").replacen("{}", &f.nome, 1),
        None if fili.is_empty() => tr("nessun filo"),
        None => tr("nessun filo attivo"),
    }
}

/// Testo per il lettore di schermo: "debian, attivo, 22 MiB".
pub fn testo_accessibile(f: &Filo) -> String {
    let mut t = format!("{}, {}", f.nome, stato_it(f.stato));
    if f.stato != StrandState::Off {
        t.push_str(&format!(", {}", mib(f.ram)));
    }
    t
}

fn classe(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "attivo",
        StrandState::Frozen => "congelato",
        StrandState::Off => "spento",
    }
}

/// Cosa fare quando l'utente sceglie un filo (Invio o clic).
pub type Scelta = Rc<dyn Fn(&Filo)>;

/// Quello che serve per disegnare i fili: letto dalla funzione di disegno.
#[derive(Default)]
struct Disegno {
    centro: (f64, f64),
    ellisse: (f64, f64),
    nodi: Vec<((f64, f64), StrandState)>,
}

struct Nodo {
    bottone: gtk::Button,
    stato: gtk::Label,
    filo: Filo,
    rett: Rett,
}

pub struct Vista {
    pub radice: gtk::Overlay,
    area: gtk::DrawingArea,
    fisso: gtk::Fixed,
    centro: gtk::Box,
    dove: gtk::Label,
    avviso: gtk::Label,
    nodi: RefCell<Vec<Nodo>>,
    disegno: Rc<RefCell<Disegno>>,
}

impl Vista {
    pub fn new() -> Self {
        let disegno = Rc::new(RefCell::new(Disegno::default()));
        let area = gtk::DrawingArea::new();
        area.set_hexpand(true);
        area.set_vexpand(true);
        let d = disegno.clone();
        area.set_draw_func(move |_, cr, _, _| disegna_fili(cr, &d.borrow()));

        let fisso = gtk::Fixed::new();

        let centro = gtk::Box::new(gtk::Orientation::Vertical, 2);
        centro.set_size_request(CENTRO_W as i32, CENTRO_H as i32);
        centro.set_valign(gtk::Align::Center);
        let marchio = gtk::Label::new(Some("aracno"));
        marchio.add_css_class("marchio");
        let dove = gtk::Label::new(None);
        dove.add_css_class("dove");
        centro.append(&marchio);
        centro.append(&dove);

        let fondo = gtk::Box::new(gtk::Orientation::Vertical, 8);
        fondo.set_valign(gtk::Align::End);
        fondo.set_halign(gtk::Align::Center);
        fondo.set_margin_bottom(32);
        let avviso = gtk::Label::new(None);
        avviso.add_css_class("avviso");
        avviso.set_wrap(true);
        avviso.set_visible(false);
        let aiuto = gtk::Label::new(Some(&tr(
            "frecce o Tab per scegliere · Invio per passare al filo · Esc per chiudere",
        )));
        aiuto.add_css_class("aiuto");
        fondo.append(&avviso);
        fondo.append(&aiuto);

        let radice = gtk::Overlay::new();
        radice.set_child(Some(&area));
        radice.add_overlay(&fisso);
        radice.add_overlay(&fondo);
        Self {
            radice,
            area,
            fisso,
            centro,
            dove,
            avviso,
            nodi: RefCell::new(Vec::new()),
            disegno,
        }
    }

    /// Dimensioni dell'area: quella allocata, oppure il monitor se non è ancora nota.
    fn misura(&self) -> (f64, f64) {
        let (w, h) = (self.radice.width(), self.radice.height());
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

    fn metti_centro(&self, dove: &str) {
        let (l, a) = self.misura();
        let c = radial::centro(l, a, CENTRO_W, CENTRO_H);
        self.dove.set_text(dove);
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
        let mut fili = fili.to_vec();
        ordina(&mut fili); // il filo attivo è il primo, quindi in alto
        self.metti_centro(&testo_dove(&fili));

        let (l, a) = self.misura();
        let posti = radial::posizioni(fili.len(), l, a, NODO_W, NODO_H);
        let mut nodi = self.nodi.borrow_mut();
        for (f, r) in fili.into_iter().zip(posti) {
            let (b, stato) = bottone(&f, scelta.clone());
            b.set_opacity(0.0); // compare con l'animazione
            self.fisso.put(&b, r.x, r.y);
            nodi.push(Nodo { bottone: b, stato, filo: f, rett: r });
        }
        {
            let mut d = self.disegno.borrow_mut();
            d.centro = (l / 2.0, a / 2.0);
            d.ellisse = radial::raggi(l, a, NODO_W, NODO_H);
            d.nodi = nodi.iter().map(|n| (n.rett.centro(), n.filo.stato)).collect();
        }
        // la ragnatela si disegna una volta sola
        self.area.queue_draw();
        // il primo elemento selezionato è il filo attivo (spec)
        if let Some(n) = nodi.first() {
            n.bottone.grab_focus();
            eprintln!("aracno-menu: selezionato {} (all'apertura)", n.filo.nome);
        }
        let bottoni: Vec<gtk::Button> = nodi.iter().map(|n| n.bottone.clone()).collect();
        drop(nodi);
        self.anima_apertura(bottoni);
    }

    /// Apertura: la ragnatela è ferma e visibile dal primo fotogramma; i nodi arrivano
    /// uno dopo l'altro scorrendo lungo il loro filo verso l'esterno, come gocce che si
    /// posano. Si muovono solo superfici piccole: col motore cairo GTK ridisegna solo le
    /// zone che cambiano, e animare la ragnatela intera (2 milioni di pixel a fotogramma)
    /// scendeva a ~30 fotogrammi al secondo (T10, 2026-11-02, misurato).
    /// I primi fotogrammi di una finestra nuova sono lenti: si parte dopo il secondo.
    /// Con le animazioni di sistema spente tutto appare subito.
    fn anima_apertura(&self, bottoni: Vec<gtk::Button>) {
        let animazioni = gtk::Settings::default().is_none_or(|s| s.is_gtk_enable_animations());
        let (cx, cy) = self.disegno.borrow().centro;
        // per ogni nodo: la sua posizione (angolo in alto a sinistra) e la direzione
        // (unitaria) dal centro dello schermo al nodo. In GtkFixed la posizione è essa
        // stessa una trasformazione: quella dell'animazione deve contenerla, altrimenti
        // il nodo finisce in (0,0) (visto nello screenshot del 2026-11-02).
        let nodi: Vec<(gtk::Button, Rett, f64, f64)> = {
            let d = self.disegno.borrow();
            let posti: Vec<Rett> = self.nodi.borrow().iter().map(|n| n.rett).collect();
            bottoni
                .into_iter()
                .zip(posti)
                .zip(d.nodi.iter())
                .map(|((b, r), &((nx, ny), _))| {
                    let l = (nx - cx).hypot(ny - cy).max(1.0);
                    (b, r, (nx - cx) / l, (ny - cy) / l)
                })
                .collect()
        };
        let n = nodi.len();
        let fisso = self.fisso.clone();
        let imposta = move |t: f64| {
            for (i, (b, r, ux, uy)) in nodi.iter().enumerate() {
                let p = radial::uscita_cubica(radial::fase(t, i, n));
                let indietro = (1.0 - p) * CORSA;
                let tr = gtk::gsk::Transform::new().translate(&gtk::graphene::Point::new(
                    (r.x - ux * indietro) as f32,
                    (r.y - uy * indietro) as f32,
                ));
                fisso.set_child_transform(b, Some(&tr));
                b.set_opacity(p);
            }
        };
        if !animazioni {
            imposta(1.0);
            return;
        }
        imposta(0.0);
        const RISCALDAMENTO: u32 = 2;
        let inizio = std::cell::Cell::new(None::<i64>);
        let fotogrammi = std::cell::Cell::new(0u32);
        let prec = std::cell::Cell::new(0i64);
        let intervalli = RefCell::new(Vec::<i64>::new());
        self.area.add_tick_callback(move |_, orologio| {
            let ora = orologio.frame_time(); // microsecondi
            let k = fotogrammi.get() + 1;
            fotogrammi.set(k);
            if prec.get() > 0 {
                intervalli.borrow_mut().push((ora - prec.get()) / 1000);
            }
            prec.set(ora);
            if k <= RISCALDAMENTO {
                return gtk::glib::ControlFlow::Continue;
            }
            let t0 = match inizio.get() {
                Some(t0) => t0,
                None => {
                    inizio.set(Some(ora));
                    ora
                }
            };
            let t = (ora - t0) as f64 / APERTURA.as_micros() as f64;
            imposta(t);
            if t >= 1.0 {
                eprintln!(
                    "aracno-menu: apertura animata in {} fotogrammi, {} ms; intervalli ms {:?}",
                    k - RISCALDAMENTO,
                    (ora - t0) / 1000,
                    intervalli.borrow()
                );
                gtk::glib::ControlFlow::Break
            } else {
                gtk::glib::ControlFlow::Continue
            }
        });
    }

    /// Aggiornamento in diretta (StateChanged): stessi fili, stati nuovi. Nodi,
    /// ragnatela e centro si aggiornano al loro posto: niente animazione, la
    /// selezione resta dov'è. Se i fili sono cambiati (aggiunti o tolti) restituisce
    /// falso e il chiamante ricostruisce il menù.
    pub fn aggiorna(&self, fili: &[Filo]) -> bool {
        let mut nodi = self.nodi.borrow_mut();
        let stessi = nodi.len() == fili.len()
            && nodi.iter().all(|n| fili.iter().any(|f| f.nome == n.filo.nome));
        if !stessi {
            return false;
        }
        for n in nodi.iter_mut() {
            let Some(f) = fili.iter().find(|f| f.nome == n.filo.nome) else { continue };
            if *f == n.filo {
                continue;
            }
            n.bottone.remove_css_class(classe(n.filo.stato));
            n.bottone.add_css_class(classe(f.stato));
            n.stato.set_text(&testo_stato(f));
            n.bottone
                .update_property(&[gtk::accessible::Property::Label(&testo_accessibile(f))]);
            n.filo = f.clone();
        }
        self.disegno.borrow_mut().nodi =
            nodi.iter().map(|n| (n.rett.centro(), n.filo.stato)).collect();
        drop(nodi);
        self.dove.set_text(&testo_dove(fili));
        self.area.queue_draw();
        true
    }

    /// Sposta il focus con una freccia. Vero se la freccia è stata usata.
    /// Si usa `is_focus` e non `has_focus`, che è vero solo a finestra attiva.
    pub fn muovi(&self, dir: Direzione) -> bool {
        let nodi = self.nodi.borrow();
        let Some(da) = nodi.iter().position(|n| n.bottone.is_focus()) else {
            return match nodi.first() {
                Some(n) => n.bottone.grab_focus(),
                None => false,
            };
        };
        let rett: Vec<Rett> = nodi.iter().map(|n| n.rett).collect();
        if let Some(j) = radial::vicino(&rett, da, dir) {
            nodi[j].bottone.grab_focus();
            eprintln!("aracno-menu: freccia {dir:?} → {}", nodi[j].filo.nome);
        }
        true
    }

    /// Nome del filo selezionato (per il log).
    pub fn selezionato(&self) -> Option<String> {
        self.nodi
            .borrow()
            .iter()
            .find(|n| n.bottone.is_focus())
            .map(|n| n.filo.nome.clone())
    }

    /// Durante lo switch: pulsanti bloccati, indicatore sul filo scelto.
    pub fn in_switch(&self, nome: &str) {
        for n in self.nodi.borrow().iter() {
            n.bottone.set_sensitive(false);
            if n.filo.nome == nome {
                n.stato.set_text(&tr("passo a questo filo…"));
            }
        }
    }

    /// M4: errore chiaro, il menù resta aperto e si può riprovare.
    pub fn mostra_errore(&self, msg: &str) {
        for n in self.nodi.borrow().iter() {
            n.bottone.set_sensitive(true);
            n.stato.set_text(&testo_stato(&n.filo));
        }
        self.avviso.set_text(&format!("⚠ {msg}"));
        self.avviso.set_visible(true);
    }
}

/// Pulsante di un filo: nome grande sopra, stato e RAM sotto.
fn bottone(f: &Filo, scelta: Scelta) -> (gtk::Button, gtk::Label) {
    let nome = gtk::Label::new(Some(&f.nome));
    nome.add_css_class("nome");
    let stato = gtk::Label::new(Some(&testo_stato(f)));
    stato.add_css_class("stato");
    let scatola = gtk::Box::new(gtk::Orientation::Vertical, 2);
    scatola.set_valign(gtk::Align::Center);
    scatola.append(&nome);
    scatola.append(&stato);

    let b = gtk::Button::new();
    b.set_child(Some(&scatola));
    b.set_size_request(NODO_W as i32, NODO_H as i32);
    b.add_css_class("filo");
    b.add_css_class(classe(f.stato));
    b.update_property(&[gtk::accessible::Property::Label(&testo_accessibile(f))]);
    let filo = f.clone();
    b.connect_clicked(move |_| {
        eprintln!("aracno-menu: scelto {}", filo.nome);
        scelta(&filo)
    });
    (b, stato)
}

/// La ragnatela: raggi e anelli sottili di sfondo, un filo verso ogni nodo,
/// quello del filo attivo nel colore della rugiada.
fn disegna_fili(cr: &gtk::cairo::Context, d: &Disegno) {
    if d.nodi.is_empty() {
        return;
    }
    let lib = radial::libero(CENTRO_W, CENTRO_H);
    let (r, g, b) = INCHIOSTRO;
    cr.set_line_cap(gtk::cairo::LineCap::Round);

    cr.set_source_rgba(r, g, b, 0.09);
    cr.set_line_width(1.0);
    let sfondo = radial::ragnatela(d.centro, d.ellisse, lib, radial::RAGGI, &radial::ANELLI, 1.0);
    for (x1, y1, x2, y2) in sfondo {
        cr.move_to(x1, y1);
        cr.line_to(x2, y2);
    }
    let _ = cr.stroke();

    let (cx, cy) = d.centro;
    for &((nx, ny), stato) in &d.nodi {
        let a = (ny - cy).atan2(nx - cx);
        let (x1, y1) = (cx + lib.0 * a.cos(), cy + lib.1 * a.sin());
        let (x2, y2) = (nx, ny);
        if stato == StrandState::Active {
            let (r, g, b) = RUGIADA;
            cr.set_source_rgba(r, g, b, 0.9);
            cr.set_line_width(2.0);
        } else {
            cr.set_source_rgba(r, g, b, 0.28);
            cr.set_line_width(1.5);
        }
        cr.move_to(x1, y1);
        cr.line_to(x2, y2);
        let _ = cr.stroke();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn f(nome: &str, stato: StrandState, ram: u64) -> Filo {
        Filo { nome: nome.into(), stato, ram, limite: 0 }
    }

    #[test]
    fn testi_dello_stato() {
        assert_eq!(testo_stato(&f("debian", StrandState::Active, 23_146_496)), "● attivo · 22 MiB");
        assert_eq!(testo_stato(&f("arch", StrandState::Frozen, 1 << 20)), "◌ congelato · 1 MiB");
        assert_eq!(testo_stato(&f("fedora", StrandState::Off, 0)), "· spento");
    }

    #[test]
    fn dove_sei() {
        let fili = [f("arch", StrandState::Frozen, 0), f("debian", StrandState::Active, 0)];
        assert_eq!(testo_dove(&fili), "sei su debian");
        assert_eq!(testo_dove(&fili[..1]), "nessun filo attivo");
        assert_eq!(testo_dove(&[]), "nessun filo");
    }

    #[test]
    fn testi_accessibili() {
        assert_eq!(testo_accessibile(&f("debian", StrandState::Active, 23_146_496)), "debian, attivo, 22 MiB");
        assert_eq!(testo_accessibile(&f("fedora", StrandState::Off, 0)), "fedora, spento");
    }
}
