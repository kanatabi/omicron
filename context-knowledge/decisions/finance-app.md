---
tags: [finance, adr, architecture, decision]
updated: 2026-11-29
status: accepted
---

# ADR — Finance app architecture

- **Status:** proposed
- **Date:** 2026-11-29
- **Deciders:** owner
- **Implements in:** lumen (cms plane), mellon (portal), vortex (release/config)
- **Companions:** [PRD](../apps/finance/PRD.md) · [Tech Spec](../apps/finance/TECH_SPEC.md) · [Plan](../apps/finance/PLAN.md)

## 1. Context

The estate already has the role-split backend: `lumen-admin` owns identity,
sessions, scopes, profiles and the shared notification inbox; `lumen-staging` /
`lumen-production` own content and the tasks application in their own databases.
Tasks proved the app-plane pattern: a self-contained module on the cms plane,
tables in the env DB, identity through the admin door, routed by the portal.

Finance is the second app. It is more complex than tasks:

- multiple workspaces per user, each with its own members, roles, accounts and
  currency;
- recurring and fixed budget plans with generated periods;
- plan-specific categories and per-period budgets;
- baskets with item-level categories;
- accounts and a real ledger (income, expenses, transfers, credit cards,
  loans);
- savings links that can cross workspaces, plus unrestricted workspace
  contributions;
- analysis on both accrual and cash bases;
- a future dedicated mobile app that must consume the same API.

The estate also learned a hard migration lesson on 2026-11-29: an applied
migration must never be edited; the role classification is the executable
scope; migrations for a new database are new files (see
[LEARNING](../repos/lumen/LEARNING.md)). Finance follows that rule.

## 2. Decision drivers

1. Keep identity, sessions and scopes single-homed in `lumen-admin`.
2. Keep finance data in each environment's DB; no new database/DSN.
3. Share the same portal components, tokens and shell; the app must look like
   mellon, not a second product.
4. Support arbitrary workspaces and household sharing without per-row ACLs.
5. Keep the model correct for budgets, savings, contributions, credit cards and
   loans; no double counting.
6. Make extraction to a dedicated service and mobile app a migration, not a
   rewrite.
7. Performance must scale beyond the current five-person household without
   harming the rest of the DB.
8. Ship the MVP online-only; barcode/FX/offline are future work.

## 3. Decisions

### D1 — Finance is a modular monolith in lumen, cms plane

Finance lives in `internal/finance` (store/service/DTOs) and mounts on the cms
plane under `/admin/finance/v1`. Tables live in `lumen_staging` /
`lumen_production`. The admin plane remains control + identity only.

**Why:** the estate already pays the operational cost of one binary and one
DB per env; identity is central. A separate service would require a new DB,
auth strategy and deployment before the product is validated. The module is
written with the same extraction seams as tasks.

**Consequences:** the cms app grows; its release trains with content and tasks;
extraction later lifts the package, schema and API.

### D2 — Workspace is the sharing and privacy boundary

A workspace is an arbitrary named membership group (Personal, Family, Brothers,
Parents, Trip Crew). There is **no** `personal | household` type. A workspace
with one member is private by fact; adding a member makes it shared. A plan
belongs to exactly one workspace; there is no per-plan ACL.

**Why:** membership, accounts, currency and categories belong to the group.
Per-plan ACLs would duplicate membership and break shared aggregates.

**Consequences:** sharing an existing plan means moving/copying it to a shared
workspace. Inviting someone to a one-member workspace exposes its data to them
if they hold the scopes; the UI warns. Private data belongs in a separate
one-member workspace.

### D3 — Workspace → Plan (recurring | fixed) → Period

A plan is a budget container. It is either:

- **recurring** — weekly/monthly/quarterly/semiannual/yearly, anchored to a
  start date, optional end; periods generated from the schedule; or
- **fixed** — one period with a start/end (vacation, college fund).

Categories are **plan-specific**. The budget is **per period**. Planned income
is per period. New-period copying is controlled by the plan setting
`none | all | recurring_only` plus per-category recurring flags.

