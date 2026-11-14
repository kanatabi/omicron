---
tags: [earendil, frontend]
updated: 2026-11-15
---

# earendil — the blog frontend

SvelteKit 3 (Svelte 5 runes) SSR blog served via `adapter-node` on K3s — the
public face at `gofar.id` + `www.gofar.id` (cutover verified live 2026-11-11;
`ainurrofiq.com` 301s in). Brand wordmark: `gofar;`.

## Its own docs (authoritative for this repo)

- [AGENTS.md](https://github.com/kanatabi/earendil/blob/main/AGENTS.md) —
  working guide: load-bearing conventions, the diagram subsystem (Route B),
  test map, manual QA recipes, ten hard-won lessons.
- [DESIGN.md](https://github.com/kanatabi/earendil/blob/main/DESIGN.md) —
  living spec: stack, routes, theming, the §4 API contract, markdown pipeline,
  deployment.
- [README.md](https://github.com/kanatabi/earendil/blob/main/README.md) —
  routes + how to run.
- `PLAN.md` — **local-only** (owner journal, gitignored since 2026-11-15).

## Estate facts an outsider needs

- The §4 contract (`src/lib/api/client.ts`) is the FE/BE source of truth —
  mirrored by `lumen/DESIGN.md` §1; coordinated changes move both.
- Runtime always fetches lumen (real-first, 2026-11-09); the fixture twin is
  test-only. Search suggest is the ONLY client-side API call; everything else
  rides the same-origin `/api/*` SSR proxy.
- Diagrams: BE ships raw fences, FE renders client-side (Route B).
- The superseded single-node ARCHITECTURE draft lives in this vault:
  [../archive/earendil-ARCHITECTURE.md](../archive/earendil-ARCHITECTURE.md).

Lesson ledger: [LEARNING.md](LEARNING.md).
