# Graph Report - idea-linux  (2026-10-31)

## Corpus Check
- 4 files · ~906 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1 file(s) not represented in the graph (top: (none) 1)

## Summary
- 17 nodes · 20 edges · 5 communities (0 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- 01-create-tentacles.sh
- 00-setup.sh
- 02-test-freeze.sh

## God Nodes (most connected - your core abstractions)
1. `01-create-tentacles.sh script` - 2 edges
2. `write_nspawn()` - 2 edges
3. `00-setup.sh script` - 1 edges
4. `02-test-freeze.sh script` - 1 edges

## Surprising Connections (you probably didn't know these)
- `octo script` --calls--> `cg()`  [EXTRACTED]
  prototype/octo → prototype/octo  _Bridges community 46 → community 0_

## Import Cycles
- None detected.

## Communities (5 total, 5 thin omitted)

## Knowledge Gaps
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges._