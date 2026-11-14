---
tags: [mellon, portal]
updated: 2026-11-15
---

# mellon — the private admin portal

One keyboard-first web app (SvelteKit 3 + Svelte 5) for content management and
env/secret management — talking ONLY to lumen. Public at `console.gofar.id`
(TLS at the shared edge; go-live is HUMAN-GATE #10); the service itself stays
ClusterIP, port-forward is break-glass.

## Its own docs (authoritative for this repo)

- [DESIGN.md](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) — **§2
  doctrine is load-bearing** (UI-only, no credentials,
  relay-forwards-never-decides), §6 routes incl. the secrets control plane,
  §8/§9 wire contracts, §11 shell.
- [AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md) — new
  2026-11-15: doctrine pointer, dual upstreams (`ADMIN_URL`/`CMS_URL` routing
  table), ghost-field rule, commands.
- [README.md](https://github.com/kanatabi/mellon/blob/main/README.md) —
  refreshed 2026-11-15: how to run, dev login.
- `PLAN.md` — **local-only** (owner journal, gitignored since 2026-11-15).

## Estate facts an outsider needs

- Holds NO credentials in any layer, any era — the portal is a relay.
- The §6.1 secrets surface implements the frozen
  [secrets-control-plane.md](../decisions/secrets-control-plane.md) contract
  (cockpit, compare, estate matrix; pin-as-lock renders lumen's 403 verbatim).
- The superseded THREAT-NOTE (GATE #5 detailing) lives in this vault:
  [../archive/mellon-THREAT-NOTE.md](../archive/mellon-THREAT-NOTE.md).

Lesson ledger: [LEARNING.md](LEARNING.md).
