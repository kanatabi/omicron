---
tags: [archive, mellon, security, secrets]
updated: 2026-11-15
---

> **Archived 2026-11-15** — removed from the
> [mellon](https://github.com/kanatabi/mellon) repo during the docs-consolidation round
> (last tracked at [mellon `b25b3bf`](https://github.com/kanatabi/mellon/blob/b25b3bf/THREAT-NOTE.md)).
> The contract this threat note grew out of is the vault's
> [secrets control plane decision record](../decisions/secrets-control-plane.md); the
> control plane it describes has since merged (lumen `846f98b`, mellon `a224950`) and
> the estate's GATE #5 final read-through stayed with the owner as recorded below.
> Content below is verbatim; repo-relative links (`mellon/PLAN.md`, the INFRA doc) are
> historical.

# THREAT-NOTE — portal sessions & the secrets plane (HUMAN-GATE #5)

> **Status: owner re-review pending.** This is the standalone detailing of the
> GATE #5 threat note prepared 2026-11-09 (journal record: `mellon/PLAN.md`
> Phase B entry). It was ack'd provisionally by the owner's merge instruction
> ("A. ack, please create a separate detailing on this. I will review it again
> later") — production seeding and the console launch (GATE #10) still wait on
> the final read-through of this document.

## 0. Scope

Everything that touches **who may act as admin**, **what credentials exist
where**, and **what a breach of each surface buys an attacker**. Three systems
are in scope: mellon (public portal UI), lumen (§8 session mint + §9 secrets
relay), OpenBao (KV v2 plane). Out of scope: infrastructure attacks on the VPS
themselves (INFRA doc), content-plane read-only abuse (earendil serves public
data only).

## 1. Assets, ranked

| #   | Asset                                          | Why it matters                                                      |
| :-- | :--------------------------------------------- | :------------------------------------------------------------------ |
| A1  | **OpenBao root / all kv secrets**              | Every app's credentials, prod included                              |
| A2  | **The admin identity itself** (session bearer) | Full write authority over published content + read of secret VALUES |
| A3  | lumen's `fzr-portal` AppRole secret-id         | The only path from lumen to Bao — a forged AppRole role             |
| A4  | Content integrity (silent post/photo edits)    | Public trust in gofar.id                                            |
| A5  | The JWT signing key                            | Mints unlimited A2 bearers                                          |

## 2. Placement — who holds what, and where it is generated

| Credential              | Lives in                                                                                                                 | Never in                                        | Minted/rotated by                                                                           |
| :---------------------- | :----------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------- | :------------------------------------------------------------------------------------------ |
| Admin password          | **only as an argon2id hash** in `users.passhash` (lumen DB)                                                              | git, env, Bao, any log                          | `cmd/userctl` (password travels via `LUMEN_PASSWORD` env, never argv)                       |
| Session JWT             | **browser cookie only** (HttpOnly, `SameSite=Strict`, `Secure` over TLS); mellon SSR reads it to relay, JS never sees it | mellon source, git, logs                        | lumen `POST /admin/session` — HS256, claims `{sub, iat, exp, tv, jti}`, 12h, **no refresh** |
| JWT signing key         | OpenBao `lumen/{env}` → ESO-rendered pod env                                                                             | git, compose (dev placeholder only)             | bootstrap-generated                                                                         |
| Bao role-id / secret-id | **lumen pod env only** (ESO, from `bao-approle-credentials`)                                                             | mellon (any layer), git, lumen logs             | §5.6 seed; AppRole TTL ≤ 1h prod (5m dev), re-login agent-side                              |
| Secret VALUES           | OpenBao KV v2                                                                                                            | **any log at any hop** (mellon, lumen, CI); git | portal CAS writes via lumen relay only                                                      |

The load-bearing sentence of the design: **the portal UI holds NOTHING** —
mellon is a relay that adds no credentials of its own; lumen is the only door
to Bao; Bao audits the truth of every access.

## 3. Vectors, mitigations, proof

### V1 — Credential stuffing on the public login (`console.gofar.id`)

The attack surface the amendment created: one known-ish username, one public URL.

- **Cost per guess:** argon2id `m=64MiB, t=3, p=2` (OWASP-side) — a GPU does not
  get bulk parallelism on memory-hard hashing.
- **Rarity of guesses:** throttle (`internal/throttle`) — per-IP **and** per-account,
  exponential (3 free, then 1s→2s→4s…, capped 15m), `Retry-After` honored.
  Edge rate-limit middleware (INFRA Phase 3) is the coarse first layer.
- **Enumeration shut:** wrong-password and unknown-user answer one indistinguishable
  401 body; 400 pre-throttle empty-credentials is a client-error class, not a
  credential event.
- **Proof:** `admin_integration_test.go` — "wrong password and unknown user are one
  indistinguishable message"; "throttle starves credential stuffing" (12 guesses →
  429); live captures in the Postman catalog (identical 401 bodies, 429 + Retry-After).
- **Residual:** throttle state is per-replica in-memory (see R1).

### V2 — Stolen session bearer (XSS, laptop compromise, cookie theft)

The honest answer, written plainly: **a live mellon session bearer IS an admin.**
It can do everything the owner can, **including reading secret VALUES** through
the §9 relay — masking is UI-only by doctrine (the editor must be able to copy
a real value; a hidden-in-DOM value is theater).

- **Window:** 12h hard expiry, no refresh tokens (re-login is the design —
  rotation machinery is not worth its own theft surface at this scale).
- **Kill switch:** `DELETE /admin/session` bumps `users.token_version`; every
  verification checks signature **AND the live row** — logout kills all
  outstanding tokens instantly, across replicas, no cache to invalidate.
- **Proof:** the battery's login→use→logout→**replay-the-same-token→401**;
  forged `alg:none` token refused at library config (`session_test.go`); the
  Postman catalog preserves the replay example.
- **Owner action on suspicion:** press logout in the console — or `userctl`
  password rotation (preserves `token_version`; explicit revocation is logout's job).

### V3 — Direct assault on Bao from outside

- lumen, Meilisearch and Bao have **no public address, ever** (INFRA §2; the
  console amendment did not touch this). Browser traffic rides same-origin
  relays; there is literally no route to the plane from a client.
- AppRole `bound_cidr_list` pins lumen's pod CIDRs **at prod seed** (dev is
  unbound — R2). Even a leaked secret-id cannot login from elsewhere.

### V4 — Compromise of lumen's own env (AppRole identity extraction)

Buying: the §9 surface **as scoped by the `fzr-portal` policy** — read/write
under `kv/` only, **no `sys/`, no enumeration beyond the mount, no admin token**.
Attack requires already owning a pod network position (same attackers who could
read the DB or the signing key — no new class).

- **Shrink:** secret-id TTL ≤ 1h prod + agent re-login; role has no `sys` rights;
  the relay's FOUR operations are the whole surface by construction (no route to
  sys/ exists in `internal/httpapi/admin_bao.go`).
- **Detect:** Bao audit devices log every relay operation (the trail of record —
  lumen logs op+path+version+key-counts, never payloads; redaction is TESTED:
  `bao_integration_test.go` captures the slog stream during reads/writes of a
  marked value and demands its absence).

### V5 — Lost-update / confused-deputy on secret writes

- CAS on every write (`cas` must equal current version; `cas: 0` is create-only;
  stale → 409, never silent clobber); `cas_required` set on the mount at bootstrap.
- Portal doctrine: no destructive path — the UI's delete affordances stop at the
  KV version list; soft-deleting a kv path is not exposed at all (versions are
  kept; purge is a root-level operator action outside the portal).

### V6 — Silent content mutation (attacker with A2 buys A4)

- All writes are `rev`-CAS-checked (no lost updates between two admin sessions);
  publish is the §2 transaction (derivations are server-owned, the attacker still
  cannot make §1 serve drafts — status is a state machine, leak rules enforced at
  the DB edge regardless of index state).
- Detection: Bao-independent — post `updated_at`/`rev` visible on the desk;
  git is not the content store, so there is no PR trail (honest gap, see R4).

### V7 — The TOFU window: the setup wizard before the owner (`POST /admin/setup/register`)

Added 2026-11-13 — the wizard shipped after this note's last revision, and the
estate's only unauthenticated **write** endpoint deserves first-class analysis.
While `users` is empty, register answers before any credentials exist. (The
rest of the pre-auth surface is the wizard's probe — `GET /admin/setup`, one
bit, nothing enumerable — and login, which writes nothing.)

- **What is atomic:** lumen wraps count+insert in one transaction under a
  `pg_advisory_xact_lock` — exactly one of N concurrent registrations wins an
  empty table; the winner's session is minted in the same response (the wizard
  IS the door), every loser gets `410 Gone`, and 410 is terminal: the wizard
  is dead forever, not "try later". The claim itself is validated (username
  shape, 10-char floor, argon2id hash) and audited (`setup.register` logs the
  new username, no credentials — the one who claimed, recorded).
