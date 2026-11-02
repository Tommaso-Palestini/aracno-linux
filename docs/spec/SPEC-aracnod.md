# Spec: `aracnod` (con `aracno-proto`)

Stato: **approvata** il 2026-11-01.

## Obiettivo
Un servizio di sistema che fa le operazioni privilegiate sui fili per conto di programmi senza privilegi: il menù (`aracno-menu`) e in futuro la CLI.
Utente: chi è seduto davanti al PC, nella sessione grafica attiva.
Successo: dalla sessione grafica l'utente fa lo switch senza password e senza `sudo`. Nessun altro processo può usare `aracnod` per fare altro che le operazioni previste.

User story:
- Come utente della sessione attiva, voglio vedere i fili con il loro stato e passare a uno di loro, senza password.
- Come utente, voglio spegnere un filo, confermando con la password di amministratore.
- Come amministratore che installa Aracno su un'altra distro, voglio che funzioni con systemd, D-Bus e polkit standard, senza dipendenze legate a una distro.

## Assunzioni
1. L'host ha systemd con cgroup v2 e freezer: systemd ≥ 252, quello di Debian bookworm. Trixie, Arch, Fedora e Ubuntu ≥ 23.04 lo soddisfano.
2. I fili sono macchine nspawn in `/var/lib/machines/NOME`, avviate come `systemd-nspawn@NOME.service` (ADR-0001).
3. polkit è presente: lo è su tutte le distro desktop principali.
4. Fuori dalla v1: `limit`, `upgrade`, creazione di fili. Si aggiungono dopo, con la stessa interfaccia.

## Interfaccia D-Bus (`aracno-proto`)
- Bus: **di sistema**. Nome: `io.github.tommaso_palestini.Aracno1`. Il nome è in DNS inverso del repo GitHub, come vuole la convenzione di D-Bus e Flatpak.
- Oggetto: `/io/github/tommaso_palestini/Aracno1`. Interfaccia: `io.github.tommaso_palestini.Aracno1.Manager`.

| Membro | Firma | Permesso polkit | Note |
|---|---|---|---|
| `ListStrands()` | → `a(sstt)` nome, stato, RAM byte, limite byte (0 = nessuno) | nessuno, sola lettura | stato ∈ `active`, `frozen`, `off` |
| `Switch(s nome)` | → `u` millisecondi | `…Aracno1.switch` | congela gli altri attivi, scongela o avvia `nome` |
| `Stop(s nome)` | → nulla | `…Aracno1.manage` | scongela se serve, poi spegne |
| `StateChanged` (segnale) | `s nome, s stato` | — | per aggiornare il menù senza interrogare di continuo |

Errori D-Bus con nome: `…Aracno1.Error.NotFound`, `.InvalidName`, `.NotAuthorized`, `.Busy`, `.Failed`.

Regole sui nomi dei fili, validate **nel demone** prima di tutto il resto: `^[a-z0-9][a-z0-9-]{0,62}$`, e deve esistere come immagine di systemd-machined (`org.freedesktop.machine1.Manager.ListImages`). `aracnod` non legge `/var/lib/machines`, che ha permessi 0700 root. I nomi non passano mai per una shell.

## Sicurezza (`security-and-hardening`)
- **Azioni polkit** in `io.github.tommaso_palestini.Aracno1.policy`:
  - `switch`: `allow_active=yes`, `allow_inactive=no`, `allow_any=no`. Solo chi è seduto nella sessione attiva, senza password.
  - `manage`: `allow_active=auth_admin_keep`, gli altri `no`.
  - Nota (T6, 2026-11-01): `allow_active` guarda la **sessione del processo**, non il suo utente. Un processo di un altro utente lanciato da root dentro la sessione attiva (per esempio `sudo runuser -u nobody` dal terminale) viene autorizzato. Non è un'escalation, perché per farlo bisogna già essere root, ed è il comportamento standard di polkit (lo stesso di NetworkManager e degli altri servizi desktop). I processi fuori da ogni sessione, come i servizi di sistema, vengono rifiutati.
