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

- [x] **T8: menù base** (M)
  - PASS il 2026-11-02 (`16-menu-base-test.sh`: layer-shell, 144–168 ms dal tasto alla finestra, uscita pulita, M4 ok): crate `aracno-menu` (ogni apertura è un processo nuovo; chiudere = uscire, perché su COSMIC nascondere o chiudere una superficie layer-shell fa cadere la connessione; dal tasto alla finestra 135–172 ms, margine stretto per M1 quando arriva la grafica di T10), client D-Bus condiviso spostato in `aracno_proto::client`. Test: `prototype/16-menu-base-test.sh` (guidato). Il menù non è nei `default-members` del workspace: serve `PKG_CONFIG_PATH=$HOME/.local/lib/x86_64-linux-gnu/pkgconfig` e `-p aracno-menu`.
  - Lavoro: istanza unica (lanciato di nuovo si chiude), layer-shell o ripiego, elenco testuale da `ListStrands`, Esc.
  - Accettazione: M4, cioè un messaggio chiaro se `aracnod` non risponde o rifiuta.
  - Da T2: l'avvio a freddo (129–207 ms) è al limite di M1. Tenere il processo già avviato e mostrare o nascondere la finestra; misurare.
  - Da T2: controllare che il display sia Wayland prima di `is_supported()`, altrimenti la libreria 1.0.4 dà un CRITICAL su X11.
  - Dipendenze: T2, T5.
- [x] **T9: raggiera, tastiera e switch** (M)
  - PASS il 2026-11-02 (`17-menu-switch-test.sh`: frecce, Tab, Invio, clic, Invio sul filo attivo; switch 9–21 ms). Corretto al primo giro: le frecce non accendevano l'evidenziazione del focus. `radial.rs` (ellisse, primo filo in alto, senso orario; frecce = nodo più vicino in quella direzione), pulsanti accessibili, Switch e chiusura a switch fatto. Test: `prototype/17-menu-switch-test.sh` (guidato).
  - Lavoro: `radial.rs` (logica pura, test per 1–8 fili su 1366×768), navigazione con frecce, Tab e Invio, `Switch` tramite `aracnod`, chiusura a switch fatto.
  - Accettazione: M2, M3.
  - Dipendenze: T6, T8.
- [x] **T10: grafica** (M)
  - PASS il 2026-11-02 (`18-menu-grafica-test.sh`: M1 73–83 ms, 18–19 fotogrammi in 300 ms, G1–G4 ok): `data/style.css` (fondo notte piatto, un solo accento "rugiada" sul filo attivo e sulla selezione, nodi tondi pieni, niente ombre/gradienti/sfocature), ragnatela disegnata con cairo (raggi e anelli sottili, zona libera intorno al centro, filo attivo colorato), centro "aracno · sei su NOME", apertura: ragnatela ferma, nodi che arrivano lungo il loro filo (300 ms, salta se le animazioni di sistema sono spente). Primo giro del test 18: G1 FAIL (apertura a scatti, 9 fotogrammi in 266 ms); corretto con motore cairo (impostato dal menù), fondo opaco e solo i nodi animati: 14–18 fotogrammi in 300 ms, M1 72–109 ms. Screenshot: `docs/img/aracno-menu-t10.png`. Anteprima per screenshot: `ARACNO_MENU_ANTEPRIMA=1`. Test: `prototype/18-menu-grafica-test.sh`.
  - Lavoro: CSS, icone, stati come testo e icona, animazione di apertura. Skill `frontend-ui-engineering` e `design-taste-frontend`; screenshot.
  - Accettazione: M1 (< 200 ms dal tasto alla schermata).
  - Dipendenze: T9.
- [x] **T11: aggiornamenti live, traduzioni e tasto rapido** (S)
  - PASS il 2026-11-02 (`21-menu-t11-test.sh`: aggiornamenti in diretta, menù in inglese con LANG=en_US, voce "Aracno" tra le applicazioni, Super+Shift+A apre e chiude): aggiornamenti in diretta da StateChanged (nodi aggiornati al loro posto), gettext (dominio "aracno", testi originali in italiano, `po/en.po`; estrazione con `po/estrai.py` perché xgettext 0.21 non conosce il Rust), voce `.desktop`, tasto **Super+Shift+A** (Super+A su COSMIC è la libreria applicazioni) con `prototype/20-tasto-rapido.sh`. gettext-rs 0.8 (la 0.7 ha RUSTSEC-2026-0244); niente setlocale nostro, lo fa GTK. Test: `prototype/21-menu-t11-test.sh`.
  - Lavoro: `StateChanged`, gettext (`po/`), file `.desktop`, `Super+Shift+A` su COSMIC (Super+A è la libreria applicazioni).
  - Accettazione: M5 su COSMIC; il ripiego si prova in VM più avanti.
  - Dipendenze: T10.

