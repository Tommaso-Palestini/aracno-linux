//! Disposizione a ragnatela: i fili su un'ellisse intorno al centro dello schermo,
//! il primo in alto e gli altri in senso orario. Logica pura, senza GTK.

/// Rettangolo in pixel: angolo in alto a sinistra e dimensioni.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rett {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}

impl Rett {
    pub fn centro(&self) -> (f64, f64) {
        (self.x + self.w / 2.0, self.y + self.h / 2.0)
    }
    #[cfg(test)]
    pub fn si_sovrappone(&self, o: &Rett) -> bool {
        self.x < o.x + o.w && o.x < self.x + self.w && self.y < o.y + o.h && o.y < self.y + self.h
    }
    #[cfg(test)]
    pub fn dentro(&self, larg: f64, alt: f64) -> bool {
        self.x >= 0.0 && self.y >= 0.0 && self.x + self.w <= larg && self.y + self.h <= alt
    }
}

/// Spazio lasciato tra i nodi e il bordo dello schermo.
pub const MARGINE: f64 = 24.0;
/// Quanto dell'ellisse massima si usa: un po' meno, così la ragnatela respira.
const PROPORZIONE: f64 = 0.85;

/// Rettangolo del centro della ragnatela (w×h), al centro dello schermo.
pub fn centro(larg: f64, alt: f64, w: f64, h: f64) -> Rett {
    Rett { x: (larg - w) / 2.0, y: (alt - h) / 2.0, w, h }
}

/// Semiassi dell'ellisse su cui stanno i centri dei nodi grandi w×h.
pub fn raggi(larg: f64, alt: f64, w: f64, h: f64) -> (f64, f64) {
    (
        ((larg - w) / 2.0 - MARGINE).max(0.0) * PROPORZIONE,
        ((alt - h) / 2.0 - MARGINE).max(0.0) * PROPORZIONE,
    )
}

/// Posizioni di `n` nodi grandi w×h su uno schermo larg×alt.
pub fn posizioni(n: usize, larg: f64, alt: f64, w: f64, h: f64) -> Vec<Rett> {
    let (cx, cy) = (larg / 2.0, alt / 2.0);
    let (rx, ry) = raggi(larg, alt, w, h);
    (0..n)
        .map(|k| {
            let a = -std::f64::consts::FRAC_PI_2 + std::f64::consts::TAU * k as f64 / n as f64;
            Rett { x: cx + rx * a.cos() - w / 2.0, y: cy + ry * a.sin() - h / 2.0, w, h }
        })
        .collect()
}

/// Semiassi della zona senza fili intorno al centro w×h: l'ellisse che contiene
/// tutto il rettangolo (angoli compresi), più un piccolo respiro.
pub fn libero(w: f64, h: f64) -> (f64, f64) {
    let r2 = std::f64::consts::SQRT_2;
    (w / 2.0 * r2 + 12.0, h / 2.0 * r2 + 12.0)
}

/// Segmento da disegnare: (x1, y1, x2, y2).
pub type Segmento = (f64, f64, f64, f64);

