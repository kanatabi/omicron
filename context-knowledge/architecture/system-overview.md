---
tags: [architecture, overview]
updated: 2026-11-15
---

# System overview — the estate end-to-end

This is the one page to read before any other. It answers: what is this
thing, who talks to whom, and where does a request actually go? Everything
here is explained in depth by the sibling notes in this folder; each section
links to its deep-dive.

## The system in one paragraph

A personal blog (the pen-name **`gofar;`**, legal identity **Faiz Ainur
Rofiq**) published at **`gofar.id`**, plus the private tooling that operates
it. The blog is a SvelteKit server-rendered frontend (**earendil**) backed by
a Go API (**lumen**) with search on Meilisearch and storage on PostgreSQL
(Patroni). The owner writes and administers through **mellon**, a private
portal at `console.gofar.id` that holds no credentials of its own — it
relays to lumen. Everything running in the cluster is declared as YAML in
**vortex** and applied by Argo CD (GitOps). Releases ship through **anvil**,
an approval-gated ladder where a human click is always the deploy decision.
Secrets live in **OpenBao** inside the cluster; Git never holds a value. The
whole estate runs on **one small VPS (~$12/month)** today, with a 3-node
shape declared as the scale-out blueprint.

## The big picture

```mermaid
flowchart TB
    subgraph internet["The internet"]
        V["Visitors"]
        O["The owner"]
    end

    subgraph cf["Cloudflare (DNS + proxy + Access)"]
        CF["gofar.id · www · console · anor · img"]
    end

    subgraph vps["One VPS — K3s cluster"]
        subgraph edge["edge (Traefik + cert-manager)"]
            T["Traefik Ingress<br/>TLS via DNS-01"]
        end

        subgraph appns["app namespace (lumen / earendil / mellon)"]
            EAR["earendil SSR ×2<br/>:3000"]
            MEL["mellon portal ×1<br/>:3000"]
            LUMC["lumen cms http ×2<br/>(role=cms)"]
            LUMA["lumen-admin ×1<br/>(role=admin, Control Plane)"]
        end

        subgraph data["data plane"]
            PG["Patroni PostgreSQL<br/>3 logical DBs"]
            MEI["Meilisearch<br/>per-env indexes"]
        end

        subgraph values["values plane"]
            BAO["OpenBao (KV v2)"]
            ESO["External Secrets Operator"]
        end

        subgraph eyes["observability"]
            GRAF["Grafana (anor.gofar.id)"]
            VM["VictoriaMetrics"]
            LOKI["Loki (7d)"]
            ALLOY["Alloy DaemonSet"]
        end

        ARGO["Argo CD<br/>(self-hosted, GitOps)"]
    end

    subgraph r2["Cloudflare R2"]
        IMG["img.gofar.id<br/>(photos)"]
        BAK["backups (restic)"]
    end

    subgraph git["GitHub — kanatabi org"]
        VORTEX["vortex (manifests)"]
        APPS["lumen · earendil · mellon"]
        ANVIL["anvil (release tooling)"]
    end

    V -->|"HTTPS"| CF --> T
    O -->|"HTTPS + Access"| CF
    T --> EAR
    T --> MEL
    T -->|"anor.gofar.id"| GRAF
    EAR -->|"same-origin /api/* proxy"| LUMC
    MEL -->|"ADMIN_URL"| LUMA
    MEL -->|"CMS_URL"| LUMC
    LUMA --> PG
    LUMC --> PG
    LUMC --> MEI
    LUMA -->|"AppRole relay"| BAO
    ESO -->|"render values"| BAO
    ESO -->|"envFrom"| EAR
    ESO -->|"envFrom"| LUMC
    ALLOY --> VM
    ALLOY --> LOKI
    GRAF --> VM
    GRAF --> LOKI
    LUMC -->|"media relay"| IMG
    ARGO -->|"apply manifests"| T
    APPS -->|"bump PR (anvil)"| VORTEX
    ANVIL -->|"release ladder"| APPS
```

## The five repos (and why they're separate)

Each repo is independently versioned and released — a blog bug fix should
never force a manifests change, and vice versa.

