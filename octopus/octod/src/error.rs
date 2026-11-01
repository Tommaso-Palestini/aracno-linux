//! Errori D-Bus di octod, con i nomi fissati in octopus_proto::error_names.
//! I messaggi verso il client sono brevi e senza dettagli interni.

use zbus::DBusError;

#[derive(Debug, DBusError)]
#[zbus(prefix = "io.github.tommaso_palestini.Octopus1.Error")]
pub enum OctoError {
    #[zbus(error)]
    ZBus(zbus::Error),
    NotFound(String),
    InvalidName(String),
    NotAuthorized(String),
    Busy(String),
    Failed(String),
}

impl OctoError {
    /// Errore interno: dettaglio nel journal, messaggio generico al client.
    pub fn internal(contesto: &str, e: impl std::fmt::Display) -> Self {
        eprintln!("octod: {contesto}: {e}");
        Self::Failed("errore interno di octod (dettagli nel journal)".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use octopus_proto::error_names as en;

    #[test]
    fn nomi_degli_errori_coerenti_con_proto() {
        let casi = [
            (OctoError::NotFound(String::new()), en::NOT_FOUND),
            (OctoError::InvalidName(String::new()), en::INVALID_NAME),
            (OctoError::NotAuthorized(String::new()), en::NOT_AUTHORIZED),
            (OctoError::Busy(String::new()), en::BUSY),
            (OctoError::Failed(String::new()), en::FAILED),
        ];
        for (e, atteso) in casi {
            assert_eq!(e.name().as_str(), atteso);
        }
    }
}
