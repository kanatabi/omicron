---
tags: [overview, omicron]
updated: 2026-11-15
---

# What is omicron?

`omicron` is the superproject of a personal blog estate — a workspace that pins
five independent git repositories (submodules) beside its own artifacts: the
infrastructure decision record, the operating runbook, and the knowledge vault
([`context-knowledge/`](INDEX.md)). GitHub is primary
([kanatabi](https://github.com/kanatabi)); GitLab `arkoi/omicron/*` trees exist
as mirrors where protection rules allow.

> **Status honesty (2026-11-15):** the estate described here is what the
> manifests DECLARE — not what is currently running. The staging and
> production hubs are **not yet applied to any cluster**; the webapp is not
> serving. What IS done: the DNS-side domain cutover (verified 2026-11-11 —
> `ainurrofiq.com` 301s in), the release ladder proven live (runbook ch.09:
> lumen v4.0.1, mellon v3.0.1, earendil v1.2.0 rode the full chain
> 2026-11-14), and the runbook chapters rehearsed on the laptop cluster.
> What remains is the walk that turns declaration into service —
> [`runbook/00a-run-order.md`](../runbook/00a-run-order.md): Argo CD →
> foundation hub → the M3 vault ritual → grafana four-key verify →
> observability hub → production + staging hubs → the first-instance checks
> (ch.06) → go-public (M5).

## The five repos

| Repo | Role | Its own docs |
| :-- | :-- | :-- |
| [earendil](https://github.com/kanatabi/earendil) | SvelteKit SSR blog frontend — declared for `gofar.id` (DNS cutover 2026-11-11; serving awaits the hub walk) | [card](repos/earendil/README.md) |
| [lumen](https://github.com/kanatabi/lumen) | Go REST backend (M1–M6 merged 2026-11-09): content API on Meilisearch + Patroni, admin API, media relay, Bao passthrough | [card](repos/lumen/README.md) |
| [mellon](https://github.com/kanatabi/mellon) | Private admin portal `console.gofar.id` — UI-only, relays to lumen, holds no credentials | [card](repos/mellon/README.md) |
| [vortex](https://github.com/kanatabi/vortex) | GitOps source of truth: Argo CD app-of-apps over K3s; everything in-cluster is declared here | [card](repos/vortex/README.md) |
| [anvil](https://github.com/kanatabi/anvil) | Release toolkit: shared scripts + composite Actions; the approval-gated release ladder | [card](repos/anvil/README.md) |

## The two workspace artifacts

- [`INFRA_ARCHITECTURE.md`](../INFRA_ARCHITECTURE.md) — the production blueprint
  and decision record (3-node K3s phases, secrets design §5, public-surface
  amendments). **Single-homed at the workspace root** since 2026-11-15 — the
  in-vortex fork was retired as stale; never re-fork it.
- [`runbook/`](../runbook/00-overview.md) — THE operating procedure
  (VPS-first, provider-neutral, milestone-ordered M0–M6). The archived
  single-node rehearsal history is the root `RUNBOOK.md` (reference, not
  procedure).

## What's public, what's never

Two sanctioned public surfaces, never a public API (INFRA §2, amended
2026-11-08; dashboard door added 2026-11-13) — **all currently DECLARED, none
serving until the hubs are applied**:

- `gofar.id` + `www.gofar.id` — earendil, content reads
- `console.gofar.id` — mellon, TLS + the GATE #10 checklist (break-glass
  port-forward remains)
- `anor.gofar.id` — the Grafana dashboard door (owner ruling 2026-11-13)

`lumen`, `meilisearch`, and OpenBao stay ClusterIP-only by design; browser→API
traffic rides the SSR/portal same-origin proxies. The API getting a public
ingress to "fix" a 404 is the estate's most classic bug.

## Where to go next

- The one-page doc doctrine: [doc-map.md](doc-map.md)
- Vocabulary: [glossary.md](glossary.md)
- The working rules you must not break: the root
  [AGENTS.md](../AGENTS.md) (workspace non-negotiables) + each repo's own
  AGENTS.md
- Architecture explainers: [architecture/system-overview.md](architecture/system-overview.md)
