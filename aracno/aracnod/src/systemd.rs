//! Proxy D-Bus verso systemd-machined e systemd.
//! Letture: permesse a un utente non privilegiato (T1, P6).
//! Freeze/Thaw/Start: permessi a `aracno` solo sui fili da 50-aracno.rules (T1, P1–P4).

use crate::list::UnitInfo;
use futures_core::Stream;
use aracno_proto::StrandName;
use std::pin::Pin;
use zbus::proxy::CacheProperties;
use zbus::{proxy, Connection, OwnedObjectPath};

#[proxy(
    interface = "org.freedesktop.machine1.Manager",
    default_service = "org.freedesktop.machine1",
    default_path = "/org/freedesktop/machine1"
)]
pub trait Machined {
    /// a(ssbttto): nome, tipo, sola lettura, creazione, modifica, uso disco, oggetto.
    #[allow(clippy::type_complexity)]
    fn list_images(
        &self,
    ) -> zbus::Result<Vec<(String, String, bool, u64, u64, u64, OwnedObjectPath)>>;
}

#[proxy(
    interface = "org.freedesktop.systemd1.Manager",
    default_service = "org.freedesktop.systemd1",
    default_path = "/org/freedesktop/systemd1"
)]
pub trait Systemd {
    fn get_unit(&self, name: &str) -> zbus::Result<OwnedObjectPath>;
    fn freeze_unit(&self, name: &str) -> zbus::Result<()>;
    fn thaw_unit(&self, name: &str) -> zbus::Result<()>;
    fn start_unit(&self, name: &str, mode: &str) -> zbus::Result<OwnedObjectPath>;
    fn stop_unit(&self, name: &str, mode: &str) -> zbus::Result<OwnedObjectPath>;
    /// Chiede a systemd di mandare i segnali dei job a questa connessione.
    fn subscribe(&self) -> zbus::Result<()>;
    #[zbus(signal)]
    fn job_removed(
        &self,
        id: u32,
        job: OwnedObjectPath,
        unit: String,
        result: String,
    ) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.systemd1.Unit",
    default_service = "org.freedesktop.systemd1",
    default_path = "/org/freedesktop/systemd1/unit"
)]
pub trait Unit {
    #[zbus(property)]
    fn active_state(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn freezer_state(&self) -> zbus::Result<String>;
}

#[proxy(
    interface = "org.freedesktop.systemd1.Service",
    default_service = "org.freedesktop.systemd1",
    default_path = "/org/freedesktop/systemd1/unit"
)]
pub trait Service {
    #[zbus(property)]
    fn memory_current(&self) -> zbus::Result<u64>;
    #[zbus(property)]
    fn memory_max(&self) -> zbus::Result<u64>;
    #[zbus(property)]
    fn control_group(&self) -> zbus::Result<String>;
}

const NO_SUCH_UNIT: &str = "org.freedesktop.systemd1.NoSuchUnit";
const ALREADY_SUBSCRIBED: &str = "org.freedesktop.systemd1.AlreadySubscribed";

/// Nomi delle immagini registrate in machined (le cartelle in /var/lib/machines).
pub async fn image_names(conn: &Connection) -> zbus::Result<Vec<String>> {
    let imgs = MachinedProxy::new(conn).await?.list_images().await?;
    Ok(imgs.into_iter().map(|i| i.0).collect())
}

/// Stato e memoria della unit del filo; `None` se systemd non l'ha caricata (spento).
pub async fn unit_info(conn: &Connection, name: &StrandName) -> zbus::Result<Option<UnitInfo>> {
    let path = match SystemdProxy::new(conn)
        .await?
        .get_unit(&name.unit_name())
        .await
    {
        Ok(p) => p,
        Err(zbus::Error::MethodError(e, _, _)) if e.as_str() == NO_SUCH_UNIT => return Ok(None),
        Err(e) => return Err(e),
    };
    // Niente cache: ogni chiamata deve vedere lo stato di adesso.
    let unit = UnitProxy::builder(conn)
        .path(path.clone())
        .cache_properties(CacheProperties::No)
        .build()
        .await?;
    let svc = ServiceProxy::builder(conn)
        .path(path)
        .cache_properties(CacheProperties::No)
        .build()
        .await?;
    // Stato di congelamento secondo il kernel: systemd 255 può restare indietro
    // (vedi list::stato_reale). Se il file non si legge, si usa solo systemd.
    let kernel_frozen = match svc.control_group().await {
        Ok(cg) => crate::list::file_eventi(&cg, name)
            .and_then(|f| std::fs::read_to_string(f).ok())
            .and_then(|e| crate::list::congelato_da_eventi(&e)),
        Err(_) => None,
    };
    Ok(Some(UnitInfo {
        active_state: unit.active_state().await?,
        freezer_state: unit.freezer_state().await?,
        memory_current: svc.memory_current().await?,
        memory_max: svc.memory_max().await?,
        kernel_frozen,
    }))
}

/// Congela il filo. systemd risponde a congelamento finito.
pub async fn freeze(conn: &Connection, name: &StrandName) -> zbus::Result<()> {
    SystemdProxy::new(conn)
        .await?
        .freeze_unit(&name.unit_name())
        .await
}

/// Scongela il filo. systemd risponde a scongelamento finito.
pub async fn thaw(conn: &Connection, name: &StrandName) -> zbus::Result<()> {
    SystemdProxy::new(conn)
        .await?
        .thaw_unit(&name.unit_name())
        .await
}

/// Avvia il filo e aspetta la fine del job. Vero se il job è riuscito.
pub async fn start(conn: &Connection, name: &StrandName) -> zbus::Result<bool> {
    job(conn, name, true).await
}

/// Spegne il filo e aspetta la fine del job. Vero se il job è riuscito.
pub async fn stop(conn: &Connection, name: &StrandName) -> zbus::Result<bool> {
    job(conn, name, false).await
}

/// StartUnit/StopUnit rispondono subito con un job: si aspetta il segnale `JobRemoved`.
/// Il flusso dei segnali si apre PRIMA della chiamata, così la fine del job non può
/// sfuggire. Il tempo massimo è quello di systemd per la unit (TimeoutStartSec/StopSec).
async fn job(conn: &Connection, name: &StrandName, avvio: bool) -> zbus::Result<bool> {
    let mgr = SystemdProxy::new(conn).await?;
    // Subscribe vale per tutta la connessione: dal secondo job in poi systemd risponde
    // AlreadySubscribed, che significa "già iscritto" e va bene (bug trovato in T7).
    match mgr.subscribe().await {
        Ok(()) => {}
        Err(zbus::Error::MethodError(e, _, _)) if e.as_str() == ALREADY_SUBSCRIBED => {}
        Err(e) => return Err(e),
    }
    let mut fine = mgr.receive_job_removed().await?;
    let unit = name.unit_name();
    let job = if avvio {
        mgr.start_unit(&unit, "replace").await?
    } else {
        mgr.stop_unit(&unit, "replace").await?
    };
    while let Some(sig) = next(&mut fine).await {
        let a = sig.args()?;
        if a.job == job {
            return Ok(a.result == "done");
        }
    }
    Ok(false)
}

/// Prossimo elemento di uno stream, senza dipendere da futures-util.
async fn next<S: Stream + Unpin>(s: &mut S) -> Option<S::Item> {
    std::future::poll_fn(|cx| Pin::new(&mut *s).poll_next(cx)).await
}
