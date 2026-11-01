# Task: menù a tentacoli

Piano: `tasks/plan.md`. Ogni task si chiude con la sua verifica sul PC reale (principio 2 di CLAUDE.md). Gli script con `sudo` li lancia l'utente, con il percorso assoluto.

## Fase 1: prove dei rischi

- [ ] **T1: prova di utente `octopus` + regola polkit** (S)
  - Lavoro: `octopus/data/sysusers/octopus.conf`, `octopus/data/polkit/50-octopus.rules`, `prototype/10-polkit-spike.sh` (installa, prova, rimuove).
  - Accettazione:
    - come `octopus`, `busctl call … FreezeUnit/ThawUnit systemd-nspawn@arch.service` funziona senza password;
    - come `octopus`, `RestartUnit` sullo stesso tentacolo e `StopUnit` su un'altra unit (per esempio `cron.service`) vengono **rifiutati**;
    - come `octopus`, `machine1 ListImages` restituisce debian e arch.
  - Verifica: `sudo /home/xenon/Desktop/progetti-personal/idea-linux/prototype/10-polkit-spike.sh` → PASS.
  - Dipendenze: nessuna.

- [ ] **T2: prova di layer-shell su COSMIC** (S)
  - Prerequisito (lo lancia l'utente): `sudo apt install libgtk-4-dev meson ninja-build libwayland-dev wayland-protocols`. Poi gtk4-layer-shell 1.0.4 compilata in `~/.local`, senza introspection e senza vala.
  - Lavoro: `octopus/spikes/layer-shell/` (una finestra minima in Rust).
  - Accettazione:
    - la finestra copre tutto lo schermo sopra le altre, riceve la tastiera e si chiude con Esc;
    - con `GDK_BACKEND=x11`, o senza layer-shell, parte il ripiego a schermo intero.
  - Verifica: `cargo run` nella cartella della prova, controllo a occhio con screenshot.
  - Dipendenze: nessuna.

### Checkpoint A
- [ ] T1 e T2 passati, oppure piano rivisto con te se un'ipotesi è caduta.

## Fase 2: `octod`

- [ ] **T3: ADR-0008** (XS): demone di sistema + D-Bus + polkit, utente dedicato, Rust. Con i risultati di T1 e T2.
- [ ] **T4: workspace e `octopus-proto`** (S)
  - Lavoro: `octopus/Cargo.toml`, `octopus/octopus-proto/` con i nomi D-Bus, `TentacleName`, `TentacleState` e gli errori.
  - Accettazione: test unitari della validazione dei nomi (validi, vuoto, maiuscole, `../`, spazi, 64 caratteri).
  - Verifica: `cargo test -p octopus-proto`, `cargo clippy -- -D warnings`.
- [ ] **T5: `octod` con `ListTentacles`** (M)
  - Lavoro: `octopus/octod/`; i file `data/dbus/`, `data/systemd/octod.service`; `prototype/11-install-octod.sh`.
  - Accettazione: O1. `ListTentacles` restituisce nome, stato, RAM e limite giusti con debian attiva e arch congelata, confrontati con `octo list`.
  - Verifica: `cargo test`; installazione; `busctl call io.github.tommaso_palestini.Octopus1 … ListTentacles`.
  - Dipendenze: T1, T4.
- [ ] **T6: `Switch`** (M)
  - Accettazione:
    - O2: switch dalla sessione senza password, mediana su 20 switch < 150 ms;
    - O3: `nobody` rifiutato;
    - O4: nomi non validi rifiutati;
    - O5: due switch in contemporanea: uno riesce, l'altro riceve `Busy`.
  - Il segnale `StateChanged` viene emesso. Ogni operazione va nel log con chi l'ha chiesta.
  - Verifica: `prototype/12-octod-test.sh` → PASS.
  - Dipendenze: T5.
- [ ] **T7: `Stop` + restrizioni della unit + controlli di sicurezza** (S)
  - Accettazione:
    - `Stop` chiede la password di amministratore;
    - O6: `systemd-analyze security octod.service` ≤ 2.0;
    - `cargo audit` e `cargo deny check` puliti.
  - Verifica: la parte Stop/O6 di `12-octod-test.sh`.
  - Revisione con la skill `security-and-hardening`.
  - Dipendenze: T6.

### Checkpoint B
- [ ] O1–O6 PASS, test e clippy verdi, revisione con te.

## Fase 3: `octo-menu`

- [ ] **T8: menù base** (M)
  - Lavoro: istanza unica (lanciato di nuovo si chiude), layer-shell o ripiego, elenco testuale da `ListTentacles`, Esc.
  - Accettazione: M4, cioè un messaggio chiaro se `octod` non risponde o rifiuta.
  - Dipendenze: T2, T5.
- [ ] **T9: raggiera, tastiera e switch** (M)
  - Lavoro: `radial.rs` (logica pura, test per 1–8 tentacoli su 1366×768), navigazione con frecce, Tab e Invio, `Switch` tramite `octod`, chiusura a switch fatto.
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
