# Graph Report - idea-linux  (2026-11-02)

## Corpus Check
- 71 files · ~38,635 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 17 file(s) not represented in the graph (top: (none) 4, .conf 4, .service 2)

## Summary
- 749 nodes · 1196 edges · 63 communities (49 shown, 14 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `69bf0dea`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- 03-bench-switch.sh
- Octopus Linux — istruzioni per l'agente
- 04-gpu-bind.sh
- 05-gpu-driver.sh
- 06-vram-test.sh
- memhog.c
- 07-wayland-bind.sh
- Da fare
- ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)
- switch.rs
- ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus
- client.rs
- lib.rs
- ADR-0001: Fili come container systemd-nspawn su un unico kernel
- 08-ram-limit.sh
- Spec: `aracnod` (con `aracno-proto`)
- aracno-cli/src/main.rs
- TentacleName
- Piano: menù a tentacoli (`octod` + `octo-menu`)
- Task: menù a tentacoli
- 09-upgrade-test.sh
- 10-polkit-spike.sh
- aracno-menu/src/main.rs
- ADR-0007: Menù a tentacoli come schermata a tutto schermo
- 12-aracnod-test.sh
- aracnod/src/main.rs
- ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd
- 11-install-aracnod.sh
- 13-aracnod-stop-test.sh
- auth.rs
- aracno-proto
- aracno-spike-layer-shell
- Revisione di sicurezza di aracnod (T7) — 2026-11-02
- view.rs
- 14-aracno-cli-test.sh
- 01-create-strands.sh
- ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`
- 15-watchdog-freeze.sh
- radial.rs
- ADR-0005: Desktop: nei fili si monta solo il socket Wayland
- 16-menu-base-test.sh
- ADR-0003: Rete dei fili condivisa con l'host
- 17-menu-switch-test.sh
- list.rs
- ADR-0009: Disco cifrato con LUKS2, due password all'avvio
- README.md
- Vista
- ragnatela.rs
- 19-stato-disallineato-test.sh
- Filo
- 18-menu-grafica-test.sh
- 21-menu-t11-test.sh
- 20-tasto-rapido.sh
- aracno-socket-sicuro.rs
- 23-ram-pressione-test.sh
- 24-wayland-sicuro-test.sh
- 22-upgrade-copia-test.sh
- aracno-wayland-globali
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `StrandState` - 28 edges
2. `StrandName` - 27 edges
3. `Vista` - 23 edges
4. `AracnoError` - 20 edges
5. `Filo` - 19 edges
6. `Spec: `aracnod` (con `aracno-proto`)` - 13 edges
7. `n()` - 12 edges
8. `23-ram-pressione-test.sh script` - 12 edges
9. `Spec: `aracno-menu`` - 11 edges
10. `bottone()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `mostra()` --calls--> `messaggio()`  [INFERRED]
  aracno/aracno-menu/src/main.rs → aracno/aracno-proto/src/client.rs
- `scelta()` --calls--> `messaggio()`  [INFERRED]
  aracno/aracno-menu/src/main.rs → aracno/aracno-proto/src/client.rs
- `bottone()` --calls--> `scelta()`  [INFERRED]
  aracno/aracno-menu/src/view.rs → aracno/aracno-menu/src/main.rs
- `simbolo()` --references--> `StrandState`  [EXTRACTED]
  aracno/aracno-proto/src/client.rs → aracno/aracno-proto/src/lib.rs
- `fili()` --references--> `UnitInfo`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/list.rs

## Import Cycles
- 1-file cycle: `aracno/aracnod/src/main.rs -> aracno/aracnod/src/main.rs`

## Communities (63 total, 14 thin omitted)

### Community 0 - "03-bench-switch.sh"
Cohesion: 0.60
Nodes (5): do_switch(), other_of(), read_count(), 03-bench-switch.sh script, start_counter()

