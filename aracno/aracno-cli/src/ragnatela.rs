//! Parte pura del comando `aracno`: come si disegna la ragnatela nel terminale.
//! Lettura dei fili e messaggi d'errore stanno in aracno_proto::client.

use aracno_proto::client::{mib, ordina, simbolo, stato_it, Filo};
use aracno_proto::StrandState;

/// Colore ANSI per lo stato: verde attivo, azzurro congelato, grigio spento.
fn colore(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "\x1b[32m",
        StrandState::Frozen => "\x1b[36m",
        StrandState::Off => "\x1b[2m",
    }
}

/// Disegna la ragnatela: prima il filo attivo, poi i congelati, poi gli spenti.
pub fn disegna(fili: &[Filo], colori: bool) -> String {
    let mut fili = fili.to_vec();
    ordina(&mut fili);
    let largo = fili.iter().map(|f| f.nome.chars().count()).max().unwrap_or(0);
    let mut out = String::from("aracno ── ragnatela\n");
    if fili.is_empty() {
        out.push_str("  (nessun filo)\n");
        return out;
    }
    for (i, f) in fili.iter().enumerate() {
        let ramo = if i + 1 == fili.len() { "└─" } else { "├─" };
        let mut riga = format!(
            "{} {:<largo$}  {:<9}",
            simbolo(f.stato),
            f.nome,
            stato_it(f.stato)
        );
        if f.stato != StrandState::Off {
            riga.push_str(&format!("  {:>8}", mib(f.ram)));
            if f.limite > 0 {
                riga.push_str(&format!("  (tetto {})", mib(f.limite)));
            }
        }
        let riga = riga.trim_end();
        if colori {
            out.push_str(&format!("  {ramo}{}{riga}\x1b[0m\n", colore(f.stato)));
        } else {
            out.push_str(&format!("  {ramo}{riga}\n"));
        }
    }
    out
}

/// Nomi dei fili attivi (di norma uno solo).
pub fn attivi(fili: &[Filo]) -> Vec<&str> {
    fili.iter()
        .filter(|f| f.stato == StrandState::Active)
        .map(|f| f.nome.as_str())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn f(nome: &str, stato: StrandState, ram: u64, limite: u64) -> Filo {
        Filo { nome: nome.into(), stato, ram, limite }
    }

    #[test]
    fn ragnatela_ordinata_e_senza_colori() {
        let fili = [
            f("fedora", StrandState::Off, 0, 0),
            f("arch", StrandState::Frozen, 46_043_136, 268_435_456),
            f("debian", StrandState::Active, 23_146_496, 0),
        ];
        assert_eq!(
            disegna(&fili, false),
            "aracno ── ragnatela\n\
             \x20 ├─● debian  attivo       22 MiB\n\
             \x20 ├─◌ arch    congelato    44 MiB  (tetto 256 MiB)\n\
             \x20 └─· fedora  spento\n"
        );
    }

    #[test]
    fn ragnatela_vuota() {
        assert_eq!(disegna(&[], false), "aracno ── ragnatela\n  (nessun filo)\n");
    }

    #[test]
    fn colori_solo_se_chiesti() {
        let fili = [f("debian", StrandState::Active, 0, 0)];
        assert!(disegna(&fili, true).contains("\x1b[32m"));
        assert!(!disegna(&fili, false).contains('\x1b'));
    }

    #[test]
    fn filo_attivo() {
        let fili = [
            f("arch", StrandState::Frozen, 0, 0),
            f("debian", StrandState::Active, 0, 0),
        ];
        assert_eq!(attivi(&fili), vec!["debian"]);
    }
}