/// Fili di sfondo della ragnatela: `raggi_n` raggi dal bordo della zona libera
/// intorno al centro (semiassi `libero`) fino a 1,12 volte l'ellisse dei nodi, e un
/// anello di segmenti dritti tra raggi vicini per ogni frazione in `anelli`.
/// `p` (0–1) è l'avanzamento dell'animazione d'apertura: i fili crescono dal centro.
pub fn ragnatela(
    centro: (f64, f64),
    ellisse: (f64, f64),
    libero: (f64, f64),
    raggi_n: usize,
    anelli: &[f64],
    p: f64,
) -> Vec<Segmento> {
    let (cx, cy) = centro;
    let (rx, ry) = ellisse;
    let p = p.clamp(0.0, 1.0);
    let punto = |a: f64, f: f64| (cx + rx * f * a.cos(), cy + ry * f * a.sin());
    let angoli: Vec<f64> = (0..raggi_n)
        .map(|k| -std::f64::consts::FRAC_PI_2 + std::f64::consts::TAU * k as f64 / raggi_n as f64)
        .collect();
    let mut out = Vec::new();
    let fine = 1.12 * p;
    for &a in &angoli {
        let (x1, y1) = (cx + libero.0 * a.cos(), cy + libero.1 * a.sin());
        let (x2, y2) = punto(a, fine);
        // il raggio parte dal bordo della zona libera: se non l'ha ancora superato, niente
        if (x2 - cx).hypot(y2 - cy) > (x1 - cx).hypot(y1 - cy) {
            out.push((x1, y1, x2, y2));
        }
    }
    for &f in anelli {
        // un anello dentro la zona libera coprirebbe il centro: si salta
        if f > fine || raggi_n < 3 || f * rx <= libero.0 || f * ry <= libero.1 {
            continue;
        }
        for k in 0..raggi_n {
            let (x1, y1) = punto(angoli[k], f);
            let (x2, y2) = punto(angoli[(k + 1) % raggi_n], f);
            out.push((x1, y1, x2, y2));
        }
    }
    out
}

/// Anelli della ragnatela, come frazioni dell'ellisse dei nodi.
pub const ANELLI: [f64; 4] = [0.45, 0.65, 0.85, 1.1];
/// Raggi di sfondo della ragnatela.
pub const RAGGI: usize = 16;

