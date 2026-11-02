# ADR-0012: Fili con spazio utenti separato (PrivateUsers=pick, proprietà mappata)

## Stato
Accettata (2026-11-02). Aggiorna ADR-0001 (`PrivateUsers=no`) e ADR-0004 (GPU: tutta `/dev/dri`).

## Contesto
Dalla fase 0 i fili giravano con `PrivateUsers=no`: root nel filo era root dell'host, e ADR-0001
lo accettava ("un filo è di fiducia quanto l'host"). Con il socket Wayland ormai ristretto
(ADR-0010) era il limite d'isolamento più grande rimasto: un programma compromesso in un filo
poteva diventare root del sistema.

Con lo spazio utenti separato l'utente del filo, root compreso, è sull'host un UID alto senza
permessi. Due cose si rompevano: la GPU (`/dev/dri/renderD128` è `root:render 0660` più un'ACL
per l'utente della sessione) e il socket Wayland (`775` dell'utente).

## Decisione
Nel `.nspawn` di ogni filo:
```
[Exec]
PrivateUsers=pick

[Files]
PrivateUsersOwnership=map
Bind=/dev/dri/renderD128
Bind=/run/user/UID/aracno-wayland-FILO.sock:/run/aracno-wayland/wayland-1
```
- `pick`: systemd sceglie per ogni filo un intervallo di 65536 UID libero.
- `map` (in `[Files]`, non in `[Exec]`): il kernel traduce la proprietà dei file al volo con un
  mount idmap; sul disco i file restano numerati da 0, come in una distro normale.
- Solo il nodo `renderD128` (disegnare), reso `0666` da `/etc/udev/rules.d/70-aracno-render.rules`.
  È il nodo pensato per i programmi non privilegiati: non comanda lo schermo. `card0`, che lo
  comanda, non entra più nei fili; `DeviceAllow` del drop-in `gpu.conf` solo per `renderD128`.
- Il socket Wayland etichettato è `0777`, ma sta in `/run/user/UID` (`0700`): sull'host ci
  arriva solo l'utente, il filo ci arriva perché il socket gli viene montato. L'helper allarga i
  permessi solo se la cartella è privata.

Verifica: `prototype/25-private-users-test.sh` PASS il 2026-11-02. Root di arch = UID 1742209024
sull'host, di debian 1766326272; `etc/passwd` sul disco resta di root; Vulkan sulla Radeon (RADV
RAVEN) in entrambi; `card0` non visibile; 36 protocolli Wayland e nessuno privilegiato; vkcube
apre la finestra; aracnod cambia filo nei due sensi.

## Alternative considerate
- **Restare con `PrivateUsers=no`**: scartato, è il motivo di questa decisione.
- **`PrivateUsersOwnership=chown`** (il default che si è attivato per errore al primo giro, con la
  chiave nella sezione sbagliata): funziona, ma riscrive il proprietario di ogni file del filo
  su un UID casuale. Non si torna indietro senza un'altra riscrittura, e le immagini dell'ISO
  andrebbero riscritte al primo avvio. `map` non tocca il disco.
- **ACL sulla GPU per gli UID mappati**: gli UID cambiano per filo e logind gestisce le ACL dei
  dispositivi della sessione: fragile.
- **Socket Wayland con ACL per l'UID mappato** invece di `0777` in una cartella privata: l'UID
  dipende da `pick`; la cartella `0700` dà lo stesso risultato senza saperlo in anticipo.

## Conseguenze
- Un processo nel filo, anche root, non ha permessi sull'host oltre a quelli di un utente
  qualsiasi (più i socket e i nodi montati apposta).
- Qualsiasi utente locale dell'host può usare `renderD128` per disegnare: su un PC personale va
  bene, ed era la regola su molte distro prima delle ACL di logind.
- Serve un filesystem che supporti i mount idmap (ext4 e btrfs sì; kernel ≥ 5.12).
- Le copie di sicurezza (T12) restano numerate da 0 come il filo: il ripristino non cambia.
- Se un filo si trova con i file già spostati (per esempio dopo un avvio con `chown`), si
  riportano a 0 a filo spento con
  `systemd-nspawn --settings=no -D DIR --private-users=0 --private-users-ownership=chown /bin/true`.
- Gli script della fase 0–4 (`01-create-strands.sh`, `04-gpu-bind.sh`, `07-wayland-bind.sh`)
  scrivono ancora la configurazione vecchia: vanno consolidati nella generazione dei `.nspawn`
  per l'ISO (fase 5c). Oggi la configurazione vera la applicano i test 24 e 25
  (`--rimuovi` torna indietro).
