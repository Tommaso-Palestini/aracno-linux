# Graph Report - idea-linux  (2026-11-01)

## Corpus Check
- 21 files · ~7,673 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1 file(s) not represented in the graph (top: (none) 1)

## Summary
- 154 nodes · 176 edges · 19 communities (12 shown, 7 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e0a91464`
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
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `08-ram-limit.sh script` - 9 edges
2. `ADR-0001: Tentacoli come container systemd-nspawn su un unico kernel` - 7 edges
3. `ADR-0002: Switch con il freezer dei cgroup (`systemctl freeze`)` - 7 edges
4. `ADR-0003: Rete dei tentacoli condivisa con l'host` - 7 edges
5. `ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd` - 7 edges
6. `ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland` - 7 edges
7. `ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`` - 7 edges
8. `06-vram-test.sh script` - 6 edges
9. `Octopus Linux — roadmap` - 5 edges
10. `Da fare` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (19 total, 7 thin omitted)

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
Cohesion: 0.20
Nodes (10): ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Passare la GPU a una VM, Rendering software (llvmpipe) (+2 more)

### Community 11 - "ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland"
Cohesion: 0.18
Nodes (10): ADR-0005: Desktop: nei tentacoli si monta solo il socket Wayland, Alternative considerate, Conseguenze, Contesto, Data, Decisione, Montare l'intera `/run/user/UID`, Stato (+2 more)

### Community 12 - "ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`"
Cohesion: 0.18
Nodes (10): ADR-0006: Host dell'ISO: Debian trixie costruita con `live-build`, Alternative considerate, Altre basi (Arch con archiso, Fedora con kiwi), Conseguenze, Contesto, Data, Decisione, Distro da zero (Linux From Scratch, buildroot) (+2 more)

### Community 13 - "ADR-0003: Rete dei tentacoli condivisa con l'host"
Cohesion: 0.15
Nodes (10): ADR-0003: Rete dei tentacoli condivisa con l'host, Alternative considerate, Bridge di rete verso la LAN, Conseguenze, Contesto, Data, Decisione, Stato (+2 more)

### Community 14 - "08-ram-limit.sh"
Cohesion: 0.27
Nodes (12): avail(), cleanup(), cur(), fail(), inside(), mb(), ooms(), 08-ram-limit.sh script (+4 more)

## Knowledge Gaps
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd` connect `ADR-0004: GPU nei tentacoli con bind di `/dev/dri` e drop-in systemd` to `ADR-0003: Rete dei tentacoli condivisa con l'host`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._