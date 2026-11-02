//! aracno — i comandi di Aracno Linux per chi usa il sistema.
//! Parla solo con aracnod sul bus di sistema: nessun permesso speciale qui,
//! i controlli li fa aracnod con polkit.

mod ragnatela;

use futures_core::Stream;
use ragnatela::{attivi, da_righe, disegna, messaggio_errore, stato_it};
use std::io::IsTerminal;
use std::pin::Pin;
use std::process::ExitCode;
use zbus::{proxy, Connection};

const AIUTO: &str = "\
aracno — i fili di Aracno Linux

  aracno [ragnatela]     disegna la ragnatela: ogni filo con stato e RAM
  aracno salta FILO      passa a FILO: congela gli altri, attiva lui
  aracno taglia FILO     spegne FILO (chiede la password di amministratore)
  aracno dove            nome del filo attivo (utile nel prompt della shell)
  aracno ascolta         segue la ragnatela in diretta (Ctrl+C per uscire)
  aracno aiuto           questo messaggio
";

#[proxy(
    interface = "io.github.tommaso_palestini.Aracno1.Manager",
    default_service = "io.github.tommaso_palestini.Aracno1",
    default_path = "/io/github/tommaso_palestini/Aracno1"
)]
trait Manager {
    fn list_strands(&self) -> zbus::Result<Vec<(String, String, u64, u64)>>;
    fn switch(&self, name: &str) -> zbus::Result<u32>;
    #[zbus(allow_interactive_auth)]
    fn stop(&self, name: &str) -> zbus::Result<u32>;
    #[zbus(signal)]
    fn state_changed(&self, name: String, state: String) -> zbus::Result<()>;
}

/// Errore già pronto da mostrare all'utente.
struct Errore(String);

impl From<zbus::Error> for Errore {
    fn from(e: zbus::Error) -> Self {
        use zbus::DBusError;
        match &e {
            zbus::Error::MethodError(nome, _, _) => Errore(messaggio_errore(nome.as_str()).into()),
            // errori standard di D-Bus (servizio assente, metodo sconosciuto, …)
            zbus::Error::FDO(f) => Errore(messaggio_errore(f.name().as_str()).into()),
            _ => Errore(format!("bus di sistema non raggiungibile: {e}")),
        }
    }
}

fn colori() -> bool {
    std::io::stdout().is_terminal() && std::env::var_os("NO_COLOR").is_none()
}

async fn fili(m: &ManagerProxy<'_>) -> Result<Vec<ragnatela::Filo>, Errore> {
    da_righe(m.list_strands().await?).map_err(Errore)
}

async fn esegui(args: &[String]) -> Result<(), Errore> {
    let comando = args.first().map(String::as_str).unwrap_or("ragnatela");
    let filo = |verbo: &str| -> Result<&str, Errore> {
        match args {
            [_, f] => Ok(f.as_str()),
            _ => Err(Errore(format!("uso: aracno {verbo} FILO"))),
        }
    };
    if matches!(comando, "aiuto" | "-h" | "--help") {
        print!("{AIUTO}");
        return Ok(());
    }
    let conn = Connection::system().await?;
    let m = ManagerProxy::new(&conn).await?;
    match comando {
        "ragnatela" => print!("{}", disegna(&fili(&m).await?, colori())),
        "salta" => {
            let f = filo("salta")?;
            let ms = m.switch(f).await?;
            println!("● sei su {f} ({ms} ms)");
        }
        "taglia" => {
            let f = filo("taglia")?;
            let ms = m.stop(f).await?;
            println!("· {f} spento ({ms} ms)");
        }
        "dove" => {
            let fili = fili(&m).await?;
            match attivi(&fili).as_slice() {
                [] => return Err(Errore("nessun filo attivo".into())),
                nomi => println!("{}", nomi.join(" ")),
            }
        }
        "ascolta" => {
            print!("{}", disegna(&fili(&m).await?, colori()));
            println!("in ascolto… (Ctrl+C per uscire)");
            let mut eventi = m.receive_state_changed().await?;
            while let Some(e) = prossimo(&mut eventi).await {
                let a = e.args()?;
                let stato = a.state.parse().map(stato_it).unwrap_or("?");
                println!("  {} → {stato}", a.name);
            }
        }
        altro => {
            return Err(Errore(format!(
                "comando sconosciuto: {altro:?}. Prova: aracno aiuto"
            )))
        }
    }
    Ok(())
}

/// Prossimo elemento di uno stream, senza dipendere da futures-util.
async fn prossimo<S: Stream + Unpin>(s: &mut S) -> Option<S::Item> {
    std::future::poll_fn(|cx| Pin::new(&mut *s).poll_next(cx)).await
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match zbus::block_on(esegui(&args)) {
        Ok(()) => ExitCode::SUCCESS,
        Err(Errore(msg)) => {
            eprintln!("aracno: {msg}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn proxy_coerente_con_proto() {
        let s = include_str!("main.rs");
        assert!(s.contains(&format!("interface = \"{}\"", aracno_proto::INTERFACE)));
        assert!(s.contains(&format!("default_service = \"{}\"", aracno_proto::BUS_NAME)));
        assert!(s.contains(&format!("default_path = \"{}\"", aracno_proto::OBJECT_PATH)));
    }
}
