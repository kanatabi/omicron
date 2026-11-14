---
tags: [architecture, network, doors, tls]
updated: 2026-11-15
---

# Network and doors — what is public, what is never

The estate's most load-bearing security property fits in one sentence:
**two sanctioned public surfaces + one dashboard door, never a public API**
(INFRA §2, amended 2026-11-08; dashboard door added 2026-11-13). This note
explains what that means in practice, how a request flows through each door,
and where the estate deliberately does NOT build doors.

## The three zones

```mermaid
flowchart TB
    subgraph z1["ZONE 1 — the public internet"]
        P["anyone"]
    end
    subgraph z2["ZONE 2 — Cloudflare guard layers"]
        CF["proxy · DNS-01 ACME · managed challenge · Access (email allowlist)"]
    end
    subgraph z3["ZONE 3 — the cluster (unrouted from the internet)"]
        T["Traefik edge<br/>(the ONLY door holder)"]
        APPS["earendil · mellon · grafana"]
        CORE["lumen (both roles) · Meilisearch · OpenBao · PostgreSQL"]
        SYS["K8s API :6443 · node SSH :22"]
    end
    subgraph z4["ZONE 4 — the admin mesh (Tailscale)"]
        LAP["the owner's laptop"]
    end
    P --> CF
    CF --> T --> APPS
    APPS --> CORE
    LAP -->|"tailnet"| APPS
    LAP -->|"tailnet"| SYS
    P -.->|"NO ROUTE — not blocked, unrouted"| CORE
    P -.->|"firewall-DENIED at the host"| SYS
```

The distinction between "blocked" and "unrouted" matters: lumen has no
Ingress object at all — there is nothing to hack through, because no door
exists. The K8s API is the harder case (it must listen), so it is
firewall-denied at the host and mesh-reached.

## The doors

| Door | Serves | Layering | State |
| :-- | :-- | :-- | :-- |
| `gofar.id` + `www.gofar.id` | earendil (content reads) | Cloudflare proxy → Traefik → SSR pods. Unauthenticated reads; writes don't exist here | **LIVE** (cutover verified 2026-11-11; `ainurrofiq.com` 301s in; www is production-only by ruling) |
| `console.gofar.id` | mellon (the owner's portal) | Cloudflare → Traefik + console middlewares (HSTS/headers/rate-limit) → mellon → relays to lumen. Service stays **ClusterIP**; only Traefik routes | Contractually live; **GATE #10** checklist gates the first public walk; `kubectl port-forward` remains break-glass |
| `anor.gofar.id` | Grafana dashboards (per-env filtered) | the ONLY door with a guest list: proxied DNS → managed challenge (whole host) → Access email allowlist → Grafana OIDC. Access IS the identity | ruling 2026-11-13 |
| `img.gofar.id` | photos | R2 bucket custom domain — never touches the server; outside ACME (bucket-side TLS) | GATE #9 closed 2026-11-13 |
| `staging.gofar.id` / `staging-console.gofar.id` | the staging world's twins | same Traefik, same ClusterIssuer | contractual; DNS + seeds land when staging first goes live |

## Why there is no API door — and how traffic reaches lumen anyway

The browser can only speak to what the edge routes. The edge routes exactly
three hostnames. lumen isn't behind any of them. So how does the blog work?

**Pattern 1 — the same-origin SSR proxy (earendil).** The browser's ONE
client-side API call (search suggest) goes to earendil itself:

```mermaid
sequenceDiagram
    autonumber
    participant B as browser
    participant E as earendil SSR pod
    participant L as lumen cms
    B->>E: GET /api/search/suggest?q=…  (SAME ORIGIN — gofar.id)
    Note over E: src/routes/api/[...path]/+server.ts<br/>the proxy: no public API ingress needed, ever
    E->>L: GET http://lumen-http-server-production.lumen.svc.cluster.local/…
    L-->>E: JSON
    E-->>B: JSON (same origin, no CORS, no exposure)
```

Every other page's data is fetched server-side during SSR (in
`+page.server.ts`), so the browser sees only rendered HTML.

