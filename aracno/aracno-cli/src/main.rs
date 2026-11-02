//! aracno — i comandi di Aracno Linux per chi usa il sistema.
//! Parla solo con aracnod sul bus di sistema: nessun permesso speciale qui,
//! i controlli li fa aracnod con polkit.

mod ragnatela;

use aracno_proto::client::{self, messaggio, stato_it, ManagerProxy};
use futures_core::Stream;
use ragnatela::{attivi, disegna};
use std::io::IsTerminal;
use std::pin::Pin;
use std::process::ExitCode;
use zbus::Connection;

const AIUTO: &str = "\
aracno — i fili di Aracno Linux

  aracno [web]           disegna la ragnatela: ogni filo con stato e RAM
  aracno hop FILO        passa a FILO: congela gli altri, attiva lui
  aracno snip FILO       spegne FILO (chiede la password di amministratore)
  aracno where           nome del filo attivo (utile nel prompt della shell)
  aracno watch           segue la ragnatela in diretta (Ctrl+C per uscire)
  aracno help            questo messaggio
";

/// Errore già pronto da mostrare all'utente.
struct Errore(String);

impl From<zbus::Error> for Errore {
    fn from(e: zbus::Error) -> Self {
        Errore(messaggio(&e))
    }
}

fn colori() -> bool {
    std::io::stdout().is_terminal() && std::env::var_os("NO_COLOR").is_none()
}

async fn fili(m: &ManagerProxy<'_>) -> Result<Vec<client::Filo>, Errore> {
    client::fili(m).await.map_err(Errore)
}

async fn esegui(args: &[String]) -> Result<(), Errore> {
    let comando = args.first().map(String::as_str).unwrap_or("web");
    let filo = |verbo: &str| -> Result<&str, Errore> {
        match args {
            [_, f] => Ok(f.as_str()),
            _ => Err(Errore(format!("uso: aracno {verbo} FILO"))),
        }
    };
    if matches!(comando, "help" | "-h" | "--help") {
        print!("{AIUTO}");
        return Ok(());
    }
    let conn = Connection::system().await?;
    let m = ManagerProxy::new(&conn).await?;
    match comando {
        "web" => print!("{}", disegna(&fili(&m).await?, colori())),
        "hop" => {
            let f = filo("hop")?;
            let ms = m.switch(f).await?;
            println!("● sei su {f} ({ms} ms)");
        }
        "snip" => {
            let f = filo("snip")?;
            let ms = m.stop(f).await?;
            println!("· {f} spento ({ms} ms)");
        }
        "where" => {
            let fili = fili(&m).await?;
            match attivi(&fili).as_slice() {
                [] => return Err(Errore("nessun filo attivo".into())),
                nomi => println!("{}", nomi.join(" ")),
            }
        }
        "watch" => {
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
                "comando sconosciuto: {altro:?}. Prova: aracno help"
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