**Why:** a monthly plan and a vacation plan have different categories and
different time semantics. A single global category set would force unrelated
vocabularies together. Per-period budgets allow historical accuracy.

**Consequences:** period generation, copy rules and plan-specific category
management are first-class. Cross-plan category analytics is limited to
per-plan breakdowns.

### D4 — Budget and ledger are separate

- **Budget:** period planned income, expense category allocations, debt/card
  commitments, and planned savings contributions.
- **Ledger:** actual money movement in workspace accounts — expenses, income,
  transfers, debt payments, interest, contributions.

Expenses are per plan/period; income and transfers are workspace-level. An
expense header has items; items carry the budget category, so a basket can mix
categories. The ledger is the source of account balances; the budget is the
planning layer.

**Why:** conflating them causes double counting (e.g. a card purchase plus its
payment), makes savings look like spending, and cannot model liabilities or
transfers. The separation also makes analysis honest.

**Consequences:** every expense creates a ledger entry; transfers are pairs of
entries; account balances are derived from the ledger (or a maintained cache);
budget remaining is not the same as cash available.

### D5 — Contributions have two purposes

- **Plan funding:** source plan → target plan; destination is the target
  workspace's savings account; restricted to the target plan; **not income**;
  tracks pledged/funded/expected.
- **Workspace contribution:** source plan/account → target workspace's
  operating account; unrestricted; reported as a **member contribution**, not
  earned income; usable in the target workspace budget.

Both are one-off or recurring, can be anonymous, and can auto-confirm. Links are
user-owned and can cross workspaces; the user must be a member of both. In
`transfer` mode ledger entries are written; in `envelope` mode no account moves.
The target account lives in the target workspace.

**Why:** a vacation fund and a household contribution are different products:
one is restricted, the other is operating money. Treating both as income would
misstate the household's earnings; treating both as expenses would double count.

**Consequences:** the contribution ledger and target account must be explicit;
cross-workspace authorization is required; FX is deferred but the schema carries
`fx_rate`.

### D6 — Full liability ledger, with accrual and cash views

Accounts are typed cash/bank/e-wallet/credit-card/loan. Credit-card purchases are
expenses (category spend at purchase time); card payments are transfers. Loan
instalments are debt-payment budget lines; the payment is a transfer, interest
is an expense. The monthly overview shows:

- **accrual budget:** planned income − savings − expenses (including card
  purchases) − loan commitments; and
- **cash/debt:** cash after debt, card due, loan due, outstanding balances.

**Why:** the owner explicitly wants full liability tracking and the 10M − 2M
example. Showing only one basis would either hide liquidity or double count
card purchases.

**Consequences:** the ledger sign rules and the analysis formulas must be
defined once; the UI must label the two numbers clearly.

### D7 — Identity and authorization: admin door + scope/role intersection

- Finance tables hold `user_id` UUIDs, never a users FK or a local users table.
- The cms app uses the admin session bearer; no new identity store.
- **Read scopes:** `finance:read` (broad) implies `finance:workspace.read`,
  `finance:plan.read`, `finance:expense.read`, `finance:analysis.read`,
  `finance:contribution.read`.
- **Write scopes (granular only):** `finance:plan.write`,
  `finance:budget.write`, `finance:expense.write`,
  `finance:contribution.write`, `finance:workspace.manage`.
- **Workspace roles:** `admin` (highest, multiple allowed, last-admin guard) and
  `member`. A member's actions are scope-gated; a read-only member behaves as a
  viewer.
- Effective permission = estate scope **and** workspace role. A workspace admin
  can invite, but cannot grant estate scopes; the UI shows missing scopes.

**Why:** identity is single-homed; the estate scope catalog is the grant
surface; workspace roles express local authority. This matches the owner's
"admin can add a member, but missing scopes block actions" rule.

**Consequences:** the scope catalog grows by 11; the admin UI groups finance
scopes; the app returns an effective permissions object for UI gating.

### D8 — Manual MVP; barcode/offline/FX deferred

Barcode lookup is a paid external service and iOS Safari lacks
`BarcodeDetector`; the owner chose to defer it. All items are entered manually.
The app is online-only. Currency is IDR-only in MVP, but `currency` is stored on
workspaces, plans and money rows, and `fx_rate` on contributions, so per-plan
currency and FX can land later.

