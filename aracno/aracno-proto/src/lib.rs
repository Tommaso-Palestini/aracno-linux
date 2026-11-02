//! Interfaccia condivisa tra `aracnod` e i suoi client (menù, CLI).
//! Contiene i nomi D-Bus, le azioni polkit e i tipi validati.
//! Spec: docs/spec/SPEC-aracnod.md. Decisione: docs/adr/0008-aracnod-servizio-di-sistema.md.

use std::fmt;
use std::str::FromStr;

pub mod client;

/// Nome sul bus di sistema (DNS inverso del repo GitHub).
pub const BUS_NAME: &str = "io.github.tommaso_palestini.Aracno1";
/// Percorso dell'oggetto esportato da `aracnod`.
pub const OBJECT_PATH: &str = "/io/github/tommaso_palestini/Aracno1";
/// Interfaccia con i metodi `ListStrands`, `Switch`, `Stop`.
pub const INTERFACE: &str = "io.github.tommaso_palestini.Aracno1.Manager";

/// Azione polkit per lo switch: senza password nella sessione attiva.
pub const ACTION_SWITCH: &str = "io.github.tommaso_palestini.Aracno1.switch";
/// Azione polkit per stop (e future operazioni di gestione): password di amministratore.
pub const ACTION_MANAGE: &str = "io.github.tommaso_palestini.Aracno1.manage";

/// Nomi degli errori D-Bus restituiti da `aracnod`.
pub mod error_names {
    pub const NOT_FOUND: &str = "io.github.tommaso_palestini.Aracno1.Error.NotFound";
    pub const INVALID_NAME: &str = "io.github.tommaso_palestini.Aracno1.Error.InvalidName";
    pub const NOT_AUTHORIZED: &str = "io.github.tommaso_palestini.Aracno1.Error.NotAuthorized";
    pub const BUSY: &str = "io.github.tommaso_palestini.Aracno1.Error.Busy";
    pub const FAILED: &str = "io.github.tommaso_palestini.Aracno1.Error.Failed";
}

/// Lunghezza massima di un nome (come un'etichetta DNS).
pub const MAX_NAME_LEN: usize = 63;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ProtoError {
    #[error("nome di filo non valido")]
    InvalidName,
    #[error("stato di systemd sconosciuto: {0}")]
    UnknownState(String),
}

/// Nome di filo già validato: `^[a-z0-9][a-z0-9-]{0,62}$`.
/// È l'unico tipo accettato dalle operazioni, quindi un nome non validato
/// non può arrivare a systemd. Lo stesso schema è nella regola polkit.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct StrandName(String);

impl StrandName {
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Unit systemd del filo, es. `systemd-nspawn@arch.service`.
    pub fn unit_name(&self) -> String {
        format!("systemd-nspawn@{}.service", self.0)
    }
}

impl TryFrom<&str> for StrandName {
    type Error = ProtoError;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let ammesso = |b: u8| b.is_ascii_lowercase() || b.is_ascii_digit();
        let b = s.as_bytes();
        let ok = !b.is_empty()
            && b.len() <= MAX_NAME_LEN
            && ammesso(b[0])
            && b.iter().all(|&c| ammesso(c) || c == b'-');
        if ok {
            Ok(Self(s.to_owned()))
        } else {
            Err(ProtoError::InvalidName)
        }
    }
}

impl fmt::Display for StrandName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Stato di un filo come lo vede l'utente.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StrandState {
    Active,
    Frozen,
    Off,
}

