# Graph Report - idea-linux  (2026-11-01)

## Corpus Check
- 29 files · ~13,119 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 4 file(s) not represented in the graph (top: .conf 2, (none) 1, .rules 1)

## Summary
- 225 nodes · 260 edges · 26 communities (19 shown, 7 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5e6a6a56`
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
- ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`
- ADR-0003: Rete dei tentacoli condivisa con l'host
- 08-ram-limit.sh
- Spec: `octo-menu`
- Spec: `octod` (con `octopus-proto`)
- ADR-0007: Menù a tentacoli come schermata a tutto schermo
- Piano: menù a tentacoli (`octod` + `octo-menu`)
- Task: menù a tentacoli
- 09-upgrade-test.sh
- 10-polkit-spike.sh
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `Spec: `octod` (con `octopus-proto`)` - 13 edges
2. `Spec: `octo-menu`` - 11 edges
3. `08-ram-limit.sh script` - 9 edges
4. `ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel` - 7 edges
5. `ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)` - 7 edges
6. `ADR-0003: Rete dei tentacoli condivisa con l'host` - 7 edges
7. `ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd` - 7 edges
8. `ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland` - 7 edges
9. `ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`` - 7 edges
10. `ADR-0007: Menù a tentacoli come schermata a tutto schermo` - 7 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (26 total, 7 thin omitted)

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
Cohesion: 0.20
Nodes (10): ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 12 - "ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`"
Cohesion: 0.18
Nodes (10): ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`, Alternative considerate, Altre basi (Arch con archiso, Fedora con kiwi), Conseguenze, Contesto, Data, Decisione, Distro da zero (Linux From Scratch, buildroot) (+2 more)

### Community 13 - "ADR-0003: Rete dei tentacoli condivisa con l'host"
Cohesion: 0.14
Nodes (10): ADR-0003: Rete dei tentacoli condivisa con l'host, Alternative considerate, Bridge di rete verso la LAN, Conseguenze, Contesto, Data, Decisione, Stato (+2 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

### Community 15 - "Spec: `octo-menu`"
Cohesion: 0.13
Nodes (12): Mappa dei componenti: menù a tentacoli, Assunzioni, Comandi, Comportamento, Confini, Criteri di successo, Domande aperte, Obiettivo (+4 more)

### Community 16 - "Spec: `octod` (con `octopus-proto`)"
Cohesion: 0.15
Nodes (13): Assunzioni, Comandi, Confini, Criteri di successo, Domande aperte, Interfaccia D-Bus (`octopus-proto`), Obiettivo, Sicurezza (`security-and-hardening`) (+5 more)

### Community 17 - "ADR-0007: Menù a tentacoli come schermata a tutto schermo"
Cohesion: 0.20
Nodes (10): ADR-0007: Menù a tentacoli come schermata a tutto schermo, Alternative considerate, Applet nella barra di COSMIC, Conseguenze, Contesto, Data, Decisione, Finestra normale (+2 more)

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

## Knowledge Gaps
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Should `ADR-0003: Rete dei tentacoli condivisa con l'host` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Spec: `octo-menu`` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._