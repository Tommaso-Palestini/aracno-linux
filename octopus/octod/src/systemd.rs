//! Proxy D-Bus verso systemd-machined e systemd.
//! Letture: permesse a un utente non privilegiato (T1, P6).
//! Freeze/Thaw/Start: permessi a `octopus` solo sui tentacoli da 50-octopus.rules (T1, P1–P4).

use crate::list::UnitInfo;
use futures_core::Stream;
use octopus_proto::TentacleName;
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
}

const NO_SUCH_UNIT: &str = "org.freedesktop.systemd1.NoSuchUnit";

/// Nomi delle immagini registrate in machined (le cartelle in /var/lib/machines).
pub async fn image_names(conn: &Connection) -> zbus::Result<Vec<String>> {
    let imgs = MachinedProxy::new(conn).await?.list_images().await?;
    Ok(imgs.into_iter().map(|i| i.0).collect())
}

/// Stato e memoria della unit del tentacolo; `None` se systemd non l'ha caricata (spento).
pub async fn unit_info(conn: &Connection, name: &TentacleName) -> zbus::Result<Option<UnitInfo>> {
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
    Ok(Some(UnitInfo {
        active_state: unit.active_state().await?,
        freezer_state: unit.freezer_state().await?,
        memory_current: svc.memory_current().await?,
        memory_max: svc.memory_max().await?,
    }))
}

/// Congela il tentacolo. systemd risponde a congelamento finito.
pub async fn freeze(conn: &Connection, name: &TentacleName) -> zbus::Result<()> {
    SystemdProxy::new(conn)
        .await?
        .freeze_unit(&name.unit_name())
        .await
}

/// Scongela il tentacolo. systemd risponde a scongelamento finito.
pub async fn thaw(conn: &Connection, name: &TentacleName) -> zbus::Result<()> {
    SystemdProxy::new(conn)
        .await?
        .thaw_unit(&name.unit_name())
        .await
}

/// Avvia il tentacolo e aspetta che il job di avvio finisca. Il flusso dei segnali
/// `JobRemoved` si apre PRIMA di StartUnit, così la fine del job non può sfuggire.
/// Il tempo massimo è quello di systemd per l'avvio della unit (TimeoutStartSec).
pub async fn start(conn: &Connection, name: &TentacleName) -> zbus::Result<bool> {
    let mgr = SystemdProxy::new(conn).await?;
    mgr.subscribe().await?;
    let mut fine = mgr.receive_job_removed().await?;
    let job = mgr.start_unit(&name.unit_name(), "replace").await?;
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