/// Curva d'uscita cubica per l'animazione: veloce all'inizio, morbida alla fine.
pub fn uscita_cubica(t: f64) -> f64 {
    let t = t.clamp(0.0, 1.0);
    1.0 - (1.0 - t).powi(3)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direzione {
    Su,
    Giu,
    Sinistra,
    Destra,
}

/// Nodo verso cui spostarsi da `da` premendo una freccia: tra quelli che stanno in
/// quella direzione, il più vicino, preferendo quelli allineati. `None` se non ce n'è.
pub fn vicino(nodi: &[Rett], da: usize, dir: Direzione) -> Option<usize> {
    let (dx, dy) = match dir {
        Direzione::Su => (0.0, -1.0),
        Direzione::Giu => (0.0, 1.0),
        Direzione::Sinistra => (-1.0, 0.0),
        Direzione::Destra => (1.0, 0.0),
    };
    let (x0, y0) = nodi.get(da)?.centro();
    nodi.iter()
        .enumerate()
        .filter(|&(j, _)| j != da)
        .filter_map(|(j, r)| {
            let (x, y) = r.centro();
            let (vx, vy) = (x - x0, y - y0);
            let avanti = vx * dx + vy * dy;
            let di_lato = (vx * dy - vy * dx).abs();
            // soglia minima: un nodo quasi alla stessa altezza non conta come "sopra"
            (avanti > 1.0).then_some((j, avanti + 2.0 * di_lato))
        })
        .min_by(|a, b| a.1.total_cmp(&b.1))
        .map(|(j, _)| j)
}

#[cfg(test)]
mod tests {
    use super::*;

    const L: f64 = 1366.0;
    const A: f64 = 768.0;
    // dimensioni usate dal menù (view.rs)
    const W: f64 = crate::view::NODO_W;
    const H: f64 = crate::view::NODO_H;

    #[test]
    fn da_uno_a_otto_fili_senza_sovrapposizioni_su_1366x768() {
        let c = centro(L, A, crate::view::CENTRO_W, crate::view::CENTRO_H);
        for n in 1..=8 {
            let p = posizioni(n, L, A, W, H);
            assert_eq!(p.len(), n);
            for (i, a) in p.iter().enumerate() {
                assert!(a.dentro(L, A), "n={n}: nodo {i} fuori dallo schermo: {a:?}");
                assert!(!a.si_sovrappone(&c), "n={n}: nodo {i} copre il centro");
                for (j, b) in p.iter().enumerate().skip(i + 1) {
                    assert!(!a.si_sovrappone(b), "n={n}: nodi {i} e {j} sovrapposti");
                }
            }
        }
    }

    #[test]
    fn il_primo_e_in_alto_e_si_gira_in_senso_orario() {
        let p = posizioni(4, L, A, W, H);
        let c: Vec<_> = p.iter().map(Rett::centro).collect();
        assert!((c[0].0 - L / 2.0).abs() < 0.5 && c[0].1 < A / 2.0); // in alto
        assert!(c[1].0 > L / 2.0); // a destra
        assert!(c[2].1 > A / 2.0); // in basso
        assert!(c[3].0 < L / 2.0); // a sinistra
    }

    #[test]
    fn frecce_su_quattro_nodi() {
        let p = posizioni(4, L, A, W, H); // 0 alto, 1 destra, 2 basso, 3 sinistra
        assert_eq!(vicino(&p, 0, Direzione::Destra), Some(1));
        assert_eq!(vicino(&p, 0, Direzione::Sinistra), Some(3));
        assert_eq!(vicino(&p, 0, Direzione::Giu), Some(2));
        assert_eq!(vicino(&p, 0, Direzione::Su), None);
        assert_eq!(vicino(&p, 1, Direzione::Sinistra), Some(3));
        assert_eq!(vicino(&p, 2, Direzione::Su), Some(0));
    }

    #[test]
    fn frecce_con_due_nodi() {
        let p = posizioni(2, L, A, W, H); // 0 alto, 1 basso
        assert_eq!(vicino(&p, 0, Direzione::Giu), Some(1));
        assert_eq!(vicino(&p, 1, Direzione::Su), Some(0));
        assert_eq!(vicino(&p, 0, Direzione::Destra), None);
    }

    #[test]
    fn ragnatela_completa_dentro_lo_schermo_e_fuori_dal_centro() {
        let (rx, ry) = raggi(L, A, W, H);
        let lib = libero(crate::view::CENTRO_W, crate::view::CENTRO_H);
        let s = ragnatela((L / 2.0, A / 2.0), (rx, ry), lib, 16, &ANELLI, 1.0);
        assert_eq!(s.len(), 16 + 4 * 16);
        let c = centro(L, A, crate::view::CENTRO_W, crate::view::CENTRO_H);
        for &(x1, y1, x2, y2) in &s {
            for (x, y) in [(x1, y1), (x2, y2)] {
                assert!((0.0..=L).contains(&x) && (0.0..=A).contains(&y), "fuori: {x},{y}");
                let dentro_centro = x > c.x && x < c.x + c.w && y > c.y && y < c.y + c.h;
                assert!(!dentro_centro, "un filo entra nel centro: {x},{y}");
            }
        }
    }

    #[test]
    fn ragnatela_cresce_con_l_animazione() {
        let (rx, ry) = raggi(L, A, W, H);
        let lib = (110.0, 60.0);
        let anelli = ANELLI;
        let all_inizio = ragnatela((683.0, 384.0), (rx, ry), lib, 16, &anelli, 0.0);
        let a_meta = ragnatela((683.0, 384.0), (rx, ry), lib, 16, &anelli, 0.5);
        let alla_fine = ragnatela((683.0, 384.0), (rx, ry), lib, 16, &anelli, 1.0);
        assert!(all_inizio.is_empty());
        assert!(a_meta.len() < alla_fine.len());
        assert!((uscita_cubica(0.0)).abs() < 1e-9 && (uscita_cubica(1.0) - 1.0).abs() < 1e-9);
        assert!(uscita_cubica(0.5) > 0.5);
    }

    #[test]
    fn un_solo_nodo_o_indice_sbagliato() {
        let p = posizioni(1, L, A, W, H);
        assert_eq!(vicino(&p, 0, Direzione::Giu), None);
        assert_eq!(vicino(&p, 5, Direzione::Giu), None);
    }
}