- **Nessuna shell, nessun `Command`**: `aracnod` parla con systemd su D-Bus (`FreezeUnit`, `ThawUnit`, `StartUnit`, `StopUnit`) e legge lo stato dai cgroup in sola lettura. I comandi di sistema non vengono composti come stringhe.
- **Un solo switch alla volta**: un lock interno; una seconda richiesta durante uno switch riceve `Busy`.
- **Policy D-Bus** (`/usr/share/dbus-1/system.d/…conf`): solo l'utente `aracno` può possedere il nome. Chiunque può chiamare i metodi, e il controllo vero lo fa polkit dentro il demone.
- **Unit systemd con restrizioni**: `Type=dbus`, attivazione via D-Bus, così il demone non gira se non serve. `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, `PrivateNetwork=yes`, `RestrictAddressFamilies=AF_UNIX`, `CapabilityBoundingSet=` vuoto, `SystemCallFilter=@system-service`, `MemoryDenyWriteExecute=yes`.
  - Gira come **utente di sistema dedicato `aracno`** (creato da `sysusers.d`), non come root, e senza capability.
  - Una **regola polkit** (`/usr/share/polkit-1/rules.d/50-aracno.rules`) permette solo a `aracno` l'azione `org.freedesktop.systemd1.manage-units`, solo per unit che corrispondono a `^systemd-nspawn@[a-z0-9][a-z0-9-]{0,62}\.service$` e solo con i verbi `start` e `stop`. Qualsiasi altra richiesta va alla decisione predefinita di polkit, cioè il rifiuto per un utente di sistema.
  - Verificato sul sorgente di systemd v255 (`src/core/dbus-unit.c`, `dbus-util.c`, `bus-convenience.c`): `FreezeUnit` passa a polkit i dettagli `unit` e `verb=stop`, `ThawUnit` passa `verb=start`. `StartUnit` e `StopUnit` usano `start` e `stop`. Se manca `CAP_SYS_ADMIN`, anche root passa da polkit: per questo "root senza capability" non funzionerebbe.
  - **Policy D-Bus per freeze e thaw** (`aracno-systemd-freezer.conf`): su systemd 255 la policy del bus di systemd non permette `FreezeUnit` e `ThawUnit` a chi non è root, e la chiamata viene rifiutata prima di arrivare a polkit (verificato in T1 il 2026-11-01). Il file apre questi due metodi **solo** all'utente `aracno`, mentre la decisione resta a polkit. Nelle versioni recenti di systemd questi metodi sono già nella policy predefinita, quindi il file non serve più ma non fa danni.
  - Se un giorno serve `aracno limit` (`SetUnitProperties`), il verbo è diverso: va aggiunto in modo esplicito alla regola, con una nuova decisione.
- **Log**: ogni operazione va nel journal con chi l'ha chiesta (UID e PID del chiamante), filo, esito e durata. Nessun dato della sessione.
- **Dipendenze Rust** ridotte e controllate: `Cargo.lock` nel repo, `cargo audit` e `cargo deny` prima di ogni rilascio.

## Tech stack
- Rust (edizione 2021, toolchain stable) in un workspace Cargo.
- `zbus` per D-Bus, server e client, senza binding C. `zbus_polkit` per i controlli polkit. `tokio` come runtime async.
- Versioni esatte da fissare nella fase Plan, verificate sulla documentazione aggiornata.
- Perché Rust: è un demone che resta acceso e ha privilegi. La sicurezza della memoria e un binario unico contano. È il caso previsto dalle note della roadmap.

## Comandi
```
Build:   cargo build --release --workspace
Test:    cargo test --workspace
Lint:    cargo clippy --workspace --all-targets -- -D warnings && cargo fmt --check
Audit:   cargo audit && cargo deny check
Prova:   sudo /home/xenon/Desktop/progetti-personal/idea-linux/prototype/10-aracnod-test.sh
```

## Struttura
```
aracno/                    workspace Cargo (nuovo, accanto a prototype/)
  Cargo.toml
  aracno-proto/            nomi D-Bus, tipi, validazione dei nomi (libreria)
  aracnod/                    il demone
  aracno-menu/                il menù (vedi SPEC-aracno-menu.md)
  data/
    dbus/                   policy del bus di sistema + file di attivazione
    polkit/                 file .policy con le due azioni
    systemd/                aracnod.service con le restrizioni