**Pattern 2 — the relay with a routing table (mellon).** The portal holds no
credentials; lumen mints its session; and WHICH lumen answers each call is
one auditable table (`src/lib/api/routing.ts`):

```mermaid
flowchart LR
    M["mellon relay"] -->|"session · users · setup · bao"| A["ADMIN_URL<br/>lumen-admin (the ONE Control Plane)"]
    M -->|"content · /api"| C["CMS_URL<br/>this env's content lumen"]
    M -->|"anything else"| X["throw — NO default"]
```

The split (2026-11-13) exists so the content worlds can't mint sessions and
the Control Plane can't be reached through a cms. A failing call is fixed by
the routing table or the seeded env — **never by adding an API Ingress**;
that "fix" is the estate's most tempting bug (root AGENTS.md non-negotiable
#2).

## TLS: DNS-01 everywhere

- The zone (`gofar.id`) lives on **Cloudflare**; cert-manager solves ACME
  challenges via **DNS-01** through one shared `ClusterIssuer` — which is why
  staging rides the same issuer from any cluster (DNS-01 doesn't need the
  cluster to be publicly reachable, unlike HTTP-01).
- The self-signed rehearsal component died with the rehearsal trees.
- `console.gofar.id` must **resolve before first issuance** (same ordering
  constraint as every host: the DNS record exists before cert-manager
  tries) — and only AFTER GATE #10 clears.
- Certificates are created in-cluster and referenced — never stored in Git.

**Operate it:** runbook [`07-go-public.md`](../../runbook/07-go-public.md)
Act 1 has the CURRENT record table + procedure (the cutover walk is proven
there, 2026-11-11); runbook [`02-security.md`](../../runbook/02-security.md)
carries the ufw/host-lockdown posture.

## The admin mesh (zone 4)

The owner's laptop reaches the cluster through **Tailscale** (ruling
2026-11-13, replacing the NetBird-agent assumption: open-source client,
zero-ops hosted control plane, Headscale as a later escape hatch; NetBird
remains the answer if self-hosting the coordinator ever becomes a
requirement). Through the mesh: node SSH (port 22 closed publicly, root
login disabled once mesh SSH verified), the K8s API (dual `--tls-san` so the
cert covers both node and mesh IPs), and break-glass paths (Argo UI via
port-forward, the Grafana admin).

Node-to-node traffic (API, overlay, replication) rides the provider private
plane when available ("Path A") or the mesh ("Path B") — the full decision
matrix with its latency/MTU/staticity trade-offs is
[`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md) §2–§3.

## The mellon door's full defense, layer by layer

Because the portal is a WRITE surface, its layering is worth naming
explicitly:

```mermaid
flowchart TB
    L1["1 · Cloudflare proxy + challenge"] --> L2["2 · Traefik console middlewares:<br/>HSTS, security headers, rate-limit (30 avg / 60 burst)"]
    L2 --> L3["3 · mellon relays only — holds NO credentials"]
    L3 --> L4["4 · lumen-admin session check:<br/>HS256 JWT (12h, no refresh) + token_version live-row check"]
    L4 --> L5["5 · lumen throttle: per-IP AND per-account,<br/>exponential backoff (3 free → 1s→2s→4s… cap 15m)"]
    L5 --> L6["6 · argon2id (m=64MiB, t=3, p=2):<br/>memory-hard; wrong-password and unknown-user are ONE indistinguishable 401"]
```

Honest limits are documented, not hidden: the throttle state is per-replica
in-memory (accepted — the durable variant is a drop-in); a strict CSP is
deferred because the palette ships inline `style=` (the XSS posture therefore
assumes compromise — which is why revocation, not trust, is the load-bearing
mitigation). The full threat analysis (V1–V7, R1–R5) is archived in the
vault: [../archive/mellon-THREAT-NOTE.md](../archive/mellon-THREAT-NOTE.md) —
its owner read-through (GATE #5) is still the open item it says it is.
