//! Errori D-Bus di aracnod, con i nomi fissati in aracno_proto::error_names.
//! I messaggi verso il client sono brevi e senza dettagli interni.

use zbus::DBusError;

#[derive(Debug, DBusError)]
#[zbus(prefix = "io.github.tommaso_palestini.Aracno1.Error")]
pub enum AracnoError {
    #[zbus(error)]
    ZBus(zbus::Error),
    NotFound(String),
    InvalidName(String),
    NotAuthorized(String),
    Busy(String),
    Failed(String),
}

impl AracnoError {
    /// Errore interno: dettaglio nel journal, messaggio generico al client.
    pub fn internal(contesto: &str, e: impl std::fmt::Display) -> Self {
        eprintln!("aracnod: {contesto}: {e}");
        Self::Failed("errore interno di aracnod (dettagli nel journal)".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aracno_proto::error_names as en;

    #[test]
    fn nomi_degli_errori_coerenti_con_proto() {
        let casi = [
            (AracnoError::NotFound(String::new()), en::NOT_FOUND),
            (AracnoError::InvalidName(String::new()), en::INVALID_NAME),
            (AracnoError::NotAuthorized(String::new()), en::NOT_AUTHORIZED),
            (AracnoError::Busy(String::new()), en::BUSY),
            (AracnoError::Failed(String::new()), en::FAILED),
        ];
        for (e, atteso) in casi {
            assert_eq!(e.name().as_str(), atteso);
        }
    }
}