**Why:** avoid an external key/provider decision and an iOS decoder dependency
before validating the app; keep the MVP focused.

**Consequences:** the barcode field/product cache/API key are absent from the
first schema/API (a later migration can add them). The mobile scanner is a later
feature.

### D9 — API designed as a future service and mobile contract

- Versioned path: `/admin/finance/v1/...`.
- Bearer auth; no cookie/session state in the finance module.
- Explicit DTOs; no DB rows on the wire.
- Workspace-scoped routes and SQL authorization.
- Keyset pagination; explicit error codes.
- Client-generated UUIDs (`client_id`) for idempotent creates.
- Effective `permissions` object so a native app can gate the same way.

**Why:** the owner may extract finance and build a dedicated mobile app. The
module must not depend on mellon's SvelteKit session or UI state.

**Consequences:** the API is slightly more verbose than an internal handler; the
mobile app can reuse it. Mobile auth (refresh/passkey) is still a future
decision.

### D10 — Performance: header totals, indexes, balance projection, rollups later

- Store expense totals on the header; items are detail.
- Store account balances as a maintained **Postgres projection** (opening +
  ledger sum) updated atomically with ledger writes; a reconciliation test
  proves it. This is not a Redis/external cache (see D14).
- Indexes for workspace/plan/period/date/category/account and keyset pagination.
- Aggregates in SQL; no N+1.
- Add per-period/category rollups only if the header aggregates exceed the
  query budget; partitioning is a later, measured step.
- Optionally route heavy analysis to the Patroni read-only service.

**Why:** the household is five people now, but the model should not accumulate
debt for a larger future. The ledger can grow faster than the budget rows.

**Consequences:** balance updates and ledger writes share a transaction; tests
must reconcile; summary tables are a deliberate future optimization.

### D11 — Migrations: two new files, no edits

- `0019_finance_scope.sql` (admin DB): inserts the finance scope catalog.
- `0020_finance_cms.sql` (cms DB): creates the finance tables/indexes.
- `0014_tasks.sql` stays frozen; `0018_tasks_cms.sql` remains the tasks cms
  bootstrap. Finance does not touch either.
- Every new file is classified in `migrationRoles`; 0019 admin, 0020 cms.
- The cms DB has no users table and no users FKs.

**Why:** the 2026-11-29 incident proved that editing an applied migration and
mis-classifying it silently skips the target DB. Exact role-boundary tests are
required.

**Consequences:** the cms migrate job applies 0020 to staging/production; the
admin job applies 0019. No new DSN.

### D12 — Portal-native UI, app-local mobile shell

- Desktop: Tools → Finance; the global rail + a finance sub-sidebar with the
  workspace selector and Overview/Budget/Expenses/Analysis/Settings.
- Plan and period are header selectors; one workspace selector only.
- Mobile: an app-local bottom tab bar + add-expense FAB, reusable as
  `AppTabBar`; the console shell is not redesigned in MVP.
- Reuse mellon's `Button`, `Select`, `Card`, `Tag`, `Popup`, `Sheet`, tokens and
  type; Inter for UI, JetBrains Mono for money; 8/6/4px shape grammar.

**Why:** the first design draft used a generic SaaS language; the portal's
identity is binding. A scoped mobile shell avoids regressing the whole console.

**Consequences:** the finance app is visually consistent; a later global mobile
nav can promote the tab bar.

### D13 — Concurrency: row locks + optimistic versions + idempotency

Multiple workspace members may edit the same plan, budget, expense or
contribution. The design uses Postgres transactions and four mechanisms, chosen
per operation:

