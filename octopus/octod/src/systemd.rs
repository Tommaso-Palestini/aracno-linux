//! Proxy D-Bus verso systemd-machined e systemd. Solo letture in questo modulo,
//! tutte permesse a un utente non privilegiato (verificato in T1, punto P6).

use crate::list::UnitInfo;
use octopus_proto::TentacleName;
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
