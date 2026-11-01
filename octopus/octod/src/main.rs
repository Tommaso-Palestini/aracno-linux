//! octod — servizio di sistema di Octopus (spec: docs/spec/SPEC-octod.md, ADR-0008).
//! Gira come utente `octopus`, attivato via D-Bus. In T5 espone solo ListTentacles.

mod list;
mod systemd;

use octopus_proto::{BUS_NAME, OBJECT_PATH};
use std::process::ExitCode;
use zbus::{fdo, interface, Connection};

struct Manager;

// Il nome deve essere una stringa letterale per la macro: il test
// `nome_interfaccia_coerente` controlla che coincida con octopus_proto::INTERFACE.
#[interface(name = "io.github.tommaso_palestini.Octopus1.Manager")]
impl Manager {
    /// a(sstt): nome, stato (active|frozen|off), RAM in byte, limite in byte (0 = nessuno).
    async fn list_tentacles(
        &self,
        #[zbus(connection)] conn: &Connection,
    ) -> fdo::Result<Vec<list::Entry>> {
        let nomi = list::tentacle_names(systemd::image_names(conn).await.map_err(fallito)?);
        let mut righe = Vec::with_capacity(nomi.len());
        for n in &nomi {
            let info = systemd::unit_info(conn, n).await.map_err(fallito)?;
            righe.push(
                list::entry(n, info.as_ref()).map_err(|e| fdo::Error::Failed(e.to_string()))?,
            );
        }
        Ok(righe)
    }
}

/// Errore verso il client senza dettagli interni; il dettaglio va nel journal.
fn fallito(e: zbus::Error) -> fdo::Error {
    eprintln!("octod: errore verso systemd: {e}");
    fdo::Error::Failed("errore interno di octod (dettagli nel journal)".into())
}

async fn run() -> zbus::Result<()> {
    let _conn = zbus::connection::Builder::system()
        .name(BUS_NAME)
        .serve_at(OBJECT_PATH, Manager)
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