### Checkpoint C
- [ ] M1–M5 PASS, criteri di successo delle due spec verificati, revisione con te.

## Prima della fase 5 (chiesto il 2026-11-02)

- [x] **T12: copia di sicurezza prima di `aracno upgrade`** (S)
  - Ipotesi: su ext4 non ci sono snapshot, ma una copia completa in `/var/lib/aracno/copie/`
    (stesso filesystem di `/var/lib/machines`, fuori dalla vista di machined) costa pochi
    secondi per filo e il ripristino è uno scambio di cartelle, istantaneo. Con btrfs
    (ISO) `cp --reflink=auto` diventa gratis senza cambiare codice.
  - Lavoro: `aracno upgrade` copia il filo prima di aggiornarlo (spento o congelato:
    copia coerente come dopo uno spegnimento brusco); una copia per filo, la più recente;
    rifiuta se lo spazio libero è meno di 1,2 volte il filo; `aracno ripristina NOME`.
  - Accettazione: `prototype/22-upgrade-copia-test.sh` (U1–U4) con tempi misurati.
  - PASS il 2026-11-02 (`22-upgrade-copia-test.sh`: copia di 1,3 GB in 8,8–9,2 s, filo attivo congelato per quel tempo; ripristino ok). `aracno upgrade` copia prima di aggiornare (`--senza-copia` per saltare), `aracno ripristina`, `aracno copie`.
- [x] **T13: politica della RAM per i fili congelati** (S)
  - PASS il 2026-11-02 al terzo giro (`23-ram-pressione-test.sh`, lavoro che tocca la memoria: 100% dal congelato, rilettura 379 ms). Decisione: ADR-0011, nessun tetto automatico.
  - Domanda: serve un tetto automatico allo switch, o il kernel sacrifica già da solo i
    fili congelati quando la memoria scarseggia? Dato di partenza: fase 4.5 (con zram si
    guadagna circa metà di quanto si toglie).
  - Ipotesi: le pagine di un filo congelato sono fredde, quindi sotto pressione il kernel
    le libera per prime; il filo attivo perde poco.
  - Misura: `prototype/23-ram-pressione-test.sh` (P1–P3). Poi la decisione in un ADR.
  - Test scritto il 2026-11-02, da lanciare.
- [x] **T14: revisione del socket Wayland (ADR-0005)** (M)
  - PASS il 2026-11-02 (`24-wayland-sicuro-test.sh`: arch e debian 36 protocolli, nessun privilegiato, vkcube ok). Decisione: ADR-0010.
  - Domanda: quali protocolli vede un programma dentro un filo? Appunti, cattura dello
    schermo, tastiera virtuale, layer-shell (una finestra a tutto schermo che imita il
    login), gestione delle finestre?
  - Misura: `aracno/spikes/wayland-globali` elenca i protocolli dall'host e da un filo
    (`prototype/24-wayland-globali-test.sh`). Poi: se COSMIC supporta
    `wp_security_context_v1`, socket dedicato per filo con i protocolli privilegiati
    filtrati; decisione in un ADR che sostituisce o aggiorna lo 0005.
  - 2026-11-02, misurato dall'host: socket normale 59 protocolli (appunti letti di nascosto, cattura schermo, tastiera virtuale, layer-shell, blocco schermo, gestione finestre e monitor); socket etichettato con `wp_security_context_v1` 36, i 23 privilegiati nascosti. Helper `aracno-socket-sicuro` + servizio utente `aracno-wayland@FILO`; test `24-wayland-sicuro-test.sh` da lanciare. Notato anche: i `.nspawn` hanno `PrivateUsers=no` (root nel filo = root dell'host), da rivedere.

- [x] **T15: fili con spazio utenti separato (PrivateUsers=pick)** (M) — chiesto il 2026-11-02
  - PASS il 2026-11-02 al secondo giro (`25-private-users-test.sh`). Al primo giro `PrivateUsersOwnership` stava in [Exec] (va in [Files]) e nspawn ha cambiato il proprietario dei file: riportati a 0. Decisione: ADR-0012.
  - Oggi (ADR-0001) root nel filo è root dell'host. Ipotesi: con `PrivateUsers=pick` e
    `PrivateUsersOwnership=map` (nessun file cambiato sul disco) funziona tutto se (1) nei fili
    si monta solo `renderD128` reso 0666 da una regola udev (card0 resta chiuso) e (2) il
    socket Wayland etichettato è 0777 dentro `/run/user/UID` (0700).
  - Test: `prototype/25-private-users-test.sh` (I1–I3, G1–G2, W1–W2, A1), `--rimuovi` per tornare indietro.
  - Poi: ADR che aggiorna lo 0001.
