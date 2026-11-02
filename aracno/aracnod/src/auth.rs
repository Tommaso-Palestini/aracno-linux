//! Controllo dei permessi del chiamante con polkit. Fallisce chiuso: qualsiasi
//! errore nel parlare con polkit diventa un rifiuto.
//! Le azioni di Aracno hanno `org.freedesktop.policykit.owner = unix-user:aracno`,
//! altrimenti polkit (≥ 0.114, verificato sul sorgente 124) non permetterebbe a un
//! utente non root di controllare i permessi di altri utenti.

use crate::error::AracnoError;
use std::collections::HashMap;
use zbus::message::Header;
use zbus::Connection;
use zbus_polkit::policykit1::{AuthorityProxy, CheckAuthorizationFlags, Subject};

/// Chiede a polkit se il mittente del messaggio può eseguire `action`.
/// `interactive`: polkit può chiedere la password tramite l'agente della sessione.
pub async fn authorize(
    conn: &Connection,
    header: &Header<'_>,
    action: &str,
    interactive: bool,
) -> Result<(), AracnoError> {
    let negato = || AracnoError::NotAuthorized("operazione non permessa".into());
    let subject = Subject::new_for_message_header(header).map_err(|e| {
        eprintln!("aracnod: polkit: mittente non identificabile: {e}");
        negato()
    })?;
    let flags = if interactive {
        CheckAuthorizationFlags::ALLOW_USER_INTERACTION
    } else {
        CheckAuthorizationFlags::empty()
    };
    let esito = async {
        AuthorityProxy::new(conn)
            .await?
            .check_authorization(&subject, action, &HashMap::new(), flags, "")
            .await
    }
    .await;
    match esito {
        Ok(r) if r.is_authorized => Ok(()),
        Ok(_) => Err(negato()),
        Err(e) => {
            eprintln!("aracnod: polkit: {e}");
            Err(negato())
        }
    }
}

/// UID del mittente, solo per il log.
pub async fn caller_uid(conn: &Connection, header: &Header<'_>) -> Option<u32> {
    let sender = header.sender()?.to_owned();
    let dbus = zbus::fdo::DBusProxy::new(conn).await.ok()?;
    dbus.get_connection_unix_user(sender.into()).await.ok()
}
