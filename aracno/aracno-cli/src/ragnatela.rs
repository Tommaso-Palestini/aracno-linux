//! Parte pura del comando `aracno`: come si mostrano i fili e gli errori.
//! Nessun D-Bus qui, così tutto è testabile.

use aracno_proto::{error_names as en, StrandState};

/// Una riga di ListStrands già interpretata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Filo {
    pub nome: String,
    pub stato: StrandState,
    pub ram: u64,
    pub limite: u64,
}

/// Converte le righe a(sstt) di ListStrands. Uno stato sconosciuto è un errore.
pub fn da_righe(righe: Vec<(String, String, u64, u64)>) -> Result<Vec<Filo>, String> {
    righe
        .into_iter()
        .map(|(nome, stato, ram, limite)| {
            let stato = stato
                .parse()
                .map_err(|_| format!("stato sconosciuto da aracnod: {stato:?}"))?;
            Ok(Filo { nome, stato, ram, limite })
        })
        .collect()
}

pub fn stato_it(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "attivo",
        StrandState::Frozen => "congelato",
        StrandState::Off => "spento",
    }
}

fn simbolo(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "●",
        StrandState::Frozen => "◌",
        StrandState::Off => "·",
    }
}

/// Colore ANSI per lo stato: verde attivo, azzurro congelato, grigio spento.
fn colore(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "\x1b[32m",
        StrandState::Frozen => "\x1b[36m",
        StrandState::Off => "\x1b[2m",
    }
}

/// Byte in MiB interi, arrotondati (es. 23146496 → "22 MiB").
pub fn mib(byte: u64) -> String {
    format!("{} MiB", (byte + (1 << 19)) >> 20)
}

fn ordine(s: StrandState) -> u8 {
    match s {
        StrandState::Active => 0,
        StrandState::Frozen => 1,
        StrandState::Off => 2,
    }
}

/// Disegna la ragnatela: prima il filo attivo, poi i congelati, poi gli spenti.
pub fn disegna(fili: &[Filo], colori: bool) -> String {
    let mut fili = fili.to_vec();
    fili.sort_by(|a, b| (ordine(a.stato), &a.nome).cmp(&(ordine(b.stato), &b.nome)));
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

/// Messaggio per l'utente a partire dal nome dell'errore D-Bus.
pub fn messaggio_errore(nome: &str) -> &'static str {
    match nome {
        en::NOT_FOUND => "questo filo non esiste",
        en::INVALID_NAME => "nome non valido: solo minuscole, cifre e trattini",
        en::NOT_AUTHORIZED => "permesso negato",
        en::BUSY => "c'è già un cambio di filo in corso, riprova tra un attimo",
        en::FAILED => "aracnod non è riuscito (dettagli: journalctl -u aracnod)",
        "org.freedesktop.DBus.Error.ServiceUnknown" => {
            "aracnod non risponde: è installato?"
        }
        "org.freedesktop.DBus.Error.UnknownMethod" => {
            "aracnod installato è di un'altra versione: reinstallalo (prototype/11-install-aracnod.sh)"
        }
        "org.freedesktop.DBus.Error.AccessDenied" => "il bus di sistema ha rifiutato la chiamata",
        _ => "errore inatteso da aracnod",
    }
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
    fn righe_da_aracnod() {
        let r = da_righe(vec![("arch".into(), "frozen".into(), 1, 0)]).unwrap();
        assert_eq!(r, vec![f("arch", StrandState::Frozen, 1, 0)]);
        assert!(da_righe(vec![("x".into(), "boh".into(), 0, 0)]).is_err());
    }

    #[test]
    fn filo_attivo() {
        let fili = [
            f("arch", StrandState::Frozen, 0, 0),
            f("debian", StrandState::Active, 0, 0),
        ];
        assert_eq!(attivi(&fili), vec!["debian"]);
    }

    #[test]
    fn errori_tradotti() {
        assert_eq!(messaggio_errore(en::BUSY), "c'è già un cambio di filo in corso, riprova tra un attimo");
        assert_eq!(messaggio_errore("x.y.Z"), "errore inatteso da aracnod");
    }

    #[test]
    fn mib_arrotondati() {
        assert_eq!(mib(0), "0 MiB");
        assert_eq!(mib(23_146_496), "22 MiB");
        assert_eq!(mib(1 << 20), "1 MiB");
    }
}
