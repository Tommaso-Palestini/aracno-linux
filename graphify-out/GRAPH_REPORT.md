# Graph Report - idea-linux  (2026-11-02)

## Corpus Check
- 52 files · ~24,255 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 11 file(s) not represented in the graph (top: .conf 4, (none) 2, .service 2)

## Summary
- 511 nodes · 757 edges · 44 communities (33 shown, 11 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.63)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bfbcf04b`
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
- ragnatela.rs
- lib.rs
- ADR-0001: Fili come container systemd-nspawn su un unico kernel
- 08-ram-limit.sh
- Spec: `aracnod` (con `aracno-proto`)
- list.rs
- TentacleName
- Piano: menù a tentacoli (`octod` + `octo-menu`)
- Task: menù a tentacoli
- 09-upgrade-test.sh
- 10-polkit-spike.sh
- main.rs
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
- ADR-0003: Rete dei fili condivisa con l'host
- 14-aracno-cli-test.sh
- 01-create-strands.sh
- ADR-0005: Desktop: nei fili si monta solo il socket Wayland
- ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`
- 15-watchdog-freeze.sh
- ADR-0009: Disco cifrato con LUKS2, due password all'avvio
- README.md
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `StrandName` - 25 edges
2. `StrandState` - 20 edges
3. `AracnoError` - 19 edges
4. `Spec: `aracnod` (con `aracno-proto`)` - 13 edges
5. `n()` - 12 edges
6. `Spec: `aracno-menu`` - 11 edges
7. `Operazione` - 9 edges
8. `esegui()` - 9 edges
9. `Step` - 9 edges
10. `unit_info()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `fili()` --references--> `UnitInfo`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/list.rs
- `stato()` --references--> `UnitInfo`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/list.rs
- `esegui()` --references--> `Step`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/switch.rs
- `fili()` --calls--> `da_righe()`  [INFERRED]
  aracno/aracno-cli/src/main.rs → aracno/aracno-cli/src/ragnatela.rs
- `fili()` --references--> `Filo`  [INFERRED]
  aracno/aracno-cli/src/main.rs → aracno/aracno-cli/src/ragnatela.rs

## Import Cycles
- 1-file cycle: `aracno/aracnod/src/main.rs -> aracno/aracnod/src/main.rs`

## Communities (44 total, 11 thin omitted)

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

### Community 11 - "ragnatela.rs"
Cohesion: 0.07
Nodes (26): AIUTO, Errore, esegui(), fili(), main(), Manager, prossimo(), attivi() (+18 more)

### Community 12 - "lib.rs"
Cohesion: 0.08
Nodes (14): ACTION_MANAGE, ACTION_SWITCH, BUS_NAME, BUSY, FAILED, INTERFACE, INVALID_NAME, MAX_NAME_LEN (+6 more)

### Community 13 - "ADR-0001: Fili come container systemd-nspawn su un unico kernel"
Cohesion: 0.17
Nodes (11): ADR-0001: Fili come container systemd-nspawn su un unico kernel, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Docker / Podman, LXC/LXD (Incus) (+3 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

### Community 15 - "Spec: `aracnod` (con `aracno-proto`)"
Cohesion: 0.07
Nodes (25): Mappa dei componenti: menù a ragnatela, Assunzioni, Comandi, Comportamento, Confini, Criteri di successo, Domande aperte, Obiettivo (+17 more)

### Community 16 - "list.rs"
Cohesion: 0.16
Nodes (14): ProtoError, InvalidName, UnknownState, attivo_con_memoria_e_senza_limite(), congelato_con_limite(), Entry, entry(), info() (+6 more)

### Community 17 - "TentacleName"
Cohesion: 0.09
Nodes (16): StrandName, n(), ALREADY_SUBSCRIBED, freeze(), image_names(), job(), Machined, next() (+8 more)

### Community 18 - "Piano: menù a tentacoli (`octod` + `octo-menu`)"
Cohesion: 0.25
Nodes (7): Decisioni architetturali, Domande aperte, Fasi, Grafo delle dipendenze, Piano: menù a ragnatela (`aracnod` + `aracno-menu`), Rischi, Sintesi

### Community 19 - "Task: menù a tentacoli"
Cohesion: 0.25
Nodes (7): Checkpoint A, Checkpoint B, Checkpoint C, Fase 1: prove dei rischi, Fase 2: `aracnod`, Fase 3: `aracno-menu`, Task: menù a ragnatela

### Community 20 - "09-upgrade-test.sh"
Cohesion: 0.60
Nodes (3): fail(), inside(), 09-upgrade-test.sh script

### Community 21 - "10-polkit-spike.sh"
Cohesion: 0.56
Nodes (7): allow(), as(), deny(), fail(), ok(), sd(), 10-polkit-spike.sh script

### Community 24 - "ADR-0007: Menù a tentacoli come schermata a tutto schermo"
Cohesion: 0.18
Nodes (10): ADR-0007: Menù a ragnatela come schermata a tutto schermo, Alternative considerate, Applet nella barra di COSMIC, Conseguenze, Contesto, Data, Decisione, Finestra normale (+2 more)

### Community 25 - "12-aracnod-test.sh"
Cohesion: 0.44
Nodes (9): attesa_errore(), call(), fail(), ms_of(), ok(), 12-aracnod-test.sh script, stati(), stato_di() (+1 more)

### Community 26 - "aracnod/src/main.rs"
Cohesion: 0.09
Nodes (21): AracnoError, Busy, Failed, InvalidName, NotAuthorized, NotFound, ZBus, nomi_degli_errori_coerenti_con_proto() (+13 more)

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
Cohesion: 0.67
Nodes (3): aracno-cli, aracno-proto, aracnod

### Community 33 - "Revisione di sicurezza di aracnod (T7) — 2026-11-02"
Cohesion: 0.33
Nodes (5): Confini di fiducia, Dipendenze, Revisione di sicurezza di aracnod (T7) — 2026-11-02, Risultati, STRIDE

### Community 34 - "ADR-0003: Rete dei fili condivisa con l'host"
Cohesion: 0.22
Nodes (9): ADR-0003: Rete dei fili condivisa con l'host, Alternative considerate, Bridge di rete verso la LAN, Conseguenze, Contesto, Data, Decisione, Stato (+1 more)

### Community 35 - "14-aracno-cli-test.sh"
Cohesion: 0.62
Nodes (6): errore(), fail(), it(), ok(), 14-aracno-cli-test.sh script, stato_api()

### Community 37 - "ADR-0005: Desktop: nei fili si monta solo il socket Wayland"
Cohesion: 0.20
Nodes (10): ADR-0005: Desktop: nei fili si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 38 - "ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`"
Cohesion: 0.20
Nodes (10): ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`, Alternative considerate, Altre basi (Arch con archiso, Fedora con kiwi), Conseguenze, Contesto, Data, Decisione, Distro da zero (Linux From Scratch, buildroot) (+2 more)

### Community 39 - "15-watchdog-freeze.sh"
Cohesion: 0.48
Nodes (5): fail(), ok(), p(), pronto(), 15-watchdog-freeze.sh script

### Community 40 - "ADR-0009: Disco cifrato con LUKS2, due password all'avvio"
Cohesion: 0.33
Nodes (5): ADR-0009: Disco cifrato con LUKS2, due password all'avvio, Alternative scartate, Conseguenze, Contesto, Decisione

## Knowledge Gaps
- **11 isolated node(s):** `aracno-cli`, `InvalidName`, `Active`, `Frozen`, `Off` (+6 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 215 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `StrandName` connect `TentacleName` to `list.rs`, `switch.rs`, `aracnod/src/main.rs`, `lib.rs`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **What connects `aracno-cli`, `InvalidName`, `Active` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ragnatela.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.07215541165587419 - nodes in this community are weakly interconnected._
- **Why does `StrandState` connect `ragnatela.rs` to `list.rs`, `switch.rs`, `aracnod/src/main.rs`, `lib.rs`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Should `lib.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Why does `AracnoError` connect `aracnod/src/main.rs` to `ragnatela.rs`, `lib.rs`, `auth.rs`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Should `Spec: `aracnod` (con `aracno-proto`)` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._