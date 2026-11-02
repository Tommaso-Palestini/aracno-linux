//! Lato client di aracnod, condiviso dal comando `aracno` e da `aracno-menu`:
//! proxy D-Bus, lettura delle righe di ListStrands, messaggi d'errore per l'utente.

use crate::{error_names as en, StrandState};
use zbus::proxy;

// Le stringhe devono essere letterali per la macro: il test `proxy_coerente`
// controlla che coincidano con BUS_NAME, INTERFACE e OBJECT_PATH.
#[proxy(
    interface = "io.github.tommaso_palestini.Aracno1.Manager",
    default_service = "io.github.tommaso_palestini.Aracno1",
    default_path = "/io/github/tommaso_palestini/Aracno1"
)]
pub trait Manager {
    fn list_strands(&self) -> zbus::Result<Vec<(String, String, u64, u64)>>;
    fn switch(&self, name: &str) -> zbus::Result<u32>;
    #[zbus(allow_interactive_auth)]
    fn stop(&self, name: &str) -> zbus::Result<u32>;
    #[zbus(signal)]
    fn state_changed(&self, name: String, state: String) -> zbus::Result<()>;
}

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

/// Chiede l'elenco dei fili ad aracnod.
pub async fn fili(m: &ManagerProxy<'_>) -> Result<Vec<Filo>, String> {
    da_righe(m.list_strands().await.map_err(|e| messaggio(&e))?)
}

/// Ordine di presentazione: attivo, congelati, spenti; a parità, per nome.
pub fn ordina(fili: &mut [Filo]) {
    let rango = |s: StrandState| match s {
        StrandState::Active => 0,
        StrandState::Frozen => 1,
        StrandState::Off => 2,
    };
    fili.sort_by(|a, b| (rango(a.stato), &a.nome).cmp(&(rango(b.stato), &b.nome)));
}

pub fn stato_it(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "attivo",
        StrandState::Frozen => "congelato",
        StrandState::Off => "spento",
    }
}

/// Simbolo dello stato, da mostrare sempre insieme al testo (non solo colore).
pub fn simbolo(s: StrandState) -> &'static str {
    match s {
        StrandState::Active => "●",
        StrandState::Frozen => "◌",
        StrandState::Off => "·",
    }
}

/// Byte in MiB interi, arrotondati (es. 23146496 → "22 MiB").
pub fn mib(byte: u64) -> String {
    format!("{} MiB", (byte + (1 << 19)) >> 20)
}

/// Messaggio per l'utente a partire dal nome dell'errore D-Bus.
pub fn messaggio_errore(nome: &str) -> &'static str {
    match nome {
        en::NOT_FOUND => "questo filo non esiste",
        en::INVALID_NAME => "nome non valido: solo minuscole, cifre e trattini",
        en::NOT_AUTHORIZED => "permesso negato",
        en::BUSY => "c'è già un cambio di filo in corso, riprova tra un attimo",
        en::FAILED => "aracnod non è riuscito (dettagli: journalctl -u aracnod)",
        "org.freedesktop.DBus.Error.ServiceUnknown" => "aracnod non risponde: è installato?",
        "org.freedesktop.DBus.Error.UnknownMethod" => {
            "aracnod installato è di un'altra versione: reinstallalo (prototype/11-install-aracnod.sh)"
        }
        "org.freedesktop.DBus.Error.AccessDenied" => "il bus di sistema ha rifiutato la chiamata",
        _ => "errore inatteso da aracnod",
    }
}

/// Messaggio per l'utente per qualsiasi errore di zbus.
pub fn messaggio(e: &zbus::Error) -> String {
    use zbus::DBusError;
    match e {
        zbus::Error::MethodError(nome, _, _) => messaggio_errore(nome.as_str()).into(),
        // errori standard di D-Bus (servizio assente, metodo sconosciuto, …)
        zbus::Error::FDO(f) => messaggio_errore(f.name().as_str()).into(),
        _ => format!("bus di sistema non raggiungibile: {e}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn f(nome: &str, stato: StrandState) -> Filo {
        Filo { nome: nome.into(), stato, ram: 0, limite: 0 }
    }

    #[test]
    fn proxy_coerente() {
        let s = include_str!("client.rs");
        assert!(s.contains(&format!("interface = \"{}\"", crate::INTERFACE)));
        assert!(s.contains(&format!("default_service = \"{}\"", crate::BUS_NAME)));
        assert!(s.contains(&format!("default_path = \"{}\"", crate::OBJECT_PATH)));
    }

    #[test]
    fn righe_da_aracnod() {
        let r = da_righe(vec![("arch".into(), "frozen".into(), 1, 0)]).unwrap();
        assert_eq!(r, vec![Filo { ram: 1, ..f("arch", StrandState::Frozen) }]);
        assert!(da_righe(vec![("x".into(), "boh".into(), 0, 0)]).is_err());
    }

    #[test]
    fn ordine_attivo_congelati_spenti() {
        let mut v = vec![
            f("fedora", StrandState::Off),
            f("b", StrandState::Frozen),
            f("a", StrandState::Frozen),
            f("debian", StrandState::Active),
        ];
        ordina(&mut v);
        let nomi: Vec<_> = v.iter().map(|x| x.nome.as_str()).collect();
        assert_eq!(nomi, ["debian", "a", "b", "fedora"]);
    }

    #[test]
    fn errori_tradotti() {
        assert_eq!(
            messaggio_errore(en::BUSY),
            "c'è già un cambio di filo in corso, riprova tra un attimo"
        );
        assert_eq!(messaggio_errore("x.y.Z"), "errore inatteso da aracnod");
    }

    #[test]
    fn mib_arrotondati() {
        assert_eq!(mib(0), "0 MiB");
        assert_eq!(mib(23_146_496), "22 MiB");
        assert_eq!(mib(1 << 20), "1 MiB");
    }
}