1. **Pessimistic row locks** for invariants that span rows:
   - last-admin demote/remove: lock the workspace row (`FOR UPDATE`), count
     admins, then update;
   - invite accept: lock the invite row, check expiry, insert membership, delete
     invite in one transaction;
   - contribution confirm/skip and auto-confirm: lock the contribution row (or
     claim it with `UPDATE … WHERE status='planned' RETURNING`) so exactly one
     actor wins;
   - period generation/copy: `INSERT … ON CONFLICT (plan_id, starts_on) DO
     NOTHING RETURNING id`; only the creator copies the budget, under a
     per-plan advisory transaction lock. Triggers are lazy (API read/expense
     write) **and** one daily River job (`finance.period_tick`, 23:55,
     7-day lookahead) in the cms worker — never one cron per plan;
   - ledger/transfer: lock account rows in a deterministic UUID order, update
     balances atomically, write the entry pair in one transaction;
   - workspace/plan archive: lock the row, pause links/stop new work.
2. **Optimistic versions** for user-edited aggregates: `version` on workspaces,
   plans, periods, accounts, categories, budget lines, expenses and links. Reads
   return the version; `PUT/PATCH` require `If-Match` / `expectedVersion`; the
   update is `UPDATE … WHERE id=$1 AND version=$2` and increments the version.
   A mismatch is `409` with the current version, so two admins cannot silently
   overwrite the same line. **Budget lines are independent resources with their
   own versions**: two admins editing different categories in the same period
   both succeed; only edits to the SAME line conflict. Planned income rides the
   period version (it is a period field); editing income conflicts only with
   another income edit, not with category-line edits. There is no whole-period
   budget PUT.
3. **Unique constraints as hard invariants**, mapped to `409`:
   `(workspace_id, invitee_id)`, `(plan_id, starts_on)`,
   `(plan_id, lower(name))`, `(period_id, category_id)` for expense lines,
   `(link_id, due_on)`, `(workspace_id, client_id)` on expenses/ledger, and the
   active-link uniqueness rule. The database is the last word, not a pre-check.
4. **Idempotency keys** on creates: `client_id` (UUID) on expenses, income,
   transfers and manual ledger entries. A retry with the same key returns the
   existing row (200) instead of creating a second one. Confirm is idempotent by
   the contribution state machine.

**Transactions and isolation:** `READ COMMITTED` plus explicit locks and
constraints is the default. Financial writes keep transactions short, do no
HTTP/identity calls inside them, and lock in a fixed order (workspace → plan →
period → accounts by UUID). A deadlock (`40P01`) or serialization failure
(`40001`) is retried a small number of times only for idempotent operations;
exhausted retries map to `409`/`503`, never a partial write. Cross-workspace
transfers are one transaction because both workspaces share the env DB; if
finance is extracted to separate DBs later, that path becomes an outbox/saga
(see D9).

**API semantics:** `If-Match: "<version>"` (or `expectedVersion` in the body)
per mutable resource — a budget line has its own version, planned income uses
the period version, and an expense/plan/link uses its own. `409` for a
same-resource version mismatch, last-admin, duplicate active link/invite, or a
contribution already skipped; `200` for an idempotent replay; `404` for
non-membership/non-existence, never `403` for a hidden row. The UI saves each
budget line independently (autosave/row save) and refetches only the conflicted
row on `409`; there is no live multi-user merge in MVP.

**Ledger edits:** expense edits/deletes adjust the ledger entry and account
balance in the same locked transaction in MVP; the expense version and audit
timestamps provide the change history. A formal append-only
reversal/compensating-entry ledger is a future audit enhancement (it does not
change the concurrency rules).

### D14 — “Caching” means Postgres projections, not Redis

The Tech Spec's “balance cache” is a **maintained denormalized column**
(`finance_accounts.balance_minor`), updated in the same transaction as the
ledger write, with a reconciliation test. The “rollups” are optional Postgres
summary tables/materialized views for analysis. There is **no Redis/Valkey or
external cache** in the estate and none is added by finance.

- No in-process cache of finance data: the cms can have multiple replicas, and
  balances/budgets must not be stale. The only existing in-process cache is the
  cms auth introspection cache (`internal/authz`, ~30s), unrelated to finance
  data.
- Finance API responses are `Cache-Control: no-store`; the portal relay must not
  cache private finance data; no CDN.
- Postgres (indexes, prepared statements, connection pool) is the read path.
  Heavy analysis may use a read replica; summary tables are a measured later
  step.
