# Graph Report - idea-linux  (2026-11-01)

## Corpus Check
- 40 files · ~16,780 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 8 file(s) not represented in the graph (top: .conf 3, (none) 2, .service 2)

## Summary
- 346 nodes · 424 edges · 33 communities (23 shown, 10 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e99c6a1c`
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
- ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel
- ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd
- ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland
- lib.rs
- README.md
- 08-ram-limit.sh
- Spec: `octo-menu`
- list.rs
- systemd.rs
- Piano: menù a tentacoli (`octod` + `octo-menu`)
- Task: menù a tentacoli
- 09-upgrade-test.sh
- 10-polkit-spike.sh
- main.rs
- octo-spike-layer-shell
- ADR-0008: Lo switch passa da `octod`, un servizio di sistema con utente dedicato, polkit e D-Bus
- octod
- octod/src/main.rs
- ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`
- 11-install-octod.sh
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `Spec: `octod` (con `octopus-proto`)` - 13 edges
2. `TentacleName` - 11 edges
3. `Spec: `octo-menu`` - 11 edges
4. `unit_info()` - 9 edges
5. `08-ram-limit.sh script` - 9 edges
6. `TentacleState` - 8 edges
7. `info()` - 7 edges
8. `confronta()` - 7 edges
9. `ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel` - 7 edges
10. `ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)` - 7 edges

## Surprising Connections (you probably didn't know these)
- `entry()` --references--> `ProtoError`  [EXTRACTED]
  octopus/octod/src/list.rs → octopus/octopus-proto/src/lib.rs
- `n()` --references--> `TentacleName`  [EXTRACTED]
  octopus/octod/src/list.rs → octopus/octopus-proto/src/lib.rs
- `unit_info()` --references--> `TentacleName`  [EXTRACTED]
  octopus/octod/src/systemd.rs → octopus/octopus-proto/src/lib.rs
- `octod` --depends_on--> `octopus-proto`  [EXTRACTED]
  octopus/octod/Cargo.toml → octopus/octopus-proto/Cargo.toml
- `unit_info()` --references--> `UnitInfo`  [EXTRACTED]
  octopus/octod/src/systemd.rs → octopus/octod/src/list.rs

## Import Cycles
- None detected.

## Communities (33 total, 10 thin omitted)

### Community 0 - "03-bench-switch.sh"
Cohesion: 0.60
Nodes (5): do_switch(), other_of(), read_count(), 03-bench-switch.sh script, start_counter()

### Community 1 - "Octopus Linux — istruzioni per l'agente"
Cohesion: 0.40
Nodes (4): Contesto e comandi utili, Octopus Linux — istruzioni per l'agente, Principi, Skill del progetto

### Community 4 - "06-vram-test.sh"
Cohesion: 0.50
Nodes (7): alloc_log(), inside(), near(), ok_of(), 06-vram-test.sh script, start_alloc(), vram()

### Community 5 - "memhog.c"
Cohesion: 0.18
Nodes (3): fill_page(), main(), ms_since()

### Community 7 - "Da fare"
Cohesion: 0.20
Nodes (9): Da fare, Decisioni prese, Fase 5 — ISO installabile (base: Debian trixie, `live-build`), Fatto, Note, Obiettivo finale (da ragionare più avanti), Obiettivo: live su chiavetta, Octopus Linux — roadmap (+1 more)

### Community 8 - "ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)"
Cohesion: 0.18
Nodes (10): ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`), Alternative considerate, Conseguenze, Contesto, Data, Decisione, SIGSTOP/SIGCONT ai processi, Solo priorità (CPUWeight/nice) senza congelare (+2 more)

### Community 9 - "ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel"
Cohesion: 0.17
Nodes (11): ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Docker / Podman, LXC/LXD (Incus) (+3 more)

### Community 10 - "ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd"
Cohesion: 0.18
Nodes (10): ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Passare la GPU a una VM, Rendering software (llvmpipe) (+2 more)

### Community 11 - "ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland"
Cohesion: 0.18
Nodes (10): ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 12 - "lib.rs"
Cohesion: 0.08
Nodes (20): ACTION_MANAGE, ACTION_SWITCH, BUS_NAME, BUSY, FAILED, INTERFACE, INVALID_NAME, MAX_NAME_LEN (+12 more)

### Community 13 - "README.md"
Cohesion: 0.08
Nodes (20): ADR-0003: Rete dei tentacoli condivisa con l'host, Alternative considerate, Bridge di rete verso la LAN, Conseguenze, Contesto, Data, Decisione, Stato (+12 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

### Community 15 - "Spec: `octo-menu`"
Cohesion: 0.07
Nodes (25): Mappa dei componenti: menù a tentacoli, Assunzioni, Comandi, Comportamento, Confini, Criteri di successo, Domande aperte, Obiettivo (+17 more)

### Community 16 - "list.rs"
Cohesion: 0.13
Nodes (13): attivo_con_memoria_e_senza_limite(), congelato_con_limite(), Entry, entry(), info(), memoria_sconosciuta_vale_zero(), n(), nomi_delle_immagini() (+5 more)

### Community 17 - "systemd.rs"
Cohesion: 0.17
Nodes (8): UnitInfo, image_names(), Machined, NO_SUCH_UNIT, Service, Systemd, Unit, unit_info()

### Community 18 - "Piano: menù a tentacoli (`octod` + `octo-menu`)"
Cohesion: 0.25
Nodes (7): Decisioni architetturali, Domande aperte, Fasi, Grafo delle dipendenze, Piano: menù a tentacoli (`octod` + `octo-menu`), Rischi, Sintesi

### Community 19 - "Task: menù a tentacoli"
Cohesion: 0.25
Nodes (7): Checkpoint A, Checkpoint B, Checkpoint C, Fase 1: prove dei rischi, Fase 2: `octod`, Fase 3: `octo-menu`, Task: menù a tentacoli

### Community 20 - "09-upgrade-test.sh"
Cohesion: 0.60
Nodes (3): fail(), inside(), 09-upgrade-test.sh script

### Community 21 - "10-polkit-spike.sh"
Cohesion: 0.56
Nodes (7): allow(), as(), deny(), fail(), ok(), sd(), 10-polkit-spike.sh script

### Community 24 - "ADR-0008: Lo switch passa da `octod`, un servizio di sistema con utente dedicato, polkit e D-Bus"
Cohesion: 0.17
Nodes (12): ADR-0008: Lo switch passa da `octod`, un servizio di sistema con utente dedicato, polkit e D-Bus, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Il menù chiama systemd direttamente, con una regola polkit per l'utente, Linguaggio: Python o C invece di Rust (+4 more)

### Community 26 - "octod/src/main.rs"
Cohesion: 0.19
Nodes (3): main(), Manager, run()

### Community 27 - "ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`"
Cohesion: 0.18
Nodes (10): ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`, Alternative considerate, Altre basi (Arch con archiso, Fedora con kiwi), Conseguenze, Contesto, Data, Decisione, Distro da zero (Linux From Scratch, buildroot) (+2 more)

### Community 28 - "11-install-octod.sh"
Cohesion: 0.47
Nodes (8): atteso(), confronta(), fail(), lista(), octo_stato(), ok(), reload_bus(), 11-install-octod.sh script

## Knowledge Gaps
- **7 isolated node(s):** `octod`, `octopus-proto`, `InvalidName`, `Active`, `Frozen` (+2 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 180 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `TentacleName` connect `list.rs` to `systemd.rs`, `lib.rs`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **What connects `octod`, `octopus-proto`, `InvalidName` to the rest of the system?**
  _7 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `lib.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.08045977011494253 - nodes in this community are weakly interconnected._
- **Why does `Entry` connect `list.rs` to `octod/src/main.rs`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Why does `ADR-0008: Lo switch passa da `octod`, un servizio di sistema con utente dedicato, polkit e D-Bus` connect `ADR-0008: Lo switch passa da `octod`, un servizio di sistema con utente dedicato, polkit e D-Bus` to `README.md`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Should `Spec: `octo-menu`` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._