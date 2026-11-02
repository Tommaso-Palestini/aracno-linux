# Revisione di sicurezza di aracnod (T7) — 2026-11-02

Oggetto: `aracno/aracnod`, `aracno/aracno-proto`, i file in `aracno/data/` e
`prototype/11-install-aracnod.sh`. Skill usata: security-and-hardening.

## Confini di fiducia

| Confine | Chi scrive il dato | Difesa |
|---|---|---|
| Chiamate D-Bus a `Aracno1.Manager` | qualsiasi processo locale | nome validato (`StrandName`), poi polkit sul mittente (subject `system-bus-name`, niente race sul PID) |
| Nomi delle immagini da machined | root (`/var/lib/machines`) | rifiltrati con `StrandName` |
| Segnali `JobRemoved` | solo systemd (nome posseduto da PID 1) | confronto sul percorso del job |
| aracnod → systemd | aracnod (utente `aracno`) | `50-aracno.rules`: solo `manage-units`, solo `systemd-nspawn@NOME.service`, solo verbi start/stop, il resto NO |

Bene da proteggere: lo stato dei fili (un filo fermato o congelato
fa perdere il lavoro aperto) e i permessi di `aracno` su systemd.

## STRIDE

- **Spoofing**: l'identità viene dal bus (kernel), non dal messaggio. OK.
- **Tampering**: il nome non può portare a unit diverse da `systemd-nspawn@…`
  (regex identica in Rust e in polkit). OK.
- **Repudiation**: ogni operazione, riuscita o rifiutata, va nel journal con l'uid. OK.
- **Information disclosure**: errori verso il client generici, dettagli solo nel
  journal. `ListStrands` è leggibile da tutti gli utenti locali (scelta della spec).
- **Denial of service**: vedi punti 2 e 3 sotto.
- **Elevation of privilege**: utente dedicato, nessuna capability, unit con
  esposizione 0.2, `PrivateUsers=yes`, `MemoryDenyWriteExecute=yes`. OK.

## Risultati

1. **Corretto** — un nome non valido veniva scritto nel journal per intero, prima
   del controllo dei permessi: chiunque poteva riempire il journal con righe
   enormi. Ora `per_log` lo escapa e lo tronca a 64 caratteri (test
   `nome_rifiutato_troncato_nel_log`).
2. **Accettato** — nessun limite di frequenza: un utente locale può chiamare
   `Switch` in ciclo e far lavorare polkit. Su un desktop a un utente il costo è
   basso; da rivedere se Aracno diventa multiutente.
3. **Accettato** — `Switch` non chiede password nella sessione attiva: qualsiasi
   programma dell'utente (non in sandbox) può cambiare filo. È il
   comportamento voluto dalla spec; Flatpak blocca il bus di sistema di default.
4. **Accettato** — `Stop` usa `auth_admin_keep`: dopo la password, per qualche
   minuto anche altri programmi della stessa sessione possono fermare i
   fili senza chiederla (verificato in O7b).
5. **Nota** — `50-aracno.rules` permette ad `aracno` qualsiasi unit
   `systemd-nspawn@*`, non solo le immagini di machined. aracnod usa solo i nomi
   di machined, e su questo sistema le due cose coincidono.

## Dipendenze

- `cargo audit`: nessuna vulnerabilità nota su 56 dipendenze.
- `cargo deny check`: advisories, bans, licenses, sources ok. Per farlo passare le crate sono segnate `publish = false` (non vanno su crates.io, quindi la dipendenza per percorso non è un wildcard) e la licenza Unlicense, non usata, è uscita dalla lista.

## Aggiunta (2026-11-02, stato disallineato)

aracnod ora legge `/sys/fs/cgroup/machine.slice/systemd-nspawn@NOME.service/cgroup.events`
per sapere se un filo è davvero congelato (systemd 255 può restare indietro, vedi ADR-0002).
- Il percorso nasce solo da un `StrandName` già validato e dal `ControlGroup` di systemd, che
  deve essere esattamente `/machine.slice/systemd-nspawn@NOME.service` (`list::file_eventi`,
  con test per `..` e nomi diversi). Nessun dato del chiamante entra nel percorso.
- Sola lettura, dentro `ProtectSystem=strict` e `ProtectControlGroups=yes`. Se il file non si
  legge si usa solo systemd, come prima.
- Il riallineamento (thaw o freeze del filo disallineato) avviene solo in Switch e Stop, cioè
  dopo il controllo di polkit, e usa gli stessi permessi di prima (`50-aracno.rules`).
  `ListStrands` resta di sola lettura.