| Repo | One job | Language / shape | Released via |
| :-- | :-- | :-- | :-- |
| [earendil](https://github.com/kanatabi/earendil) | render the blog | SvelteKit 3 (Svelte 5 runes) + `adapter-node` container | anvil ladder |
| [lumen](https://github.com/kanatabi/lumen) | the only backend | Go (chi), layered handlers→services→store | anvil ladder |
| [mellon](https://github.com/kanatabi/mellon) | the owner's control surface | SvelteKit 3, UI-only relay | anvil ladder |
| [vortex](https://github.com/kanatabi/vortex) | declare the cluster | YAML (Kustomize + Argo CD) | commits = syncs |
| [anvil](https://github.com/kanatabi/anvil) | the release ladder | shell scripts + composite Actions | pinned by SHA |

The superproject [omicron](https://github.com/kanatabi/omicron) pins all five
as git submodules and owns the blueprint
([`INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md)), the operating
procedure ([`runbook/`](../../runbook/00-overview.md)), and this vault.

## The three planes

The runbook (ch.00) teaches the system as three planes — hold onto this
model:

1. **Content plane** — what readers see: earendil ← cms lumen ←
   PostgreSQL/Meilisearch. Per environment (staging / production).
2. **Control plane** — what the owner uses: mellon → `lumen-admin` (ONE,
   unsuffixed, foundation-owned) → sessions, users, the TOFU wizard, and the
   Bao relay. Also Argo CD and the release ladder.
3. **Values plane** — OpenBao + ESO: where every credential and config value
   lives and how it reaches pods. Foundation-owned, shared.

## Walkthrough: a reader opens a post

```mermaid
sequenceDiagram
    autonumber
    participant V as Visitor's browser
    participant CF as Cloudflare
    participant T as Traefik (edge)
    participant E as earendil SSR pod
    participant L as lumen cms pod
    participant M as Meilisearch
    participant P as PostgreSQL (Patroni)

    V->>CF: GET gofar.id/posts/some-slug
    CF->>T: proxied request (managed TLS)
    T->>E: route → earendil :3000
    E->>L: GET /v1/posts/some-slug (internal service DNS)
    L->>P: prepared SELECT (rev-checked)
    L->>M: search-index read only for search routes
    L-->>E: post JSON (already derived: readTime, tags, order)
    E-->>V: rendered HTML (Shiki code, TOC, diagram placeholders)
    Note over V: mermaid diagrams render CLIENT-side (Route B)<br/>search suggest is the ONLY browser→API call
```

The load-bearing rules visible here: the browser never reaches lumen (there
is no route — see [network-and-doors.md](network-and-doors.md)); the FE
renders payloads as-is (ordering/derivation happens BE-side, at publish
time); and the API has no public ingress, ever.

## Walkthrough: the owner publishes a post

```mermaid
sequenceDiagram
    autonumber
    participant O as Owner (browser)
    participant M as mellon
    participant A as lumen-admin
    participant C as lumen cms
    participant DB as PostgreSQL

    O->>M: edit + Ctrl+Enter (save & publish)
    M->>A: PUT /admin/posts/… (session cookie relays)
    A->>A: publish unit of work — PURE derivations<br/>(readTime, excerpt, status transitions)
    A->>DB: one transaction (rev-CAS check inside)
    A->>C: introspection: the cms plane validates its view (≤30s cache)
    C-->>A: ack (unreachable → 503 fail-closed)
    A-->>M: 200 + the desk re-renders
    M-->>O: published — earendil serves it on next SSR fetch
```

Why two lumen planes? The role split (2026-11-13): the **admin** plane is
ONE instance holding sessions/users/TOFU/Bao; **cms** instances exist per
environment and hold content only. A cms can serve `gofar.id` without ever
being able to mint a session.

## Walkthrough: the owner edits a secret value

```mermaid
sequenceDiagram
    autonumber
    participant O as Owner (mellon /secrets)
    participant M as mellon
    participant A as lumen-admin
    participant B as OpenBao

    O->>M: save env bundle (CAS)
    M->>A: PUT /admin/bao/{app}/{env}?cas=N (relay — mellon holds no tokens)
    A->>B: CAS write with the AppRole (fzr-portal)
    A->>A: key-set MIRROR: diff key set vs previous head,<br/>apply shape to sibling envs (adds empty, removes propagate)
    B-->>A: new version vN+1 (history kept)
    A-->>M: rendered copy verbatim (ghost-field: never decorated)
    M-->>O: saved — next ESO refresh drift-pulls it
```

The full frozen contract (apps-are-data, the mirror, pins-as-locks) is the
[secrets control plane decision record](../decisions/secrets-control-plane.md);
the values-plane mechanics are [secrets-and-vault.md](secrets-and-vault.md).

## How changes reach the cluster (the 30-second version)

```mermaid
flowchart LR
    A["merge to main<br/>(gates only)"] --> B["THREE waiting bump jobs<br/>release-patch · minor · major"]
    B --> C{"human approves ONE<br/>(the release decision)"}
    C --> D["tag vX.Y.Z pushed<br/>via RELEASE_BOT_PAT"]
    D --> E["image built + pushed<br/>deploy-plan = evidence"]
    E --> F["deploy-staging card<br/→ bump PR"]
    F --> G["deploy-production card<br/>→ bump PR (the ladder order)"]
    G --> H["Argo syncs<br/>(prune + selfHeal)"]
```

Deep dive: [releases-and-ci.md](releases-and-ci.md). **Operate it:**
runbook [`09-releases.md`](../../runbook/09-releases.md).

## Where to go next

| You want to… | Read |
| :-- | :-- |
| understand how Git becomes cluster state | [gitops.md](gitops.md) |
| understand staging vs production vs foundation | [environments-model.md](environments-model.md) |
| know what's public and what's never | [network-and-doors.md](network-and-doors.md) |
| follow a secret from Bao to a pod | [secrets-and-vault.md](secrets-and-vault.md) |
| know how the estate is watched | [observability.md](observability.md) |
| ship a release | [releases-and-ci.md](releases-and-ci.md) |
| run the whole thing from zero | runbook [`00a-run-order.md`](../../runbook/00a-run-order.md) (the execution map) |
| learn the vocabulary | [glossary.md](../glossary.md) |
