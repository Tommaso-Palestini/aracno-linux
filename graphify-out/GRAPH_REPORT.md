# Graph Report - idea-linux  (2026-10-31)

## Corpus Check
- 12 files · ~3,939 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1 file(s) not represented in the graph (top: (none) 1)

## Summary
- 64 nodes · 71 edges · 12 communities (4 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f95e57ea`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- 03-bench-switch.sh
- Octopus Linux — istruzioni per l'agente
- 04-gpu-bind.sh
- 05-gpu-driver.sh
- 06-vram-test.sh
- 07-wayland-bind.sh
- Da fare
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `06-vram-test.sh script` - 6 edges
2. `Octopus Linux — roadmap` - 5 edges
3. `Da fare` - 5 edges
4. `do_switch()` - 4 edges
5. `Octopus Linux — istruzioni per l'agente` - 4 edges
6. `03-bench-switch.sh script` - 3 edges
7. `alloc_log()` - 3 edges
8. `ok_of()` - 3 edges
9. `start_alloc()` - 3 edges
10. `01-create-tentacles.sh script` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (12 total, 8 thin omitted)

### Community 0 - "03-bench-switch.sh"
Cohesion: 0.60
Nodes (5): do_switch(), other_of(), read_count(), 03-bench-switch.sh script, start_counter()

### Community 1 - "Octopus Linux — istruzioni per l'agente"
Cohesion: 0.40
Nodes (4): Contesto e comandi utili, Octopus Linux — istruzioni per l'agente, Principi, Skill del progetto

### Community 4 - "06-vram-test.sh"
Cohesion: 0.50
Nodes (7): alloc_log(), inside(), near(), ok_of(), 06-vram-test.sh script, start_alloc(), vram()

### Community 7 - "Da fare"
Cohesion: 0.20
Nodes (9): Da fare, Decisioni prese, Fase 5 — ISO installabile (base: Debian trixie, `live-build`), Fatto, Note, Obiettivo finale (da ragionare più avanti), Obiettivo: live su chiavetta, Octopus Linux — roadmap (+1 more)

## Knowledge Gaps
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges._