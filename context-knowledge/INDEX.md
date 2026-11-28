---
tags: [index, vault]
updated: 2026-11-29
---

# context-knowledge — the omicron vault

Cross-repo knowledge for the [omicron](https://github.com/kanatabi/omicron)
estate: synthesis the per-repo docs can't hold (they're each cloned standalone),
decision records, and the walked-lessons ledger.

## How this vault relates to the repos (the DRY line)

- The repos own their depth: each repo's `AGENTS.md` / `DESIGN.md` / `README.md`
  is the authority for itself (see [doc-map.md](doc-map.md)).
- The vault owns what spans repos: estate-level explainers
  ([architecture/](architecture/README.md)), decision records
  ([decisions/](decisions/README.md)), the per-repo cards
  ([repos/](repos/omicron/README.md)) and lesson ledgers
  (`repos/<name>/LEARNING.md`), plus [archives](archive/earendil-ARCHITECTURE.md)
  of superseded docs.
- The vault never becomes a second home for a repo doc. When a repo doc dies,
  it is **archived** here verbatim behind a provenance header — not maintained.

## Map

| Path | What |
| :-- | :-- |
| [what-is-omicron.md](what-is-omicron.md) | the estate in one page |
| [doc-map.md](doc-map.md) | which doc lives where, and the README/AGENTS/DESIGN/PLAN tier doctrine |
| [glossary.md](glossary.md) | the estate's vocabulary |
| [decisions/](decisions/README.md) | tracked decision records (the binding-contract kind) |
| [architecture/](architecture/README.md) | detailed system explainers, one concern each (mermaid throughout, runbook pointers) |
| [repos/](repos/omicron/README.md) | detailed learning notes + lesson ledgers — learn a repo from here alone; extra focused files (API surfaces, subsystem walkthroughs) as sections outgrow their note |
| [apps/](apps/finance/README.md) | app-level PRDs, tech specs and plans for features spanning repos (finance first; the binding ADR lives in decisions/) |
| [archive/](archive/earendil-ARCHITECTURE.md) | verbatim snapshots of removed docs, provenance headers on |

## Conventions

- **Relative links only** inside the vault (no `[[wikilinks]]`) — the tree must
  survive plain-filesystem, GitHub, and Obsidian readers alike.
- **Minimal frontmatter**: `tags` + `updated` only.
- **Every claim keeps its walked date.** A rule without a date can't be
  re-verified; dates turn claims into a ledger.
- **Diagrams are mermaid fenced blocks** (```` ```mermaid ````) — GitHub,
  Obsidian, and the blog itself render them natively; no images.
- **Cross-repo links are absolute GitHub URLs** (submodules clone standalone —
  a relative link out of the vault's repo cannot resolve there); links INTO
  this repo (root docs, runbook, vault) stay relative.
