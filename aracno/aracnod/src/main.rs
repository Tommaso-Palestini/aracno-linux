//! aracnod — servizio di sistema di Aracno (spec: docs/spec/SPEC-aracnod.md, ADR-0008).
//! Gira come utente `aracno`, attivato via D-Bus.
//! Metodi: ListTentacles (lettura libera), Switch (polkit: sessione attiva),
//! Stop (polkit: password di amministratore).

mod auth;
mod error;
mod list;
mod switch;
mod systemd;

use error::AracnoError;
use aracno_proto::{
    TentacleName, TentacleState, ACTION_MANAGE, ACTION_SWITCH, BUS_NAME, OBJECT_PATH,
};
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
) -> Result<Vec<(TentacleName, Option<list::UnitInfo>)>, AracnoError> {
    let imgs = systemd::image_names(conn)
        .await
        .map_err(|e| AracnoError::internal("machined", e))?;
    let mut out = Vec::new();
    for n in list::tentacle_names(imgs) {
        let info = systemd::unit_info(conn, &n)
            .await
            .map_err(|e| AracnoError::internal("systemd", e))?;
        out.push((n, info));
    }
    Ok(out)
}

fn stato(info: Option<&list::UnitInfo>) -> Result<TentacleState, AracnoError> {
    match info {
        None => Ok(TentacleState::Off),
        Some(u) => TentacleState::from_systemd(&u.active_state, &u.freezer_state)
            .map_err(|e| AracnoError::internal("stato", e)),
    }
}

// Il nome deve essere una stringa letterale per la macro: il test
// `nome_interfaccia_coerente` controlla che coincida con aracno_proto::INTERFACE.
#[interface(name = "io.github.tommaso_palestini.Aracno1.Manager")]
impl Manager {
    /// a(sstt): nome, stato (active|frozen|off), RAM in byte, limite in byte (0 = nessuno).
    async fn list_tentacles(
        &self,
        #[zbus(connection)] conn: &Connection,
    ) -> Result<Vec<list::Entry>, AracnoError> {
        let mut righe = Vec::new();
        for (n, info) in tentacoli(conn).await? {
            righe.push(
                list::entry(&n, info.as_ref()).map_err(|e| AracnoError::internal("elenco", e))?,
            );
        }
        Ok(righe)
    }

    /// Congela gli altri tentacoli attivi e attiva `name`. Restituisce i millisecondi.
    /// Permesso: azione `switch` (sessione attiva, senza password).
    async fn switch(
        &self,
        name: &str,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> Result<u32, AracnoError> {
        let op = Operazione::Switch;
        let (target, chi, stati, _turno) = self.prepara(op, name, conn, &header).await?;
        let piano = switch::plan(&stati, &target).ok_or_else(|| inesistente(op, &target, &chi))?;
        esegui(op, &target, &chi, &piano, conn, &emitter).await
    }

    /// Spegne `name` (prima lo scongela se è congelato). Restituisce i millisecondi.
    /// Permesso: azione `manage` (password di amministratore, chiesta dall'agente polkit).
    async fn stop(
        &self,
        name: &str,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> Result<u32, AracnoError> {
        let op = Operazione::Stop;
        let (target, chi, stati, _turno) = self.prepara(op, name, conn, &header).await?;
        let piano =
            switch::plan_stop(&stati, &target).ok_or_else(|| inesistente(op, &target, &chi))?;
        esegui(op, &target, &chi, &piano, conn, &emitter).await
    }

    /// Emesso a ogni cambio di stato di un tentacolo causato da aracnod.
    #[zbus(signal)]
    async fn state_changed(
        emitter: &SignalEmitter<'_>,
        name: &str,
        state: &str,
    ) -> zbus::Result<()>;
}

#[derive(Clone, Copy)]
enum Operazione {
    Switch,
    Stop,
}

impl Operazione {
    fn nome(self) -> &'static str {
        match self {
            Self::Switch => "switch",
            Self::Stop => "stop",
        }
    }
    fn azione(self) -> &'static str {
        match self {
            Self::Switch => ACTION_SWITCH,
            Self::Stop => ACTION_MANAGE,
        }
    }
    /// Solo le operazioni con password possono far comparire la finestra dell'agente polkit.
    fn interattiva(self) -> bool {
        matches!(self, Self::Stop)
    }
}

type Preparato<'a> = (
    TentacleName,
    String,
    Vec<(TentacleName, TentacleState)>,
    Turno<'a>,
);

impl Manager {
    /// Controlli comuni, in quest'ordine: nome valido, permesso polkit, nessuna
    /// operazione in corso. Restituisce anche lo stato di tutti i tentacoli.
    async fn prepara(
        &self,
        op: Operazione,
        name: &str,
        conn: &Connection,
        header: &Header<'_>,
    ) -> Result<Preparato<'_>, AracnoError> {
        let uid = auth::caller_uid(conn, header).await;
        let chi = uid.map_or("uid ?".to_string(), |u| format!("uid {u}"));
        let o = op.nome();

        let target = TentacleName::try_from(name).map_err(|_| {
            eprintln!("aracnod: {o} rifiutato ({chi}): nome non valido {name:?}");
            AracnoError::InvalidName("nome di tentacolo non valido".into())
        })?;
        if let Err(e) = auth::authorize(conn, header, op.azione(), op.interattiva()).await {
            eprintln!("aracnod: {o} {target} rifiutato ({chi}): non autorizzato");
            return Err(e);
        }
        if self
            .occupato
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_err()
        {
            eprintln!("aracnod: {o} {target} rifiutato ({chi}): un'altra operazione è in corso");
            return Err(AracnoError::Busy("un'altra operazione è in corso".into()));
        }
        let turno = Turno(&self.occupato);

        let stati = tentacoli(conn)
            .await?
            .iter()
            .map(|(n, i)| stato(i.as_ref()).map(|s| (n.clone(), s)))
            .collect::<Result<_, _>>()?;
        Ok((target, chi, stati, turno))
    }
}

fn inesistente(op: Operazione, target: &TentacleName, chi: &str) -> AracnoError {
    eprintln!(
        "aracnod: {} {target} rifiutato ({chi}): tentacolo inesistente",
        op.nome()
    );
    AracnoError::NotFound("tentacolo inesistente".into())
}

/// Esegue i passi in ordine, emette StateChanged dopo ognuno e registra l'esito.
async fn esegui(
    op: Operazione,
    target: &TentacleName,
    chi: &str,
    piano: &[switch::Step],
    conn: &Connection,
    emitter: &SignalEmitter<'_>,
) -> Result<u32, AracnoError> {
    let t0 = Instant::now();
    let job_ok = |ok: bool, cosa: &str| {
        if ok {
            Ok(())
        } else {
            Err(AracnoError::internal(
                cosa,
                "il job non è terminato con successo",
            ))
        }
    };
    for passo in piano {
        let (n, nuovo) = match passo {
            switch::Step::Freeze(n) => {
                systemd::freeze(conn, n)
                    .await
                    .map_err(|e| AracnoError::internal(&format!("freeze {n}"), e))?;
                (n, TentacleState::Frozen)
            }
            switch::Step::Thaw(n) => {
                systemd::thaw(conn, n)
                    .await
                    .map_err(|e| AracnoError::internal(&format!("thaw {n}"), e))?;
                (n, TentacleState::Active)
            }
            switch::Step::Start(n) => {
                let ok = systemd::start(conn, n)
                    .await
                    .map_err(|e| AracnoError::internal(&format!("start {n}"), e))?;
                job_ok(ok, &format!("start {n}"))?;
                (n, TentacleState::Active)
            }
            switch::Step::Stop(n) => {
                let ok = systemd::stop(conn, n)
                    .await
                    .map_err(|e| AracnoError::internal(&format!("stop {n}"), e))?;
                job_ok(ok, &format!("stop {n}"))?;
                (n, TentacleState::Off)
            }
        };
        // Un segnale perso non deve far fallire l'operazione, che è già avvenuta.
        if let Err(e) = Manager::state_changed(emitter, n.as_str(), nuovo.as_str()).await {
            eprintln!("aracnod: segnale StateChanged non inviato: {e}");
        }
    }
    let ms = u32::try_from(t0.elapsed().as_millis()).unwrap_or(u32::MAX);
    eprintln!(
        "aracnod: {} {target} ({chi}): ok in {ms} ms, {} passi",
        op.nome(),
        piano.len()
    );
    Ok(ms)
}

async fn run() -> zbus::Result<()> {
    let _conn = zbus::connection::Builder::system()
        .name(BUS_NAME)
        .serve_at(OBJECT_PATH, Manager::default())
        .build()
        .await?;
    eprintln!("aracnod: in ascolto su {BUS_NAME}");
    std::future::pending::<()>().await;
    Ok(())
}

fn main() -> ExitCode {
    match zbus::block_on(run()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("aracnod: {e}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn nome_interfaccia_coerente() {
        let sorgente = include_str!("main.rs");
        let atteso = format!("#[interface(name = \"{}\")]", aracno_proto::INTERFACE);
        assert!(sorgente.contains(&atteso));
    }
}
