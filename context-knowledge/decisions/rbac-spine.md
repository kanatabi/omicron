---
tags: [decisions, rbac, auth, lumen, mellon]
updated: 2026-11-27
---

# DECISION — the RBAC spine: scopes replace roles, lumen stays the identity authority

**Status: ACCEPTED** (landed 2026-11-24 — lumen `152629e` + `eb6e607`, mellon
`f9d0c53` + `60b9d48`). Supersedes the user-role descriptions in lumen §8/§9
and mellon §2; the process planes (`LUMEN_ROLE`) are NOT this decision.

> **Audience note:** written for coding agents — every ruling is pinned, do
> not re-derive; where older docs disagree, this record wins.

## 0. Pinned owner rulings (do not reopen)

| # | Ruling | Date |
| :-- | :-- | :-- |
| R1 | mellon becomes the center of command for personal/family apps (budgeting, …). Apps are MODULAR: an app's BE is a separate service; mellon serves its UI and relays to it. | 2026-11-23 |
| R2 | Keep lumen THIN: identity + authorization authority only. No app domain logic, no app traffic proxying. | 2026-11-23 |
| R3 | Apps verify the token sent to them and enforce their own scopes — 401 (unverifiable) / 403 (verified, scope missing). No lumen gateway-proxy, no dedicated proxy service. | 2026-11-23 |
| R4 | App data: per-app DATABASES inside the current Patroni instance; designed so separation later is a dump-and-restore. | 2026-11-24 |
| R5 | USER roles are deprecated and dropped; user creation grants exact scopes. (`LUMEN_ROLE` process planes are UNTOUCHED deployment topology.) | 2026-11-24 |
| R6 | Scope catalog is DB data, managed via the portal (users:manage-gated) — onboarding a scope never means manual SQL. | 2026-11-24 |
| R7 | Scopes ride the session token as a claim at mint; any scope mutation BUMPS token_version (immediate demotion; the 12h TTL staleness never applies to a demotion). | 2026-11-24 |
| R8 | Verification stays INTROSPECTION-FIRST (the cms plane's existing `internal/authz` pattern, generalized). JWKS/asymmetric signing is the recorded later optimization for an app that wants zero-hop local verification — not this round. | 2026-11-24 |
| R9 | OAuth (GitHub/Google) linking: design-open extension point, NOT this round. Source of truth stays the internal user DB; a provider identity would be an additional credential (explicit linking only; TOFU and must_change gates hold). | 2026-11-24 |
| R10 | MVP of RBAC = the CURRENT content + admin planes (the proving ground). App namespaces (e.g. `budget:*`) are catalog EXAMPLES until an app ships. | 2026-11-24 |

---

## 1. Context (the estate today — what an agent must know before touching anything)

- Two-service estate: **mellon** (SvelteKit SSR portal, UI-only doctrine — it
  relays, never decides, holds no secrets) and **lumen** (Go, the backend).
- lumen already runs a **process-role split**: ONE binary, `LUMEN_ROLE=admin|cms`.
  - admin plane (lumen-admin): owns the `users` table, the session MINT, the
    verify door, the Bao relay.
  - cms plane (lumen-{staging,production}): content desks + public reads; NO
    users table — auth is INTROSPECTED from the admin plane via
    `internal/authz` (POST /admin/session/verify, ~30s positive cache keyed on
    the token's SHA-256, FAIL CLOSED on admin-plane unreachability).
  - **This is the pattern the spine generalizes**: the cms plane is already the
    first scope-separated client. Round 1 extends an existing seam; it does not
    invent one.
- `users` table (migration 0002/0007): `username TEXT PRIMARY KEY, passhash,
  token_version INT, role TEXT ('admin'|'editor'), must_change BOOL, created_at`.
  **No id column exists.** The session JWT (HS256, pinned, 12h TTL) carries
  `{sub, iat, exp, tv, jti}` — `tv` is users.token_version, verified live.
- mellon's types are the contract: wire changes to whoami/users MUST land in
  the same round as mellon's adoption (no broken intermediate wire).
- User WIP that agents MUST NOT touch: `lumen/internal/service/service.go`,
  `mellon/Makefile`.

## 2. Decisions

### D1 — Scopes replace user roles (R5)
- New table `scopes` (the catalog — DB data, portal-managed per R6):
  ```sql
  CREATE TABLE scopes (
      scope       TEXT PRIMARY KEY,   -- 'content:manage' — natural key, immutable
      description TEXT NOT NULL,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ```
- New table `user_scopes` (normalized — owner asked; agent analysis: FK
  integrity, no-dup grants by PK, indexable "who has X", one-DELETE revocations):
  ```sql
  CREATE TABLE user_scopes (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      scope   TEXT NOT NULL REFERENCES scopes(scope) ON DELETE CASCADE,
      PRIMARY KEY (user_id, scope)
  );
  ```
- Grammar: `<domain>:<verb>`, lowercase, `:` separator. Verbs stay COARSE
  (`manage`/`read`/`write`/`admin`); splitting (e.g. `content:publish`) is pure
  catalog data later — grammar and storage do not move.

### D2 — `users.id` surrogate key (owner call 2026-11-24)
```sql
ALTER TABLE users ADD COLUMN id UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE users ALTER COLUMN id SET NOT NULL;
ALTER TABLE users DROP CONSTRAINT users_pkey;
ALTER TABLE users ADD PRIMARY KEY (id);
ALTER TABLE users ADD CONSTRAINT users_username_key UNIQUE (username);
```
- Login/mint/auth lookups KEEP keying on username (the human handle, still
  unique). Every relational reference (user_scopes, future provider columns,
  future app tables) keys on `id`. `whoami`/users API expose `id`.

### D3 — Initial catalog (seeded by the migration; portal-managed after)
| scope | description | gates |
| :-- | :-- | :-- |
| `content:manage` | the content desks: posts, photos, tags, collections, media | cms desks (create/edit/delete/upload) |
| `secrets:admin` | the whole Bao cockpit: values, pins, app onboarding, estate matrix | admin bao routes |
| `users:manage` | user creation, scope assignment + the scope catalog, password resets | admin users routes + scope catalog routes |
| `settings:manage` | portal-level settings (reserved; gated when settings grow) | (none yet) |
- Migration grants: `role='admin'` → all four; `role='editor'` → `content:manage`.
  Then `users.role` is DROPPED. TOFU (`InsertUser`) grants the full set.
- Self-service routes (whoami, change-password, **profile**) require
  AUTHENTICATION only — no scope. The profile is the caller's own display
  name + private email (`GET/PATCH /admin/profile`); username remains the
  immutable login handle. Public `/api/*` + media stay ANONYMOUS.

> **Amended 2026-11-27 (tasks/notifications round):** the catalog is now
> **SEVEN** — `0014_tasks.sql` seeds `tasks:create|update|manage` next to
> the original four. The trio gates the admin-plane tasks workspace (reads
> and invite acceptance need ANY of the three); project MEMBERSHIP and role
> are the second key, enforced inside every query. No migration grants them:
> they appear in the portal catalog and an admin grants them through
> `users:manage` — the D3 "role=admin → all" rule was the one-time cutover,
> not a standing auto-grant. `scopes.Seed` is the single source the catalog
> goldens derive from.

### D4 — Scopes in the token, tv-bump on mutation (R7)
- `session.Claims` gains `Scopes []string \`json:"scopes"\``.
- `MintSession(secret, username, tv, scopes)`.
- **Every scope mutation (grant/revoke) bumps `users.token_version`** — the
  existing revocation lever — so outstanding tokens fail the tv check
  immediately. Consequence: claim and DB can never disagree at verification
  time. A scope change logs the user's OTHER sessions out (re-login) —
  accepted at personal scale (password resets already behave this way).

### D5 — Introspection-first verification (R8)
- `/admin/session/verify` response gains `scopes` (the authoritative set read
  at verify time). The cms-side `internal/authz` client + its verdict struct
  and 30s cache carry scopes through unchanged semantics (positives cached,
  denials fresh, fail closed).
- App-BE contract (documented in the new decision record + `internal/authz`'s
  doc comment): an app authenticates a request by introspecting against the
  verify door — cache positives ≤30s keyed by token SHA-256, re-ask denials
  immediately, fail closed — then checks its own route's required scope
  against the returned scopes. lumen never learns what an app's scopes MEAN.
- Deferred (recorded): JWKS/asymmetric local verification; per-provider OAuth
  columns.

### D6 — Enforcement matrix (lumen routes; agent: implement exactly this)
| Route class | Plane | Requirement |
| :-- | :-- | :-- |
| `POST /admin/setup*` (TOFU) | admin | none (the unclaimed-estate gate stays) |
| `POST /admin/session` (login), `GET /admin/session` (whoami), `POST /admin/session/password` | admin | authentication only (self-service) |
| `POST /admin/session/verify` | admin | authentication only (the introspection door) |
| `/admin/users*` (list/create/reset/scopes), `/admin/scopes*` (catalog CRUD) | admin | `users:manage` |
| `/admin/bao*` (paths/read/write/pins/apps/envs/summary) | admin | `secrets:admin` |
| cms desks: `/admin/posts*`, `/admin/photos*`, `/admin/tags*`, `/admin/collections*` | cms | `content:manage` |
| cms public `/api/*`, media serving | cms | anonymous (unchanged) |
- The plane matrix (`internal/role` Planes) is UNTOUCHED — planes classify
  deployment topology, scopes classify permission. Both apply.
- mellon renders scopes as AFFORDANCES (nav/pages) — it never enforces.

### D7 — mellon surface (same coordinated round)
- `whoami` principal gains `scopes: string[]` + `id: string`.
- Users page: creation = scope picker (checkboxes grouped by namespace,
  from the catalog); existing users = a scope editor; the role column/pills
  die. A "Scopes" management surface (catalog list/add/delete-unused),
  users:manage-gated server-side AND rendered only for holders.
- Nav/pages filter by `principal.scopes` — affordance rendering.
- The wire flips atomically (no role-shaped compat shim).

## 3. Task breakdown

Working rules for every task (estate-wide, non-negotiable):
- Branch off `main` → squash-merge (ONE conventional commit), never
  fast-forward/rebase; push after landing.
- Gates STANDALONE, never piped/tailed — read full output (the CI lint
  incident 2026-11-24: `| tail -1` hid failures).
- Never touch: `lumen/internal/service/service.go` (WIP), `mellon/Makefile` (WIP).
- Vault sync in the same round (`context-knowledge/repos/<name>/README.md` +
  `LEARNING.md`), and the ADR migration to `context-knowledge/decisions/`.
- lumen offline gate: `LUMEN_BAO_ADDR= LUMEN_INTEGRATION= go test ./...`
  (known env-only failures: TestBaoRelay/TestEstateSummary/TestRoleSplit).
  lumen integration (when needed): `make test-integration`. mellon gates:
  `npm run lint && npm run check && npm run test:unit && npm run build`.

### L — lumen (the spine)
- **L1 `internal/scopes`**: catalog helpers — validate scope strings
  (`^[a-z]+:[a-z]+$`), `FullSet`, `ContentBundle`, list-from-DB, seed list.
  Unit test: validation + bundles.
- **L2 migration** (`internal/store/migrations/00XX_rbac_scopes.sql`, one tx):
  users.id + PK/UNIQUE swap (D2 SQL), scopes + user_scopes tables, seed the
  four scopes, grants from role, DROP COLUMN role. Update the migrate
  manifest test if it classifies files. Verify: fresh admin/all DB AND an
  already-migrated admin DB both land clean (the 0002 IF-NOT-EXISTS era).
- **L3 `internal/store/users.go`**: `AuthUser`/lookups join scopes (via id);
  `SetScopes(userID, scopes)` (catalog-validated, bumps token_version,
  returns the new tv); `InsertUser(username, passhash, scopes, mustChange)`;
  `ListUsers` carries scopes; remove role from all queries.
- **L4 `internal/session`**: `Claims.Scopes`; `MintSession(secret, username,
  tv, scopes)`; update all mint call sites (TOFU, login, reset).
- **L5 verify door + authz**: admin verify handler returns scopes;
  `internal/authz` verdict struct gains scopes (client, cache — values pass
  through). Both planes' middlewares attach scopes to the request context.
- **L6 enforcement**: the route→scope table (`internal/api/routes.go` +
  handler mounts); middleware answers 401 (unauthenticated) / 403
  (authenticated, scope missing) with lumen's error shapes. cms desks check
  the introspected scopes; admin routes check directly.
- **L7 users + scopes API**: `PATCH /admin/users/{username}/scopes` (catalog-
  validated), `GET/POST/DELETE /admin/scopes` (catalog CRUD; delete refuses
  while any user holds the scope), create-user takes `scopes`. `whoami`
  gains `id` + `scopes`. Audit-log the scope mutations (slog, the logging
  doctrine).
- **L8 tests**: migration (both eras), the 401/403 matrix per route class,
  verify-door scopes + cache behavior, tv-bump on mutation, users/scopes API
  (catalog CRUD, delete-refusal), role→bundle equivalence (admin↔full,
  editor↔content).

### M — mellon (the surface)
- **M1 types + client**: principal `id`/`scopes`; `createUser(username, tempPassword, scopes)`; `updateUserScopes(username, scopes)`; `listScopes()` / `addScope(scope, description)` / `deleteScope(scope)`; mock twin + fixtures.
- **M2 users page**: creation = scope picker (grouped checkboxes from the
  catalog); scope editor per user (with the tv-bump re-login warning copy);
  role column/pills removed. Contract tests updated.
- **M3 scope catalog surface**: list/add/delete (delete refuses while held —
  render lumen's refusal verbatim), users:manage-gated server-side AND
  rendered for holders only.
- **M4 scope-aware rendering**: nav/pages filter by `principal.scopes`
  (affordance; the auth-gate tests unaffected). The blog dashboard hidden
  for a content-less user.
- **M5 gates**: full chain + the users-page contract tests + api.test/routing.test updates.

### D — docs/vault (the round's close)
- **D1** ADR migration: this file's §0–§2 → `context-knowledge/decisions/rbac-spine.md` (status → ACCEPTED, with the landed shas).
- **D2** vault: `repos/lumen/README.md` (+LEARNING: "introspection generalized — the cms plane was the first scope-separated client"; "tv-bump is the revocation lever for scope changes"), `repos/mellon/README.md` (+LEARNING as earned), `doc-map.md` pointers.
- **D3** `mellon/DESIGN.md` §2/§6 + `lumen/DESIGN.md` §8/§9: the scope matrix replaces the role descriptions; the "mellon talks ONLY to lumen" line is amended to "only the estate's backend services, relay-verbatim" (owner ruling R1).
- **D4** `env.yaml.sample`/sample tests: nothing secrets-shaped changes (catalog is DB data) — verify the sample tests still pass.

## 4. Acceptance criteria (the whole round)

1. Fresh-install estate: TOFU grants the full set; mellon renders everything for the owner — identical to today.
2. An editor-migrated user: sees the content desks, gets 403 on the Bao cockpit and on user management — verbatim lumen copy in the UI.
3. Revoking `content:manage` from a logged-in editor: their NEXT request is 401/403 within seconds (tv bump), not 12h.
4. Catalog round-trip via the portal: add `demo:read` → assign to a user → introspection returns it → delete refused while held → delete after unassign works.
5. The cms plane behaves byte-identically except for scope checks (the introspection client's semantics untouched: 30s positives, fail closed).
6. No wire consumer breaks: mellon types adopted in the same round.

## 5. Explicitly deferred (recorded, not forgotten)

- OAuth provider linking (R9 — the users table's provider columns land when built).
- JWKS/asymmetric local verification (R8 — when an app wants zero-hop checks).
- App namespaces actually enforced (R10 — the catalog carries examples; the first real app lands its own BE + scopes and proves the wall).
- Per-app Patroni separation (R4 — the per-app DATABASE boundary is already the seam).


## 6. Addendum (2026-11-27) — the last-manager gap, and the tasks precedent

The passkey round's audit found a hole outside the passkey code: the
`users:manage` guard lives on DELETE (a delete that would leave ZERO
holders is `ErrLastManager`) but **not on `PATCH /admin/users/{u}/scopes`**.
An admin can PATCH their own scope set to remove `users:manage` (or the
last manager can be demoted by another holder) and leave the estate with
no manager at all — every admin door 403s, and recovery is the `lumen
user` bootstrap verb / manual SQL, not the portal. The portal's own UI
copy ("the last manager cannot be removed") covers only the delete path.

**Status: OPEN — owner decision required.** Two coherent closes:

1. the delete guard's twin on the scopes PATCH: inside its transaction,
   count `users:manage` holders EXCLUDING the target; if the resulting set
   would be empty, `409` (the same voice as delete). Cheap and symmetric;
   it also covers demoting *someone else* down to zero.
2. an explicit break-glass workflow (a documented `lumen user` runbook
   path) with the gap accepted as a recorded trade-off.

The tasks round (0014/0015, 2026-11-27) applied the same invariant at its
own layer, which is the precedent to copy: **every project-admin mutation
locks the project row first, and demoting/removing the LAST project admin
is a 409** — the invariant is enforced at the WRITE path, not only when a
row disappears. Deleting a user promotes the earliest remaining member
(the lifecycle hook), so a project can never be left adminless by an
account deletion either. Lesson: any authority SET needs an
"at-least-one-holder" predicate on every mutation that can shrink it —
delete is only one of the shrink verbs.
