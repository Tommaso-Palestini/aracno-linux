//! octod — servizio di sistema di Octopus (spec: docs/spec/SPEC-octod.md, ADR-0008).
//! Gira come utente `octopus`, attivato via D-Bus.
//! Metodi: ListTentacles (lettura libera), Switch (polkit: sessione attiva).

mod auth;
mod error;
mod list;
mod switch;
mod systemd;

use error::OctoError;
use octopus_proto::{TentacleName, TentacleState, ACTION_SWITCH, BUS_NAME, OBJECT_PATH};
use std::process::ExitCode;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;
use zbus::message::Header;
use zbus::object_server::SignalEmitter;
use zbus::{interface, Connection};

#[derive(Default)]
struct Manager {
    /// Vero mentre uno switch è in corso: un secondo switch riceve Busy.
    occupato: AtomicBool,
}

/// Libera `occupato` quando lo switch finisce, anche in caso di errore.
struct Turno<'a>(&'a AtomicBool);
impl Drop for Turno<'_> {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
}

/// Stato attuale di tutti i tentacoli, insieme ai dati della unit (per ListTentacles).
async fn tentacoli(
    conn: &Connection,
) -> Result<Vec<(TentacleName, Option<list::UnitInfo>)>, OctoError> {
    let imgs = systemd::image_names(conn)
        .await
        .map_err(|e| OctoError::internal("machined", e))?;
    let mut out = Vec::new();
    for n in list::tentacle_names(imgs) {
        let info = systemd::unit_info(conn, &n)
            .await
            .map_err(|e| OctoError::internal("systemd", e))?;
        out.push((n, info));
    }
    Ok(out)
}

fn stato(info: Option<&list::UnitInfo>) -> Result<TentacleState, OctoError> {
    match info {
        None => Ok(TentacleState::Off),
        Some(u) => TentacleState::from_systemd(&u.active_state, &u.freezer_state)
            .map_err(|e| OctoError::internal("stato", e)),
    }
}

// Il nome deve essere una stringa letterale per la macro: il test
// `nome_interfaccia_coerente` controlla che coincida con octopus_proto::INTERFACE.
#[interface(name = "io.github.tommaso_palestini.Octopus1.Manager")]
impl Manager {
    /// a(sstt): nome, stato (active|frozen|off), RAM in byte, limite in byte (0 = nessuno).
    async fn list_tentacles(
        &self,
        #[zbus(connection)] conn: &Connection,
    ) -> Result<Vec<list::Entry>, OctoError> {
        let mut righe = Vec::new();
        for (n, info) in tentacoli(conn).await? {
            righe.push(
                list::entry(&n, info.as_ref()).map_err(|e| OctoError::internal("elenco", e))?,
            );
        }
        Ok(righe)
    }

    /// Congela gli altri tentacoli attivi e attiva `name`. Restituisce i millisecondi.
    /// Ordine dei controlli: nome valido, permesso polkit, nessuno switch in corso, tentacolo esistente.
    async fn switch(
        &self,
        name: &str,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> Result<u32, OctoError> {
        let t0 = Instant::now();
        let uid = auth::caller_uid(conn, &header).await;
        let chi = uid.map_or("uid ?".to_string(), |u| format!("uid {u}"));

        let target = TentacleName::try_from(name).map_err(|_| {
            eprintln!("octod: switch rifiutato ({chi}): nome non valido {name:?}");
            OctoError::InvalidName("nome di tentacolo non valido".into())
        })?;
        if let Err(e) = auth::authorize(conn, &header, ACTION_SWITCH, false).await {
            eprintln!("octod: switch → {target} rifiutato ({chi}): non autorizzato");
            return Err(e);
        }
        if self
            .occupato
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_err()
        {
            eprintln!("octod: switch → {target} rifiutato ({chi}): un altro switch è in corso");
            return Err(OctoError::Busy("un altro switch è in corso".into()));
        }
        let _turno = Turno(&self.occupato);

        let tutti = tentacoli(conn).await?;
        let stati: Vec<(TentacleName, TentacleState)> = tutti
            .iter()
            .map(|(n, i)| stato(i.as_ref()).map(|s| (n.clone(), s)))
            .collect::<Result<_, _>>()?;
        let piano = switch::plan(&stati, &target).ok_or_else(|| {
            eprintln!("octod: switch → {target} rifiutato ({chi}): tentacolo inesistente");
            OctoError::NotFound("tentacolo inesistente".into())
        })?;

        for passo in &piano {
            let (n, nuovo) = match passo {
                switch::Step::Freeze(n) => {
                    systemd::freeze(conn, n)
                        .await
                        .map_err(|e| OctoError::internal(&format!("freeze {n}"), e))?;
                    (n, TentacleState::Frozen)
                }
                switch::Step::Thaw(n) => {
                    systemd::thaw(conn, n)
                        .await
                        .map_err(|e| OctoError::internal(&format!("thaw {n}"), e))?;
                    (n, TentacleState::Active)
                }
                switch::Step::Start(n) => {
                    let ok = systemd::start(conn, n)
                        .await
                        .map_err(|e| OctoError::internal(&format!("start {n}"), e))?;
                    if !ok {
                        return Err(OctoError::internal(
                            &format!("start {n}"),
                            "il job di avvio non è terminato con successo",
                        ));
                    }
                    (n, TentacleState::Active)
                }
            };
            // Un segnale perso non deve far fallire lo switch, che è già avvenuto.
            if let Err(e) = Self::state_changed(&emitter, n.as_str(), nuovo.as_str()).await {
                eprintln!("octod: segnale StateChanged non inviato: {e}");
            }
        }

        let ms = u32::try_from(t0.elapsed().as_millis()).unwrap_or(u32::MAX);
        eprintln!(
            "octod: switch → {target} ({chi}): ok in {ms} ms, {} passi",
            piano.len()
        );
        Ok(ms)
    }

    /// Emesso a ogni cambio di stato di un tentacolo causato da octod.
    #[zbus(signal)]
    async fn state_changed(
        emitter: &SignalEmitter<'_>,
        name: &str,
        state: &str,
    ) -> zbus::Result<()>;
}

async fn run() -> zbus::Result<()> {
    let _conn = zbus::connection::Builder::system()
        .name(BUS_NAME)
        .serve_at(OBJECT_PATH, Manager::default())
        .build()
        .await?;
    eprintln!("octod: in ascolto su {BUS_NAME}");
    std::future::pending::<()>().await;
    Ok(())
}

fn main() -> ExitCode {
    match zbus::block_on(run()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("octod: {e}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn nome_interfaccia_coerente() {
        let sorgente = include_str!("main.rs");
        let atteso = format!("#[interface(name = \"{}\")]", octopus_proto::INTERFACE);
        assert!(sorgente.contains(&atteso));
    }
}
