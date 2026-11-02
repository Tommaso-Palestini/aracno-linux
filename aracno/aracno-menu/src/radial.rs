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

/// Posizioni di `n` nodi grandi w×h su uno schermo larg×alt.
pub fn posizioni(n: usize, larg: f64, alt: f64, w: f64, h: f64) -> Vec<Rett> {
    let (cx, cy) = (larg / 2.0, alt / 2.0);
    let rx = ((larg - w) / 2.0 - MARGINE).max(0.0) * PROPORZIONE;
    let ry = ((alt - h) / 2.0 - MARGINE).max(0.0) * PROPORZIONE;
    (0..n)
        .map(|k| {
            let a = -std::f64::consts::FRAC_PI_2 + std::f64::consts::TAU * k as f64 / n as f64;
            Rett { x: cx + rx * a.cos() - w / 2.0, y: cy + ry * a.sin() - h / 2.0, w, h }
        })
        .collect()
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
    fn un_solo_nodo_o_indice_sbagliato() {
        let p = posizioni(1, L, A, W, H);
        assert_eq!(vicino(&p, 0, Direzione::Giu), None);
        assert_eq!(vicino(&p, 5, Direzione::Giu), None);
    }
}
