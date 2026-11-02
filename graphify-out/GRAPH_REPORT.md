# Graph Report - idea-linux  (2026-11-02)

## Corpus Check
- 46 files · ~21,204 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 10 file(s) not represented in the graph (top: .conf 3, (none) 2, .service 2)

## Summary
- 450 nodes · 650 edges · 37 communities (26 shown, 11 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `302f70cd`
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
- ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland
- lib.rs
- README.md
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
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `TentacleName` - 25 edges
2. `AracnoError` - 19 edges
3. `TentacleState` - 13 edges
4. `Spec: `aracnod` (con `aracno-proto`)` - 13 edges
5. `n()` - 12 edges
6. `Spec: `aracno-menu`` - 11 edges
7. `Operazione` - 9 edges
8. `esegui()` - 9 edges
9. `Step` - 9 edges
10. `unit_info()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `n()` --references--> `TentacleName`  [EXTRACTED]
  aracno/aracnod/src/list.rs → aracno/aracno-proto/src/lib.rs
- `stato()` --references--> `UnitInfo`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/list.rs
- `tentacoli()` --references--> `UnitInfo`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/list.rs
- `esegui()` --references--> `Step`  [INFERRED]
  aracno/aracnod/src/main.rs → aracno/aracnod/src/switch.rs
- `entry()` --references--> `ProtoError`  [EXTRACTED]
  aracno/aracnod/src/list.rs → aracno/aracno-proto/src/lib.rs

## Import Cycles
- 1-file cycle: `aracno/aracnod/src/main.rs -> aracno/aracnod/src/main.rs`

## Communities (37 total, 11 thin omitted)

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
Cohesion: 0.16
Nodes (19): TentacleName, gia_attivo_e_unico_non_fa_nulla(), i_congelamenti_vengono_sempre_prima(), n(), plan(), plan_stop(), Step, Freeze (+11 more)

### Community 10 - "ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus"
Cohesion: 0.15
Nodes (12): ADR-0008: Lo switch passa da `aracnod`, un servizio di sistema con utente dedicato, polkit e D-Bus, Alternative considerate, `aracnod` come root, Conseguenze, Contesto, Data, Decisione, Il menù chiama systemd direttamente, con una regola polkit per l'utente (+4 more)

### Community 11 - "ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland"
Cohesion: 0.18
Nodes (10): ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 12 - "lib.rs"
Cohesion: 0.07
Nodes (21): ACTION_MANAGE, ACTION_SWITCH, BUS_NAME, BUSY, FAILED, INTERFACE, INVALID_NAME, MAX_NAME_LEN (+13 more)

### Community 13 - "README.md"
Cohesion: 0.06
Nodes (31): ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Docker / Podman, LXC/LXD (Incus) (+23 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

### Community 15 - "Spec: `aracnod` (con `aracno-proto`)"
Cohesion: 0.07
Nodes (25): Mappa dei componenti: menù a tentacoli, Assunzioni, Comandi, Comportamento, Confini, Criteri di successo, Domande aperte, Obiettivo (+17 more)

### Community 16 - "list.rs"
Cohesion: 0.15
Nodes (12): attivo_con_memoria_e_senza_limite(), congelato_con_limite(), Entry, entry(), info(), memoria_sconosciuta_vale_zero(), n(), nomi_delle_immagini() (+4 more)

### Community 17 - "TentacleName"
Cohesion: 0.10
Nodes (14): ALREADY_SUBSCRIBED, freeze(), image_names(), job(), Machined, next(), NO_SUCH_UNIT, Service (+6 more)

### Community 18 - "Piano: menù a tentacoli (`octod` + `octo-menu`)"
Cohesion: 0.25
Nodes (7): Decisioni architetturali, Domande aperte, Fasi, Grafo delle dipendenze, Piano: menù a tentacoli (`aracnod` + `aracno-menu`), Rischi, Sintesi

### Community 19 - "Task: menù a tentacoli"
Cohesion: 0.25
Nodes (7): Checkpoint A, Checkpoint B, Checkpoint C, Fase 1: prove dei rischi, Fase 2: `aracnod`, Fase 3: `aracno-menu`, Task: menù a tentacoli

### Community 20 - "09-upgrade-test.sh"
Cohesion: 0.60
Nodes (3): fail(), inside(), 09-upgrade-test.sh script

### Community 21 - "10-polkit-spike.sh"
Cohesion: 0.56
Nodes (7): allow(), as(), deny(), fail(), ok(), sd(), 10-polkit-spike.sh script

### Community 24 - "ADR-0007: Menù a tentacoli come schermata a tutto schermo"
Cohesion: 0.18
Nodes (10): ADR-0007: Menù a tentacoli come schermata a tutto schermo, Alternative considerate, Applet nella barra di COSMIC, Conseguenze, Contesto, Data, Decisione, Finestra normale (+2 more)

### Community 25 - "12-aracnod-test.sh"
Cohesion: 0.44
Nodes (9): attesa_errore(), call(), fail(), ms_of(), ok(), 12-aracnod-test.sh script, stati(), stato_di() (+1 more)

### Community 26 - "aracnod/src/main.rs"
Cohesion: 0.09
Nodes (22): AracnoError, Busy, Failed, InvalidName, NotAuthorized, NotFound, ZBus, nomi_degli_errori_coerenti_con_proto() (+14 more)

### Community 27 - "ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd"
Cohesion: 0.18
Nodes (10): ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Passare la GPU a una VM, Rendering software (llvmpipe) (+2 more)

### Community 28 - "11-install-aracnod.sh"
Cohesion: 0.47
Nodes (8): aracno_stato(), atteso(), confronta(), fail(), lista(), ok(), reload_bus(), 11-install-aracnod.sh script

### Community 29 - "13-aracnod-stop-test.sh"
Cohesion: 0.54
Nodes (7): attesa_errore(), call(), fail(), ok(), 13-aracnod-stop-test.sh script, stati(), stato_di()

### Community 33 - "Revisione di sicurezza di aracnod (T7) — 2026-11-02"
Cohesion: 0.33
Nodes (5): Confini di fiducia, Dipendenze, Revisione di sicurezza di aracnod (T7) — 2026-11-02, Risultati, STRIDE

## Knowledge Gaps
- **11 isolated node(s):** `aracno-proto`, `InvalidName`, `Active`, `Frozen`, `Off` (+6 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 201 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TentacleName` connect `switch.rs` to `list.rs`, `TentacleName`, `aracnod/src/main.rs`, `lib.rs`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **What connects `aracno-proto`, `InvalidName`, `Active` to the rest of the system?**
  _11 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `lib.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.07459677419354839 - nodes in this community are weakly interconnected._
- **Why does `AracnoError` connect `aracnod/src/main.rs` to `list.rs`, `auth.rs`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.05714285714285714 - nodes in this community are weakly interconnected._
- **Why does `TentacleState` connect `lib.rs` to `switch.rs`, `aracnod/src/main.rs`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Should `Spec: `aracnod` (con `aracno-proto`)` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._