- **The window:** between "cluster up with empty `users`" and "the owner's
  first visit", anyone who can reach `console.gofar.id` becomes the estate's
  first admin — and the probe tells any prober the window is open. Bounded by
  doctrine, not luck: the console is dark (no DNS, no ingress) until GATE #10,
  and lumen has no public ingress ever (V3) — the portal surface is the only
  doorway, and it opens last.
- **Residuals, named:** (a) on the VPS there is real wall-clock between the
  surface going live and a human standing in front of it; (b) a squatter-claim
  is silent-until-noticed — the owner learns someone else won only when
  `/setup` bounces to `/login`, and the audit line pays only if someone reads
  logs.
- **Mitigations, cheapest first:** RUNBOOK Part-B ordering makes the claim the
  FIRST human act after `console.gofar.id` resolves (Part A already scripts
  the bounce-then-claim as "the owner's manual act"). If a public pre-claim
  window is ever unavoidable: `BOOTSTRAP_PIN` — a one-time code seeded into
  Bao before the surface opens, which the wizard must echo — turns "whoever
  reaches it wins" into "whoever reaches it AND the seed plane wins". Not
  built; proposed only.
- **What the wizard does NOT expose — temp passwords:** the server-generated,
  once-only, never-logged temp (admin-created accounts, resets) is not on the
  wizard's path; the first admin is born from the owner's own typed password,
  `must_change=false` — nothing interceptable in flight.