### Community 1 - "Octopus Linux — istruzioni per l'agente"
Cohesion: 0.40
Nodes (4): Aracno Linux — istruzioni per l'agente, Contesto e comandi utili, Principi, Skill del progetto

### Community 4 - "06-vram-test.sh"
Cohesion: 0.50
Nodes (7): alloc_log(), inside(), near(), ok_of(), 06-vram-test.sh script, start_alloc(), vram()

### Community 5 - "memhog.c"
Cohesion: 0.18
Nodes (3): fill_page(), main(), ms_since()

### Community 7 - "Da fare"
Cohesion: 0.20
Nodes (9): Aracno Linux — roadmap, Da fare, Decisioni prese, Fase 5 — ISO installabile (base: Debian trixie, `live-build`), Fatto, Note, Obiettivo finale (da ragionare più avanti), Obiettivo: live su chiavetta (+1 more)

### Community 8 - "ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)"
Cohesion: 0.18
Nodes (10): ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`), Alternative considerate, Conseguenze, Contesto, Data, Decisione, SIGSTOP/SIGCONT ai processi, Solo priorità (CPUWeight/nice) senza congelare (+2 more)

### Community 9 - "switch.rs"
Cohesion: 0.20
Nodes (18): filo_sconosciuto(), gia_attivo_e_unico_non_fa_nulla(), i_congelamenti_vengono_sempre_prima(), n(), plan(), plan_stop(), Step, Freeze (+10 more)

### Community 10 - "ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus"
Cohesion: 0.15
Nodes (12): ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus, Alternative considerate, `aracnod` come root, Conseguenze, Contesto, Data, Decisione, Il menù chiama systemd direttamente, con una regola polkit per l'utente (+4 more)

### Community 11 - "client.rs"
Cohesion: 0.10
Nodes (9): CARTELLA_TRADUZIONI, da_righe(), DOMINIO, fili(), Manager, messaggio(), messaggio_errore(), righe_da_aracnod() (+1 more)

### Community 12 - "lib.rs"
Cohesion: 0.10
Nodes (14): ACTION_MANAGE, ACTION_SWITCH, BUS_NAME, BUSY, FAILED, INTERFACE, INVALID_NAME, MAX_NAME_LEN (+6 more)

### Community 13 - "ADR-0001: Fili come container systemd-nspawn su un unico kernel"
Cohesion: 0.18
Nodes (11): ADR-0001: Fili come container systemd-nspawn su un unico kernel, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Docker / Podman, LXC/LXD (Incus) (+3 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

### Community 15 - "Spec: `aracnod` (con `aracno-proto`)"
Cohesion: 0.07
Nodes (25): Mappa dei componenti: menù a ragnatela, Assunzioni, Comandi, Comportamento, Confini, Criteri di successo, Domande aperte, Obiettivo (+17 more)

### Community 16 - "aracno-cli/src/main.rs"
Cohesion: 0.15
Nodes (7): AIUTO, Errore, esegui(), fili(), main(), prossimo(), attivi()

### Community 17 - "TentacleName"
Cohesion: 0.08
Nodes (17): StrandName, file_eventi(), n(), ALREADY_SUBSCRIBED, freeze(), image_names(), job(), Machined (+9 more)

### Community 18 - "Piano: menù a tentacoli (`octod` + `octo-menu`)"
Cohesion: 0.25
Nodes (7): Decisioni architetturali, Domande aperte, Fasi, Grafo delle dipendenze, Piano: menù a ragnatela (`aracnod` + `aracno-menu`), Rischi, Sintesi

### Community 19 - "Task: menù a tentacoli"
Cohesion: 0.22
Nodes (8): Checkpoint A, Checkpoint B, Checkpoint C, Fase 1: prove dei rischi, Fase 2: `aracnod`, Fase 3: `aracno-menu`, Prima della fase 5 (chiesto il 2026-11-02), Task: menù a ragnatela

### Community 20 - "09-upgrade-test.sh"
Cohesion: 0.60
Nodes (3): fail(), inside(), 09-upgrade-test.sh script

### Community 21 - "10-polkit-spike.sh"
Cohesion: 0.56
Nodes (7): allow(), as(), deny(), fail(), ok(), sd(), 10-polkit-spike.sh script

### Community 22 - "aracno-menu/src/main.rs"
Cohesion: 0.11
Nodes (13): APP_ID, ascolta(), carica_stile(), chiudi(), crea(), main(), mostra(), prepara_superficie() (+5 more)

### Community 24 - "ADR-0007: Menù a tentacoli come schermata a tutto schermo"
Cohesion: 0.18
Nodes (11): ADR-0007: Menù a ragnatela come schermata a tutto schermo, Alternative considerate, Applet nella barra di COSMIC, Conseguenze, Contesto, Data, Decisione, Finestra normale (+3 more)

### Community 25 - "12-aracnod-test.sh"
Cohesion: 0.44
Nodes (9): attesa_errore(), call(), fail(), ms_of(), ok(), 12-aracnod-test.sh script, stati(), stato_di() (+1 more)

### Community 26 - "aracnod/src/main.rs"
Cohesion: 0.10
Nodes (22): AracnoError, Busy, Failed, InvalidName, NotAuthorized, NotFound, ZBus, nomi_degli_errori_coerenti_con_proto() (+14 more)

### Community 27 - "ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd"
Cohesion: 0.18
Nodes (10): ADR-0004: GPU nei fili con bind di `/dev/dri` e drop-in systemd, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Passare la GPU a una VM, Rendering software (llvmpipe) (+2 more)

### Community 28 - "11-install-aracnod.sh"
Cohesion: 0.47
Nodes (8): aracno_stato(), atteso(), confronta(), fail(), lista(), ok(), reload_bus(), 11-install-aracnod.sh script

### Community 29 - "13-aracnod-stop-test.sh"
Cohesion: 0.54
Nodes (7): attesa_errore(), call(), fail(), ok(), 13-aracnod-stop-test.sh script, stati(), stato_di()

### Community 31 - "aracno-proto"
Cohesion: 0.50
Nodes (4): aracno-cli, aracno-menu, aracno-proto, aracnod

### Community 33 - "Revisione di sicurezza di aracnod (T7) — 2026-11-02"
Cohesion: 0.29
Nodes (6): Aggiunta (2026-11-02, stato disallineato), Confini di fiducia, Dipendenze, Revisione di sicurezza di aracnod (T7) — 2026-11-02, Risultati, STRIDE

### Community 34 - "view.rs"
Cohesion: 0.13
Nodes (9): APERTURA, CENTRO_H, CENTRO_W, CORSA, dove_sei(), INCHIOSTRO, NODO_H, NODO_W (+1 more)

### Community 35 - "14-aracno-cli-test.sh"
Cohesion: 0.62
Nodes (6): errore(), fail(), it(), ok(), 14-aracno-cli-test.sh script, stato_api()

### Community 37 - "ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`"
Cohesion: 0.18
Nodes (10): ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`, Alternative considerate, Altre basi (Arch con archiso, Fedora con kiwi), Conseguenze, Contesto, Data, Decisione, Distro da zero (Linux From Scratch, buildroot) (+2 more)

### Community 39 - "15-watchdog-freeze.sh"
Cohesion: 0.48
Nodes (5): fail(), ok(), p(), pronto(), 15-watchdog-freeze.sh script

### Community 40 - "radial.rs"
Cohesion: 0.09
Nodes (28): A, ANELLI, centro(), da_uno_a_otto_fili_senza_sovrapposizioni_su_1366x768(), Direzione, Destra, Giu, Sinistra (+20 more)

### Community 41 - "ADR-0005: Desktop: nei fili si monta solo il socket Wayland"
Cohesion: 0.18
Nodes (10): ADR-0005: Desktop: nei fili si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 42 - "16-menu-base-test.sh"
Cohesion: 0.47
Nodes (9): apri(), chiedi(), DBUS_SYSTEM_BUS_ADDRESS, fail(), log_pulito(), ok(), 16-menu-base-test.sh script, uscito_bene() (+1 more)

### Community 43 - "ADR-0003: Rete dei fili condivisa con l'host"
Cohesion: 0.20
Nodes (9): ADR-0003: Rete dei fili condivisa con l'host, Alternative considerate, Bridge di rete verso la LAN, Conseguenze, Contesto, Data, Decisione, Stato (+1 more)

### Community 44 - "17-menu-switch-test.sh"
Cohesion: 0.62
Nodes (6): chiedi(), fail(), ok(), prova(), 17-menu-switch-test.sh script, vivo()

### Community 45 - "list.rs"
Cohesion: 0.12
Nodes (19): ProtoError, InvalidName, UnknownState, attivo_con_memoria_e_senza_limite(), congelato_con_limite(), d_accordo_o_kernel_non_letto(), Entry, entry() (+11 more)

### Community 46 - "ADR-0009: Disco cifrato con LUKS2, due password all'avvio"
Cohesion: 0.33
Nodes (5): ADR-0009: Disco cifrato con LUKS2, due password all'avvio, Alternative scartate, Conseguenze, Contesto, Decisione

### Community 48 - "Vista"
Cohesion: 0.17
Nodes (6): disegna_fili(), Disegno, testo_dove(), Vista, stato_it(), tr()

### Community 49 - "ragnatela.rs"
Cohesion: 0.15
Nodes (15): colore(), colori_solo_se_chiesti(), disegna(), f(), filo_attivo(), ragnatela_ordinata_e_senza_colori(), f(), f() (+7 more)

### Community 50 - "19-stato-disallineato-test.sh"
Cohesion: 0.31
Nodes (8): fail(), hop(), kernel(), ok(), pronto(), 19-stato-disallineato-test.sh script, togli_prova(), u()

### Community 51 - "Filo"
Cohesion: 0.23
Nodes (6): bottone(), classe(), Nodo, testo_accessibile(), testo_stato(), main()

### Community 52 - "18-menu-grafica-test.sh"
Cohesion: 0.57
Nodes (6): chiedi(), fail(), ok(), pulito(), 18-menu-grafica-test.sh script, vivo()

### Community 54 - "21-menu-t11-test.sh"
Cohesion: 0.60
Nodes (5): chiedi(), fail(), ok(), 21-menu-t11-test.sh script, vivo()

### Community 56 - "aracno-socket-sicuro.rs"
Cohesion: 0.15
Nodes (3): Stato, Globali, main()

### Community 57 - "23-ram-pressione-test.sh"
Cohesion: 0.26
Nodes (14): avail(), fail(), ferma(), hog(), hop(), mb(), ok(), ooms() (+6 more)

### Community 58 - "24-wayland-sicuro-test.sh"
Cohesion: 0.48
Nodes (5): fail(), ok(), riavvia_fili(), 24-wayland-sicuro-test.sh script, utente()

### Community 59 - "22-upgrade-copia-test.sh"
Cohesion: 0.53
Nodes (4): byte(), fail(), ok(), 22-upgrade-copia-test.sh script

## Knowledge Gaps
- **18 isolated node(s):** `aracno-cli`, `aracno-menu`, `Su`, `Giu`, `Sinistra` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 280 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `StrandState` connect `ragnatela.rs` to `view.rs`, `switch.rs`, `client.rs`, `lib.rs`, `list.rs`, `Vista`, `Filo`, `aracnod/src/main.rs`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **What connects `aracno-cli`, `aracno-menu`, `Su` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `client.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Why does `StrandName` connect `TentacleName` to `switch.rs`, `aracnod/src/main.rs`, `lib.rs`, `list.rs`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Should `lib.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._
- **Why does `main()` connect `Filo` to `aracno-socket-sicuro.rs`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `Spec: `aracnod` (con `aracno-proto`)` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._