- Member display names are read through the existing identity door; if a cache
  is ever added there, it is a short in-process TTL for names only — never
  permissions or balances. Redis remains a separate infrastructure decision.

## 4. Alternatives considered

| Alternative | Why rejected |
| :--- | :--- |
| Plan = workspace (each plan has its own membership) | Duplicates membership/accounts/categories per plan; cross-plan savings links cross permission boundaries; household friction |
| Separate finance service + DB now | Premature; new auth/DB/deploy; the module seams already permit extraction |
| Users table/FKs in the cms DB | Breaks the role split; duplicates identity; drift |
| Per-plan or per-expense ACL (private rows in shared workspace) | Breaks aggregates and every query; personal workspace is the privacy boundary |
| Single budget/expense table without a ledger | Cannot model accounts, transfers, card payments, loans, or cash vs accrual without double counting |
| Broad `finance:write` scope | Owner ruling: writes are granular only |
| Treat plan funding as workspace income | Misstates earnings; the money is restricted and not spendable |
| Barcode API in MVP | Paid provider/key and iOS scanner gap; owner deferred; manual first |
| Offline-first mobile API now | Adds sync/conflict complexity; online-only is the MVP |

## 5. Consequences and risks

**Positive**

- One identity, one env DB, one release train; no new infrastructure.
- Correct accounting for budgets, savings, contributions, cards and loans.
- Arbitrary workspaces support any group.
- API ready for a dedicated mobile app/extraction.
- Portal-native UI by reusing components.

**Negative / risks**

- Cross-workspace contributions and ledger pairs need careful authorization and
  atomic writes.
- The ledger/accrual-cash distinction is a UX teaching cost; labels must be
  explicit.
- Per-period budgets and plan-specific categories mean more setup; copy rules
  and defaults must be good.
- The cms app now carries content + tasks + finance; release coupling grows.
- Workspace sharing has no per-plan privacy; inviting changes visibility.
- Mobile auth and offline are unresolved future work.

## 6. Review checklist

- [ ] No finance table has a `users` FK or local users table.
- [ ] `0019` is admin-only, `0020` cms-only; `migrationRoles` has exact-role
      tests; no applied migration edited.
- [ ] Every workspace-scoped query joins the caller's membership; a non-member
      gets the one not-found voice.
- [ ] Scope checks are the intersection of estate scope and workspace role; no
      broad write.
- [ ] Last-admin guard is transactional.
- [ ] Mutable aggregates carry a `version`; updates require `If-Match` and
      return 409 on mismatch.
- [ ] Budget lines are independent resources: different-category edits by two
      admins both succeed; same-line edits 409; planned income uses the period
      version; no whole-period budget PUT.
- [ ] Creates use `client_id` idempotency; unique constraints are the hard
      invariant.
- [ ] Locks are taken in a fixed order; no HTTP/identity calls inside write
      transactions; deadlock retries are bounded.
- [ ] Contribution confirm/auto-confirm claim the row exactly once; period
      generation is `ON CONFLICT` safe.
- [ ] Ledger/account-balance writes are in one transaction; reconciliation
      passes.
- [ ] No Redis/external cache; finance responses are `no-store`.
- [ ] Money is integer minor units + currency; no floats.
- [ ] Expense items' categories belong to the expense plan; the server rejects
      cross-plan combinations.
- [ ] Plan funding and workspace contributions are not counted as income in the
      wrong place; ledger signs and budget formulas are documented and tested.
- [ ] Account balances reconcile with the ledger.
- [ ] API is versioned, DTO-based, bearer-only, paginated, idempotent on create.
- [ ] UI uses portal tokens/components; no pill primary buttons, no 16px cards,
      no generic SaaS styling.
- [ ] Mobile `AppTabBar` is app-local; the console shell is untouched.
- [ ] No barcode/offline/FX code in MVP.

## 7. Decision log

| Date | Change |
| :--- | :--- |
| 2026-11-29 | Initial ADR: cms module, arbitrary workspaces, plans/periods, budget+ledger, two contribution purposes, full liability, scopes/roles, portal-native UI, manual MVP. |
