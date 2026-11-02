# Task: menù a ragnatela

Piano: `tasks/plan.md`. Ogni task si chiude con la sua verifica sul PC reale (principio 2 di CLAUDE.md). Gli script con `sudo` li lancia l'utente, con il percorso assoluto.

## Fase 1: prove dei rischi

- [x] **T1: prova di utente `aracno` + regola polkit** (S): PASS il 2026-11-01. Serve anche una policy D-Bus per FreezeUnit/ThawUnit su systemd 255
  - Lavoro: `aracno/data/sysusers/aracno.conf`, `aracno/data/polkit/50-aracno.rules`, `prototype/10-polkit-spike.sh` (installa, prova, rimuove).
  - Accettazione:
    - come `aracno`, `busctl call … FreezeUnit/ThawUnit systemd-nspawn@arch.service` funziona senza password;
    - come `aracno`, `RestartUnit` sullo stesso filo e `StopUnit` su un'altra unit (per esempio `cron.service`) vengono **rifiutati**;
    - come `aracno`, `machine1 ListImages` restituisce debian e arch.
  - Verifica: `sudo /home/xenon/Desktop/progetti-personal/idea-linux/prototype/10-polkit-spike.sh` → PASS.
  - Dipendenze: nessuna.

- [x] **T2: prova di layer-shell su COSMIC** (S): PASS il 2026-11-01. Layer-shell overlay a tutto schermo (pannelli compresi), tastiera esclusiva, Esc chiude; ripiego X11 ok; avvio a freddo 129–207 ms
  - Prerequisito (lo lancia l'utente): `sudo apt install libgtk-4-dev meson ninja-build libwayland-dev wayland-protocols`. Poi gtk4-layer-shell 1.0.4 compilata in `~/.local`, senza introspection e senza vala.
  - Lavoro: `aracno/spikes/layer-shell/` (una finestra minima in Rust).
  - Accettazione:
    - la finestra copre tutto lo schermo sopra le altre, riceve la tastiera e si chiude con Esc;
    - con `GDK_BACKEND=x11`, o senza layer-shell, parte il ripiego a schermo intero.
  - Verifica: `cargo run` nella cartella della prova, controllo a occhio con screenshot.
  - Dipendenze: nessuna.

### Checkpoint A
- [x] T1 e T2 passati (2026-11-01). Ipotesi corretta in T1: serve una policy D-Bus per FreezeUnit/ThawUnit.

## Fase 2: `aracnod`

- [x] **T3: ADR-0008** (XS): demone di sistema + D-Bus + polkit, utente dedicato, Rust. Con i risultati di T1 e T2.
- [x] **T4: workspace e `aracno-proto`** (S): 7 test verdi (nomi, stati, coerenza con la regola polkit), clippy e fmt puliti
  - Lavoro: `aracno/Cargo.toml`, `aracno/aracno-proto/` con i nomi D-Bus, `StrandName`, `StrandState` e gli errori.
  - Accettazione: test unitari della validazione dei nomi (validi, vuoto, maiuscole, `../`, spazi, 64 caratteri).
  - Verifica: `cargo test -p aracno-proto`, `cargo clippy -- -D warnings`.
- [x] **T5: `aracnod` con `ListStrands`** (M): PASS il 2026-11-01 (O1a–O1d). Senza tokio: zbus 6 ha il suo runtime; RAM e limite dalle proprietà di systemd, nessun file letto
  - Lavoro: `aracno/aracnod/`; i file `data/dbus/`, `data/systemd/aracnod.service`; `prototype/11-install-aracnod.sh`.
  - Accettazione: O1. `ListStrands` restituisce nome, stato, RAM e limite giusti con debian attiva e arch congelata, confrontati con `aracno list`.
  - Verifica: `cargo test`; installazione; `busctl call io.github.tommaso_palestini.Aracno1 … ListStrands`.
  - Dipendenze: T1, T4.
- [x] **T6: `Switch`** (M): PASS il 2026-11-01. Mediana 13 ms, nobody fuori dalla sessione rifiutato, 12 Busy su 60 chiamate in contemporanea, stato sempre coerente. Le azioni polkit hanno come proprietario `unix-user:aracno`
  - Accettazione:
    - O2: switch dalla sessione senza password, mediana su 20 switch < 150 ms;
    - O3: `nobody` rifiutato;
    - O4: nomi non validi rifiutati;
    - O5: due switch in contemporanea: uno riesce, l'altro riceve `Busy`.
  - Il segnale `StateChanged` viene emesso. Ogni operazione va nel log con chi l'ha chiesta.
  - Verifica: `prototype/12-aracnod-test.sh` → PASS.
  - Dipendenze: T5.
- [x] **T7: `Stop` + restrizioni della unit + controlli di sicurezza** (S)
  - Accettazione:
    - `Stop` chiede la password di amministratore;
    - O6: `systemd-analyze security aracnod.service` ≤ 2.0;
    - `cargo audit` e `cargo deny check` puliti.
  - Verifica: la parte Stop/O6 di `12-aracnod-test.sh`.
  - Revisione con la skill `security-and-hardening`.
  - Dipendenze: T6.
  - PASS il 2026-11-02: `13-aracnod-stop-test.sh` (Stop con password, esposizione 0.2), `cargo audit` e `cargo deny check` puliti, revisione in `docs/security/2026-11-02-revisione-aracnod.md`.

- [x] **T7b: comando `aracno` per l'utente** (S) — chiesto il 2026-11-02
  - Lavoro: crate `aracno-cli` (binario `aracno`, client di `aracnod`, nessun permesso proprio):
    `web`, `hop FILO`, `snip FILO`, `where`, `watch`, `help` (nomi dei comandi in inglese, chiesto il 2026-11-02; i messaggi restano in italiano fino alle traduzioni di T11). Installato in `/usr/local/bin` da `11-install-aracnod.sh`.
  - Accettazione: C1–C5 di `prototype/14-aracno-cli-test.sh`. PASS il 2026-11-02 (con i nomi italiani; da rilanciare con quelli inglesi).
  - Idee per dopo (servono metodi nuovi in `aracnod`, con polkit `manage`):
    `aracno weave NOME DISTRO` (crea un filo dalle immagini dell'ISO, fase 5b),
    `aracno rest FILO SIZE` (tetto di RAM a un filo congelato, oggi `aracno limit` del prototipo),
    `aracno mend [FILO]` (aggiorna i pacchetti, oggi `aracno upgrade` del prototipo).
  - Dipendenze: T7.

### Checkpoint B
- [x] O1–O6 PASS, test e clippy verdi, revisione con te (approvato il 2026-11-02).

## Fase 3: `aracno-menu`

- [ ] **T8: menù base** (M)
  - Lavoro: istanza unica (lanciato di nuovo si chiude), layer-shell o ripiego, elenco testuale da `ListStrands`, Esc.
  - Accettazione: M4, cioè un messaggio chiaro se `aracnod` non risponde o rifiuta.
  - Da T2: l'avvio a freddo (129–207 ms) è al limite di M1. Tenere il processo già avviato e mostrare o nascondere la finestra; misurare.
  - Da T2: controllare che il display sia Wayland prima di `is_supported()`, altrimenti la libreria 1.0.4 dà un CRITICAL su X11.
  - Dipendenze: T2, T5.
- [ ] **T9: raggiera, tastiera e switch** (M)
  - Lavoro: `radial.rs` (logica pura, test per 1–8 fili su 1366×768), navigazione con frecce, Tab e Invio, `Switch` tramite `aracnod`, chiusura a switch fatto.
  - Accettazione: M2, M3.
  - Dipendenze: T6, T8.
- [ ] **T10: grafica** (M)
  - Lavoro: CSS, icone, stati come testo e icona, animazione di apertura. Skill `frontend-ui-engineering` e `design-taste-frontend`; screenshot.
  - Accettazione: M1 (< 200 ms dal tasto alla schermata).
  - Dipendenze: T9.
- [ ] **T11: aggiornamenti live, traduzioni e tasto rapido** (S)
  - Lavoro: `StateChanged`, gettext (`po/`), file `.desktop`, `Super+O` su COSMIC.
  - Accettazione: M5 su COSMIC; il ripiego si prova in VM più avanti.
  - Dipendenze: T10.

### Checkpoint C
- [ ] M1–M5 PASS, criteri di successo delle due spec verificati, revisione con te.
