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
    /// Congelamento secondo il kernel (`frozen` in cgroup.events); `None` se non letto.
    pub kernel_frozen: Option<bool>,
}

/// Stato vero del filo e se systemd è disallineato dal kernel.
///
/// systemd 255 non azzera `FreezerState` quando un filo muore mentre è congelato
/// (watchdog, memoria finita…): al riavvio dice "frozen" anche se il kernel non lo
/// è (visto il 2026-11-02 su debian). Con lo stato di systemd uno switch lascerebbe
/// quel filo acceso insieme al nuovo. Quando il kernel è stato letto, vale il kernel.
pub fn stato_reale(u: &UnitInfo) -> Result<(StrandState, bool), ProtoError> {
    let di_systemd = StrandState::from_systemd(&u.active_state, &u.freezer_state)?;
    let reale = match (di_systemd, u.kernel_frozen) {
        (StrandState::Off, _) | (_, None) => di_systemd,
        (_, Some(true)) => StrandState::Frozen,
        (_, Some(false)) => StrandState::Active,
    };
    Ok((reale, reale != di_systemd))
}

/// Legge la riga `frozen 0|1` di cgroup.events.
pub fn congelato_da_eventi(eventi: &str) -> Option<bool> {
    eventi.lines().find_map(|r| match r.trim() {
        "frozen 1" => Some(true),
        "frozen 0" => Some(false),
        _ => None,
    })
}

/// Percorso di cgroup.events per il ControlGroup di un filo, solo se ha la forma
/// attesa (`/machine.slice/systemd-nspawn@NOME.service`): niente `..`, niente altro.
pub fn file_eventi(control_group: &str, name: &StrandName) -> Option<String> {
    let atteso = format!("/machine.slice/{}", name.unit_name());
    (control_group == atteso).then(|| format!("/sys/fs/cgroup{atteso}/cgroup.events"))
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
    let (stato, _) = stato_reale(u)?;
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
            kernel_frozen: None,
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
    fn systemd_dice_congelato_ma_il_kernel_no() {
        // il caso di debian del 2026-11-02, dopo la morte da congelato
        let i = UnitInfo { kernel_frozen: Some(false), ..info("active", "frozen", 1, u64::MAX) };
        assert_eq!(stato_reale(&i), Ok((StrandState::Active, true)));
        assert_eq!(entry(&n("debian"), Some(&i)).map(|e| e.1), Ok("active".into()));
    }

    #[test]
    fn kernel_congelato_ma_systemd_no() {
        let i = UnitInfo { kernel_frozen: Some(true), ..info("active", "running", 1, u64::MAX) };
        assert_eq!(stato_reale(&i), Ok((StrandState::Frozen, true)));
    }

    #[test]
    fn d_accordo_o_kernel_non_letto() {
        let ok = UnitInfo { kernel_frozen: Some(true), ..info("active", "frozen", 1, u64::MAX) };
        assert_eq!(stato_reale(&ok), Ok((StrandState::Frozen, false)));
        let senza = info("active", "frozen", 1, u64::MAX);
        assert_eq!(stato_reale(&senza), Ok((StrandState::Frozen, false)));
        let spento = UnitInfo { kernel_frozen: Some(true), ..info("inactive", "frozen", 0, u64::MAX) };
        assert_eq!(stato_reale(&spento), Ok((StrandState::Off, false)));
    }

    #[test]
    fn lettura_di_cgroup_events() {
        assert_eq!(congelato_da_eventi("populated 1\nfrozen 1\n"), Some(true));
        assert_eq!(congelato_da_eventi("populated 1\nfrozen 0\n"), Some(false));
        assert_eq!(congelato_da_eventi("populated 0\n"), None);
        assert_eq!(congelato_da_eventi(""), None);
    }

    #[test]
    fn percorso_di_cgroup_events_solo_se_atteso() {
        assert_eq!(
            file_eventi("/machine.slice/systemd-nspawn@arch.service", &n("arch")),
            Some("/sys/fs/cgroup/machine.slice/systemd-nspawn@arch.service/cgroup.events".into())
        );
        assert_eq!(file_eventi("/machine.slice/systemd-nspawn@debian.service", &n("arch")), None);
        assert_eq!(file_eventi("/machine.slice/../../etc", &n("arch")), None);
        assert_eq!(file_eventi("", &n("arch")), None);
    }

    #[test]
    fn stato_sconosciuto_e_un_errore() {
        let i = info("boh", "running", 0, u64::MAX);
        assert!(entry(&n("arch"), Some(&i)).is_err());
    }
}
