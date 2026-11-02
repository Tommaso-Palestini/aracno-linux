# ADR-0010: Nei fili un socket Wayland etichettato (wp_security_context_v1)

## Stato
Accettata (2026-11-02). Aggiorna ADR-0005: resta "solo il socket Wayland", ma non più quello
normale del compositor.

## Contesto
ADR-0005 montava nei fili il socket normale della sessione (`wayland-1`) e lasciava aperta una
domanda: quali protocolli vede un programma dentro un filo? Misurato il 2026-11-02 su COSMIC
(cosmic-comp 1.0.0) con `aracno/spikes/wayland-globali`:

- **socket normale: 59 protocolli**, fra cui:
  - `ext_data_control_manager_v1`, `zwlr_data_control_manager_v1`: leggere e scrivere gli
    appunti in ogni momento, anche senza finestre in primo piano;
  - `ext_image_copy_capture_manager_v1` e le sorgenti di output e finestre: fotografare lo
    schermo e le singole finestre;
  - `zwp_virtual_keyboard_manager_v1`, `zwp_input_method_manager_v2`: simulare tasti premuti;
  - `zwlr_layer_shell_v1`, `ext_session_lock_manager_v1`: finestre sopra tutto, anche una
    finta schermata di blocco o di login;
  - `zcosmic_toplevel_manager_v1`, `ext_foreign_toplevel_list_v1`, `zwlr_output_manager_v1`,
    i workspace: vedere e comandare le altre finestre, cambiare i monitor.
- COSMIC offre **`wp_security_context_manager_v1`**, il meccanismo che usa Flatpak: un client
  fidato crea un socket "etichettato" e chi si collega da lì è trattato come in sandbox.
  **Dallo stesso socket etichettato: 36 protocolli, i 23 privilegiati nascosti.** Restano
  quelli di un'applicazione normale (finestre, input, GPU, scala, appunti classici, che
  passano solo con un'azione dell'utente e la finestra in primo piano).

## Decisione
- Per ogni filo un servizio utente `aracno-wayland@FILO.service` (in `graphical-session.target`)
  avvia `aracno-socket-sicuro`, che crea `/run/user/UID/aracno-wayland-FILO.sock` con
  `wp_security_context_v1` (sandbox engine `io.github.tommaso_palestini.aracno`, app id
  `io.github.tommaso_palestini.aracno.FILO`, instance id `FILO`) e resta in vita finché
  serve il socket.
- Il `.nspawn` del filo monta quel socket al posto di `wayland-1`:
  `Bind=/run/user/UID/aracno-wayland-FILO.sock:/run/aracno-wayland/wayland-1`.
- Nei fili non cambia niente: `XDG_RUNTIME_DIR=/run/aracno-wayland`, `WAYLAND_DISPLAY=wayland-1`.

Verifica: `prototype/24-wayland-sicuro-test.sh` PASS il 2026-11-02. Da dentro arch e debian 36
protocolli e nessuno dei 20 privilegiati (lista per nome esatto); `vkcube` apre la finestra.

## Alternative considerate
- **Socket normale (ADR-0005)**: scartato per i protocolli sopra.
- **Un compositor annidato per filo**: isolamento migliore ma una finestra unica per filo, più
  GPU, meno integrazione. Resta un'opzione se un giorno servisse isolare anche gli appunti.
- **Filtrare in un proxy Wayland nostro**: più codice da mantenere e da rendere sicuro, per
  ottenere quello che il compositor già fa.

## Conseguenze
- Il filtro lo decide COSMIC: se una versione futura cambia l'elenco dei protocolli privilegiati,
  cambia anche quello che vedono i fili. Il test 24 va rilanciato dopo gli aggiornamenti di COSMIC.
- Un compositor senza `wp_security_context_v1` non va bene per Aracno così com'è: l'helper esce
  con un errore chiaro. Da tenere presente per il ripiego senza layer-shell (M5).
- Se il servizio utente si ferma, le connessioni già aperte restano, ma i programmi nuovi del
  filo non trovano il compositor finché il servizio non riparte (`Restart=on-failure`).
- Il socket è creato dall'utente; i fili lo raggiungono perché girano con `PrivateUsers=no`, cioè
  root nel filo è root dell'host. Questo è un limite d'isolamento più grande del socket e va
  rivisto a parte; con `PrivateUsers=yes` il socket dovrà essere accessibile all'utente mappato.
- Per l'ISO (fase 5c): helper e servizio utente vanno installati dal sistema, e il `.nspawn`
  generato con il percorso giusto. Oggi li installa `prototype/24-wayland-sicuro-test.sh`
  (`--rimuovi` torna al socket normale).