prototype/10-aracnod-test.sh  prova sul PC reale
```

## Stile del codice
```rust
/// Un nome di filo già validato: l'unico tipo accettato dalle operazioni.
pub struct StrandName(String);

impl TryFrom<&str> for StrandName {
    type Error = ProtoError;
    fn try_from(s: &str) -> Result<Self, Self::Error> {
        let ok = !s.is_empty() && s.len() <= 63
            && s.bytes().next().is_some_and(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
            && s.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-');
        if ok { Ok(Self(s.to_owned())) } else { Err(ProtoError::InvalidName) }
    }
}
```
Convenzioni: tipi che rendono impossibili gli stati sbagliati (un nome non validato non arriva alle operazioni), errori con `thiserror`, nessun `unwrap()` fuori dai test, commenti in italiano solo per spiegare il perché.

## Strategia di test
- **Unitari** (`cargo test`): validazione dei nomi (casi validi, vuoto, maiuscole, `../`, spazi, 64 caratteri), lettura dello stato dai file cgroup (con cartelle finte), logica dello switch con un systemd finto (trait).
- **Sul PC** (`prototype/10-aracnod-test.sh`, criteri scritti nello script prima di lanciarlo):
  - O1: `busctl call … ListStrands` restituisce debian e arch con lo stato giusto.
  - O2: `Switch` dalla sessione attiva funziona senza password. Mediana su 20 switch < 150 ms, contro i 69 ms della fase 3, più il costo del D-Bus.
  - O3: `Switch` lanciato come `nobody`, da fuori della sessione, riceve `NotAuthorized` e lo stato non cambia.
  - O4: nomi non validi (`../etc`, `Debian`, `a b`, stringa vuota) ricevono `InvalidName`, e nessuna unit viene toccata.
  - O5: due `Switch` in contemporanea: uno riesce, l'altro riceve `Busy`, e alla fine c'è esattamente un filo attivo.
  - O6: `systemd-analyze security aracnod.service` dà un punteggio ≤ 2.0 (OK).

## Confini
- **Sempre**: validare i nomi nel demone; controllare polkit prima di ogni azione che cambia stato; registrare chi ha chiesto cosa; test unitari verdi prima di ogni commit.
- **Chiedere prima**: aggiungere metodi D-Bus o azioni polkit; aggiungere dipendenze Rust oltre a quelle elencate; cambiare `allow_active` dello switch.
- **Mai**: eseguire una shell o comporre comandi con i nomi; aprire una porta di rete; dare a `aracnod` capability che non servono; chiamare `sudo` dal codice.

## Criteri di successo
1. O1–O6 passano sul PC di riferimento.
2. Il menù e la CLI possono fare lo switch senza sudo, e solo dalla sessione attiva.
3. L'installazione richiede solo file in posizioni standard (`/usr/lib/systemd/system`, `/usr/share/dbus-1`, `/usr/share/polkit-1/actions`) e funziona senza modifiche su Debian trixie e su Arch. La prova su Arch verrà con l'ISO o in VM.

## Domande aperte
- ~~Password per lo switch?~~ Deciso il 2026-11-01: **nessuna password** dalla sessione attiva (`allow_active=yes`).
- ~~Utente dedicato o root?~~ Deciso il 2026-11-01: utente dedicato `aracno` + regola polkit (vedi Sicurezza).
