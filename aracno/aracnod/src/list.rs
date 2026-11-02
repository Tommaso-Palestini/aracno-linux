//! Logica pura di ListStrands: niente D-Bus qui, così si testa senza systemd.

use aracno_proto::{ProtoError, StrandName, StrandState};

/// Valori di una unit `systemd-nspawn@NOME.service` letti da systemd.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnitInfo {
    pub active_state: String,
    pub freezer_state: String,
    /// `MemoryCurrent` del servizio; u64::MAX = sconosciuto.
    pub memory_current: u64,
    /// `MemoryMax` del servizio; u64::MAX = nessun limite.
    pub memory_max: u64,
}

/// Una riga di ListStrands, firma D-Bus `(sstt)`: nome, stato, RAM in byte, limite in byte (0 = nessuno).
pub type Entry = (String, String, u64, u64);

/// Tiene solo i nomi validi come filo (scarta per esempio `.host`), ordinati e senza doppioni.
pub fn strand_names<I: IntoIterator<Item = String>>(images: I) -> Vec<StrandName> {
    let mut nomi: Vec<StrandName> = images
        .into_iter()
        .filter_map(|s| StrandName::try_from(s.as_str()).ok())
        .collect();
    nomi.sort_by(|a, b| a.as_str().cmp(b.as_str()));
    nomi.dedup();
    nomi
}

/// Riga dell'elenco. `None` = unit non caricata in systemd, cioè filo spento.
pub fn entry(name: &StrandName, unit: Option<&UnitInfo>) -> Result<Entry, ProtoError> {
    let Some(u) = unit else {
        return Ok((name.to_string(), StrandState::Off.as_str().into(), 0, 0));
    };
    let stato = StrandState::from_systemd(&u.active_state, &u.freezer_state)?;
    let noto = |v: u64| if v == u64::MAX { 0 } else { v };
    let (ram, limite) = match stato {
        StrandState::Off => (0, 0),
        _ => (noto(u.memory_current), noto(u.memory_max)),
    };
    Ok((name.to_string(), stato.as_str().into(), ram, limite))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn n(s: &str) -> StrandName {
        StrandName::try_from(s).unwrap()
    }

    fn info(a: &str, f: &str, cur: u64, max: u64) -> UnitInfo {
        UnitInfo {
            active_state: a.into(),
            freezer_state: f.into(),
            memory_current: cur,
            memory_max: max,
        }
    }

    #[test]
    fn nomi_delle_immagini() {
        let imgs = ["debian", ".host", "arch", "Bad Name", "debian", "a/b"].map(String::from);
        let nomi: Vec<String> = strand_names(imgs).iter().map(|t| t.to_string()).collect();
        assert_eq!(nomi, ["arch", "debian"]);
    }

    #[test]
    fn filo_non_caricato_e_spento() {
        assert_eq!(
            entry(&n("arch"), None),
            Ok(("arch".into(), "off".into(), 0, 0))
        );
    }

    #[test]
    fn attivo_con_memoria_e_senza_limite() {
        let i = info("active", "running", 83 << 20, u64::MAX);
        assert_eq!(
            entry(&n("debian"), Some(&i)),
            Ok(("debian".into(), "active".into(), 83 << 20, 0))
        );
    }

    #[test]
    fn congelato_con_limite() {
        let i = info("active", "frozen", 27 << 20, 256 << 20);
        assert_eq!(
            entry(&n("arch"), Some(&i)),
            Ok(("arch".into(), "frozen".into(), 27 << 20, 256 << 20))
        );
    }

    #[test]
    fn memoria_sconosciuta_vale_zero() {
        let i = info("active", "running", u64::MAX, u64::MAX);
        assert_eq!(entry(&n("arch"), Some(&i)).map(|e| e.2), Ok(0));
    }

    #[test]
    fn unit_caricata_ma_spenta() {
        let i = info("inactive", "running", 12345, u64::MAX);
        assert_eq!(
            entry(&n("arch"), Some(&i)),
            Ok(("arch".into(), "off".into(), 0, 0))
        );
    }

    #[test]
    fn stato_sconosciuto_e_un_errore() {
        let i = info("boh", "running", 0, u64::MAX);
        assert!(entry(&n("arch"), Some(&i)).is_err());
    }
}