impl StrandState {
    /// Forma usata sul bus: `active`, `frozen`, `off`.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Frozen => "frozen",
            Self::Off => "off",
        }
    }

    /// Stato a partire dalle proprietà `ActiveState` e `FreezerState` della unit.
    /// Un congelamento in corso (`freezing`) conta già come congelato e uno
    /// scongelamento in corso (`thawing`) come attivo: è lo stato verso cui si va.
    pub fn from_systemd(active_state: &str, freezer_state: &str) -> Result<Self, ProtoError> {
        let acceso = match active_state {
            "active" | "reloading" | "activating" | "deactivating" => true,
            "inactive" | "failed" => false,
            altro => return Err(ProtoError::UnknownState(altro.to_owned())),
        };
        if !acceso {
            return Ok(Self::Off);
        }
        match freezer_state {
            "running" | "thawing" => Ok(Self::Active),
            "frozen" | "freezing" => Ok(Self::Frozen),
            altro => Err(ProtoError::UnknownState(altro.to_owned())),
        }
    }
}

impl FromStr for StrandState {
    type Err = ProtoError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "active" => Ok(Self::Active),
            "frozen" => Ok(Self::Frozen),
            "off" => Ok(Self::Off),
            altro => Err(ProtoError::UnknownState(altro.to_owned())),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nomi_validi() {
        let lungo = "a".repeat(MAX_NAME_LEN);
        for n in [
            "debian",
            "arch",
            "a",
            "0",
            "a-b",
            "fedora-41",
            lungo.as_str(),
        ] {
            assert_eq!(
                StrandName::try_from(n).map(|t| t.as_str().to_owned()),
                Ok(n.to_owned()),
                "{n:?}"
            );
        }
    }

    #[test]
    fn nomi_non_validi() {
        let troppo_lungo = "a".repeat(MAX_NAME_LEN + 1);
        for n in [
            "",
            "Debian",
            "ARCH",
            "../etc",
            "a/b",
            "a b",
            " arch",
            "arch ",
            "-arch",
            "arch\n",
            "arch.service",
            "a_b",
            "über",
            "arch@x",
            troppo_lungo.as_str(),
        ] {
            assert_eq!(
                StrandName::try_from(n),
                Err(ProtoError::InvalidName),
                "{n:?}"
            );
        }
    }

    #[test]
    fn unit_del_filo() {
        let t = StrandName::try_from("arch").unwrap();
        assert_eq!(t.unit_name(), "systemd-nspawn@arch.service");
    }

    #[test]
    fn stato_da_systemd() {
        use StrandState::*;
        let casi = [
            ("active", "running", Active),
            ("active", "thawing", Active),
            ("active", "frozen", Frozen),
            ("active", "freezing", Frozen),
            ("reloading", "running", Active),
            ("activating", "running", Active),
            ("deactivating", "running", Active),
            ("inactive", "running", Off),
            ("failed", "running", Off),
            ("inactive", "", Off),
        ];
        for (a, f, atteso) in casi {
            assert_eq!(StrandState::from_systemd(a, f), Ok(atteso), "{a}/{f}");
        }
    }

    #[test]
    fn stato_sconosciuto_non_viene_nascosto() {
        assert_eq!(
            StrandState::from_systemd("boh", "running"),
            Err(ProtoError::UnknownState("boh".into()))
        );
        assert_eq!(
            StrandState::from_systemd("active", "boh"),
            Err(ProtoError::UnknownState("boh".into()))
        );
    }

    /// La regola polkit deve usare lo stesso schema di `StrandName`:
    /// se uno dei due cambia e l'altro no, questo test fallisce.
    #[test]
    fn regola_polkit_coerente_con_i_nomi() {
        let regola = include_str!("../../data/polkit/50-aracno.rules");
        let schema = format!(
            r"/^systemd-nspawn@[a-z0-9][a-z0-9-]{{0,{}}}\.service$/",
            MAX_NAME_LEN - 1
        );
        assert!(
            regola.contains(&schema),
            "la regola polkit non contiene {schema}"
        );
    }

    #[test]
    fn stato_andata_e_ritorno_sul_bus() {
        for s in [
            StrandState::Active,
            StrandState::Frozen,
            StrandState::Off,
        ] {
            assert_eq!(s.as_str().parse::<StrandState>(), Ok(s));
        }
        assert!("Active".parse::<StrandState>().is_err());
    }
}