- **What the wizard does NOT expose — the 428 lock:** the forced-change gate
  lives in the authenticator for every bearer (escape triad: whoami,
  change-password, logout); claiming the estate does not route around it.
- **What the wizard does NOT expose — revocation:** the claim mints an
  ordinary 12h `tv`-bearing bearer — V2's kill switch (logout, rotation)
  kills it exactly like any other token. A squatted admin is a revocable
  admin, not a permanent one.
- **Proof:** `wizard_integration_test.go` — TOFU is terminal (second register
  → 410); the 428 gate on a first login; race-proofing is structural in
  `store.InsertFirstAdmin` (one tx, one lock, one winner).
- **GATE #5 question (owner):** is the default posture — bare TOFU + Part-B
  ordering — acceptable for VPS go-live, or must `BOOTSTRAP_PIN` be built
  before the console gets its first public walk?

## 4. Residual risks (accepted, with rationale)

- **R1 — per-replica throttle.** Two lumen replicas = 2× the guess budget.
  Chosen over a Postgres-backed limiter: stateless scale honesty at blog
  traffic; the durable variant is a drop-in if the console ever earns the
  attention. Documented, not hidden.
- **R2 — dev plane divergence.** compose's AppRole is CIDR-unbound and the dev
  OpenBao has in-memory storage + a throwaway root token. Never reachable from
  outside the laptop; production seeds are the §5.6 procedure (CIDR-bound,
  audit devices ON — GATE #10 item).
- **R3 — the 12h bearer is admin-equal by design** (V2). Accepted because the
  alternative (value-blind relay responses) breaks the portal's actual job.
  Mitigated by instant revocation + re-login, not by pretense.
- **R4 — no content change-audit trail in git.** Bao audits secrets; lumen
  logs operations (`session.grant/deny/revoke`, `bao.*`); post writes carry
  timestamps + rev but no per-field history. If this ever matters, an
  `post_revisions` table is the known answer — deliberately not built yet.
- **R5 — strict CSP deferred** (mellon): inline `style=` hue attributes are how
  the wayfinding ships today; a tight `style-src` breaks it. The palette +
  masked-value UI never interpolates user content into markup; XSS is treated
  as _possible_, which is exactly why V2's mitigation is revocation, not trust.

## 5. What finalizing this gate means

The owner's final read-through of this document is what unblocks (in order):

1. **Prod seeding** — §5.6 Bao seed (incl. `SESSION_JWT_SECRET`, media keys,
   `bao-approle-credentials`) and ESO wiring; nothing may go in-cluster before.
2. **GATE #10 run** — the console pre-launch checklist (edge middlewares,
   throttle + argon2id live, `tv`-revocation proven end-to-end through the
   portal, `Secure` cookie over TLS, Bao audit devices ON).
3. Any line in this note the owner rejects is a **design change**, not a
   footnote — V2/R3 are the load-bearing ones.

## 6. Evidence index

| Claim                                           | Where it is proven                                                    |
| :---------------------------------------------- | :-------------------------------------------------------------------- |
| alg:none / garbage / expired tokens refused     | `lumen/internal/session/session_test.go`                              |
| tv revocation kills live tokens (over-the-wire) | `admin_integration_test.go` + live battery run 2×                     |
| one indistinguishable auth-failure body         | same test, response-equality assert                                   |
| throttle engages with Retry-After               | same suite + Postman catalog 429 capture                              |
| values never in lumen logs                      | `bao_integration_test.go` slog-capture redaction proof                |
| CAS conflicts are 409, never clobbers           | same test + driftcheck walks on OpenBao                               |
| relay surface = 4 operations, no sys/           | `internal/httpapi/admin_bao.go` (mount table) + §9 contract           |
| drafts never on §1 surfaces                     | earendil `contract.spec.ts` (13/13 live) + Postman leak examples      |
| TOFU register: one winner, 410 ever after       | `wizard_integration_test.go` + `store.InsertFirstAdmin` advisory lock |
| dev plane == prod product                       | compose `ghcr.io/openbao/openbao:2.5.3` + battery re-run `938ce69`    |
