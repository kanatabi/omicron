---
tags: [finance, plan, milestones]
updated: 2026-11-29
status: approved
---

# Finance & Budgeting — Implementation Plan

> Companion documents: [PRD](PRD.md) · [ADR](../../decisions/finance-app.md) · [Tech Spec](TECH_SPEC.md)

## Assumptions

- No new service/database; finance is a cms-plane module in lumen with tables in
  the env DB.
- Identity is the admin door; member names and invite search use the existing
  identity token.
- IDR-only MVP; currency fields are in the schema. Barcode, FX, offline and a
  native app are later.
- The API is versioned and DTO-based; the UI is portal-native.
- Migrations are new files only. `0014`/`0018` are frozen.

## Milestone execution protocol (owner ruling 2026-11-29)

Applies to **every** milestone, without exception.

1. **Sync `main` first.** For each repo the milestone touches (lumen, mellon,
   vortex; root docs/pins separately): fetch and fast-forward local `main` to
   `origin/main`. Never start from a stale base.
2. **Branch from latest `main`, per repo.** Name it `feat/finance-mN` (e.g.
   `feat/finance-m1` in lumen and mellon). One branch per touched repo, never a
   shared/stacked branch across milestones.
3. **Implement only that milestone.** Run its gates: Go unit/integration for
   lumen, `check`/`test:unit`/`lint`/`build` for mellon, and kustomize for
   vortex when touched.
4. **Self-review the diff.** Remove debug code, verify the ADR/Tech Spec
   contracts, migration classification, authz, money/date handling and tests.
5. **Spawn a fresh review subagent — this is the ONLY review gate.**
   The owner does not review manually. The reviewer is a fresh-context
   `general` subagent, read-only (review, do not modify), given the milestone
   brief, the ADR/Tech Spec/Plan, and the branch diff. It must **run the gates
   itself** (not trust the executor's summary), inspect the diff, and return a
   structured verdict: `APPROVE` or `CHANGES REQUESTED` with findings by
   severity (blocker / should-fix / nit). The executor addresses every blocker
   and should-fix and requests re-review; the branch stays unmerged until the
   verdict is `APPROVE`. The squash commit carries a `Reviewed-by: finance-review
   (<model>)` trailer for the audit trail.
6. **Squash-merge only after sign-off.** `git merge --squash <branch>` + ONE
   conventional commit on `main`, then push. Never fast-forward a branch merge;
   never rebase. Syncing `main` itself stays `--ff-only`.
7. **Bump the root pin** for every touched submodule after its pushed `main`
   (`git add lumen mellon vortex` + pin commit). The root docs/pins commit is
   separate from the milestone code.
8. **Only then start the next milestone**, forked from the updated `main`. If a
   milestone touches multiple repos, use one branch per repo, one combined
   review, and merge in dependency order: **lumen (migrations/API) → mellon
   (UI) → vortex/root**.

Review checklist for the subagent: correctness vs ADR/Tech Spec; workspace
membership/scope-role authz; last-admin; concurrency/version/idempotency/ledger
signs; migration classification and no edits to applied migrations; no users FK;
money in minor units/currency; dates/timezone; API DTO/status/pagination/
no-store; portal design grammar; tests and gates; no barcode/FX/offline code.

## Milestone overview

| Milestone | Outcome | Depends on |
| :--- | :--- | :--- |
| M0 | Signed docs; migrations/classification; module skeleton; auth/scopes plumbing | — |
| M1 | Workspaces, members, invites, permissions | M0 |
| M2 | Plans, periods, categories, budgets, copy policy | M1 |
| M3 | Accounts, ledger, income, transfers, balances | M1 |
| M4 | Expenses, baskets, items, filters | M2, M3 |
| M5 | Savings links, plan funding, workspace contributions, auto-confirm | M2, M3 |
| M6 | Credit cards/loans, analysis, accrual/cash/debt views | M3, M4, M5 |
| M7 | Desktop UI (shell, overview, budget, expenses, analysis, settings) | M2–M6 |
| M8 | Mobile shell, theme/mode QA, release hardening | M7 |
| Later | Barcode, FX/multi-currency, offline, dedicated mobile app/extraction | — |

---

## M0 — Contracts and skeleton

**Status:** merged to `main` on 2026-11-29 — lumen `f62f0e8`, mellon `a278d47`;
approved by the independent review gate (two rounds, final `APPROVE`).

**Goal:** lock the written contracts and make the empty module boot with correct
migrations, scopes and auth.

**Tasks**

- [x] Sign off PRD/ADR/Tech Spec/Plan.
- [x] Add `0019_finance_scope.sql` (admin) with the 11 scopes; update
      `internal/scopes/scopes.go` Seed.
- [x] Add `0020_finance_cms.sql` (cms) with the finance tables/indexes; no users
      FKs.
- [x] Add both to `migrationRoles` (0019 admin, 0020 cms) and the exact-role
      boundary test; verify cms subset has no users and admin subset no finance
      tables.
- [x] Create `internal/finance` package skeleton (store/service/dto; period/
      ledger land with M2/M3) and `internal/api/admin/finance.go` mount on the
      cms plane at `/admin/finance/v1`.
- [x] Wire the finance scope door (`requireAnyScope` with all finance scopes).
- [x] Add the mellon routing table entry `/admin/finance` → `CMS_URL`; add
      `finance` types/client/mock placeholders.
- [x] Add a fail-closed config check: cms finance requires the identity token
      (already present) but no new DSN.
- [x] Add `finance` to the `destinations.ts` Tools group, gated by any finance
      scope.

**Acceptance**

- `lumen migrate` for cms reports one more file and creates the finance tables;
  admin reports 0019.
- Route matrix tests: finance routes cms-only; admin 404s.
- No finance table references `users`.
- The portal rail shows Finance only for a finance scope; the route is 404/403
  otherwise.

**Tests**

- Migration classification/role-boundary tests.
- Route matrix + scope gate tests.
- Empty module boot test.

---

## M1 — Workspaces, members, invites, permissions

**Status:** merged to `main` on 2026-11-29 — lumen `0c48186`, mellon `db523a8`;
approved by the independent review gate (three rounds, final `APPROVE`).
Pending-invite list/revoke UI and workspace rename are deferred to the M7 UI
pass; the APIs exist.

**Goal:** a user can create a workspace, invite a portal user, accept/decline,
and see the correct role/permissions.

**Tasks**

- [x] Tables: workspaces, members, invites (already in 0020; add store queries).
- [x] Service: create/rename/archive; invite by username (identity door);
      accept/decline/revoke; role update; remove; last-admin guard.
- [x] Authorization: membership join on every workspace query; role admin
      required for `finance:workspace.manage`.
- [x] Effective permissions object; `finance:read` implication.
- [x] API: workspace list/detail, members, invites, roles.
- [x] Identity hydration for member names; anonymous/email never in payloads.
- [x] UI data plumbing: workspace switcher, members page/sheet; invite search
      (reuse the tasks people search pattern).
- [x] Tests: non-member 404; member/admin 403 matrix; last-admin 409; invite TTL
      410; duplicate invite upsert; identity unavailable maps 503.

**Acceptance**

- A user can create "Family", invite four members, promote one to admin, and
  cannot remove/demote the last admin.
- A member without `finance:workspace.manage` cannot invite/remove.
- The workspace selector shows all memberships with roles.

---

## M2 — Plans, periods, categories, budgets

**Goal:** recurring and fixed plans, generated periods, plan categories, and
per-period budgets with copy rules.

**Tasks**

- [ ] Plan create/update/archive; validate schedule/currency/dates.
- [ ] Period generator: weekly/monthly/quarterly/semiannual/yearly, anchored
      start, month-length clamp, optional end, fixed single period.
- [ ] `ensurePeriods` on plan read/expense create; current/upcoming computation.
- [ ] One cms-worker River daily job `finance.period_tick` (23:55): scan active
      recurring plans, ensure periods through a 7-day lookahead in the
      workspace timezone; idempotent under concurrent replicas; lazy path
      remains the fallback.
- [ ] Plan-specific categories CRUD; recurring flag; archive.
- [ ] Budget API: planned income PATCH (period version), per-line
      create/edit/delete (line version), expense/debt/card lines; savings
      commitments derived from links (stub until M5). No whole-budget PUT.
- [ ] Copy policy: none/all/recurring_only at period generation; manual “Copy
      last period” merges missing lines only (never overwrites).
- [ ] API: plans, periods, categories, budget lines, planned income.
- [ ] UI: plan selector (+ New plan), empty state, budget table with per-row
      autosave/row save, copy button, plan settings; period selector.
- [ ] Tests: period math (month-end, leap year, weekly/quarterly/yearly),
      copy modes, fixed plan one period, cross-plan category rejection,
      two-admin different-line edits succeed, same-line 409.

**Acceptance**

- Create "Family Monthly" recurring on the 25th; navigate periods; copy budget.
- Create "Vacation 2027" fixed; one period; budget is expected cost.
- A category from another plan is rejected with 400.
- New-period copy respects the mode and per-category recurring flag.
- Two admins editing different category lines simultaneously both save; the
  same-line second edit gets a 409 and refetches only that row.

---

## M3 — Accounts, ledger, income, transfers

**Goal:** workspace accounts with signed balances and a ledger for actual money
movement.

**Tasks**

- [ ] Accounts CRUD: cash/bank/ewallet/credit_card/loan; opening balance;
      credit limit/statement/due/interest fields.
- [ ] Ledger table + service: signed entries; balance cache in the same
      transaction; transfer pair helper.
- [ ] Income entries (workspace-level, planned vs actual).
- [ ] Transfers (bank→card, bank→savings); debt payments + interest.
- [ ] Reconciliation query/test `opening + sum(ledger) = balance`.
- [ ] API: accounts, income, transfers, debt payments, ledger list (cursor).
- [ ] UI: accounts settings; income/transfer/debt entry sheets; balance display
      (liability rendered as owed).
- [ ] Tests: signs, transfer pairs, card/loan balances, reconciliation, idempotent
      client ids.

**Acceptance**

- Card purchase increases liability; payment reduces it; bank balance changes;
  no double-counted expense.
- Loan disbursement/payment/interest produce the expected balances.
- Account list shows asset vs liability correctly.

---

## M4 — Expenses and baskets

**Goal:** manual expense entry, including multi-item baskets with mixed
categories.

**Tasks**

- [ ] Expense + item store/service; total = sum items; plan/period derivation;
      primary category.
- [ ] Create/edit/soft-delete with ledger entry adjustment in one transaction;
      plan/period immutable.
- [ ] Category validation per plan; at least one item; quantity × unit price.
- [ ] List/filter: plan, period, category, account, text; all-plans view; keyset
      cursor; plan column.
- [ ] Idempotent create with `clientId`.
- [ ] API: expenses list/detail/create/update/delete.
- [ ] UI: expenses list; New basket sheet; item rows with quantity/price and
      category chips; "Add item manually"; totals; save.
- [ ] Tests: mixed-category basket analysis; total/ledger atomicity; cross-plan
      400; soft delete; pagination.

**Acceptance**

- A 12-item grocery basket with Groceries/Household items saves and attributes
  each item correctly.
- An individual expense is a one-item basket.
- Deleting an expense removes it from lists and reverses the ledger/balance.

---

## M5 — Savings links and contributions

**Goal:** plan funding and workspace contributions, including cross-workspace
links, envelope/transfer, anonymous, auto-confirm.

**Tasks**

- [ ] Links table/service: purpose, source/target, accounts, cadence, mode,
      anonymous, auto-confirm, status.
- [ ] Generate planned contributions per period/cadence; source budget reserves;
      target pledged.
- [ ] Confirm/skip; transfer pair or envelope; target funded/actual; ledger.
- [ ] Cross-workspace membership/scope checks on create/confirm; pause on loss
      of access.
- [ ] Auto-confirm: inside `finance.period_tick` (or a separate River job);
      claim due planned contributions; idempotent; workspace timezone.
- [ ] Funded ≥ expected alert; unlink/pause cancels future.
- [ ] Workspace contribution expected/actual in the workspace overview; member
      contribution reporting (not earned income).
- [ ] UI: commitments on Budget, contribution dialog, progress/funded, anonymous
      display, source/target account pickers.
- [ ] Tests: plan funding from personal→family; workspace contribution; envelope
      vs transfer; skip releases; auto-confirm; anonymous hides contributor;
      cross-workspace 403/404.

**Acceptance**

- Personal Monthly reserves 1M and Family Vacation shows 1M/month pledge; a
  confirmation raises funded; 100% alerts.
- Family operating account receives a workspace contribution; it is reported as
  a member contribution, not earned income.
- Source and target memberships are both required; losing one pauses.

---

## M6 — Credit/loan analysis and reporting

**Goal:** correct accrual/cash/debt analysis.

**Tasks**

- [ ] Plan overview: expense budget remaining, allocated/unallocated, savings
      commitments, funded/spent/available.
- [ ] Cash/debt card: asset balances, card due, loan due, cash after debt.
- [ ] Plan analysis: category budget vs actual, pace, top categories, previous
      period.
- [ ] Workspace analysis: totals/per-plan, earned income vs member contributions,
      savings progress.
- [ ] Loan schedule/installments: schedule table or derived schedule; budget
      commitment; due amounts. Card statement/due computation.
- [ ] UI: analysis page, charts (SVG), period comparison; label accrual vs cash.
- [ ] Tests: formula fixtures; card/loan scenarios; zero/negative unallocated;
      funded vs spent.

**Acceptance**

- The 10M income / 2M debt example shows the correct cash-after-debt and accrual
  remaining, with no double counting.
- Analysis matches hand-calculated fixtures for mixed categories and savings.

---

## M7 — Desktop UI

**Goal:** portal-native desktop finance app.

**Tasks**

- [ ] `finance` route layout: global rail + finance sub-sidebar; workspace
      selector at top; nav.
- [ ] Content header: breadcrumb (workspace as text), page title 30px, subtitle,
      plan/period selects, primary action baseline.
- [ ] Overview, Budget, Expenses, Analysis, Settings pages with portal
      components.
- [ ] Plan selector dropdown (+ New plan, Manage plans), empty states.
- [ ] Theme/mode QA across all registered themes; shape audit (8/6/4px; no pill
      primary; mono money).
- [ ] Accessibility: keyboard, focus, labels, contrast.
- [ ] Link the Flowstep reference and the design decisions.

**Acceptance**

- Desktop screens read as mellon, not a separate SaaS.
- One workspace selector only; plan/period selectors separate.
- Every theme/mode passes the visual QA.

---

## M8 — Mobile shell and release

**Goal:** app-local mobile shell, release and first household.

**Tasks**

- [ ] `AppTabBar` (generic) + FAB; safe area; 10px labels; brand active; 48px
      circle.
- [ ] Mobile header: workspace/plan/period selects (8px), page titles 24px.
- [ ] Mobile pages: overview, budget cards, expenses list, basket sheet,
      analysis cards.
- [ ] Responsive QA on phone/tablet; no horizontal scroll; sticky save.
- [ ] Release lumen (migrations/API) then mellon; verify cms migrate applies
      0020; grant scopes; create first workspace.
- [ ] Smoke: household invite, budget, basket, contribution, card payment,
      analysis.
- [ ] Docs/vault sync; update DESIGN/README; record lessons.

**Acceptance**

- A phone user can add a basket and confirm a contribution without a desktop.
- The console shell is unchanged outside `/finance`.
- The production/staging envs have the finance tables; the app is gated by
  scopes.

---

## Cross-cutting work

- **Authz:** one helper for scope implication; role checks in SQL; no broad
  write; membership join on every query.
- **Money/currency:** minor units and a currency exponent table; IDR MVP; no
  floats.
- **Dates:** plan/period math in one package; client timezone for "today".
- **Observability:** structured logs without amounts/descriptions; metrics for
  finance mutations; no PII.
- **Docs:** PRD/ADR/Tech Spec/Plan kept in the vault; repo DESIGN/README updated
  in the same round as the code.
- **Migration discipline:** new files only; exact-role tests; no edits to 0014,
  0018, 0019, 0020 after they ship.

## Later backlog

1. Barcode lookup provider/key + server proxy + product cache; iOS scanner
   fallback.
2. Per-plan currency + FX rates + workspace display currency.
3. Offline-first mobile API (client ids, sync, conflicts) and dedicated mobile
   auth.
4. Receipt attachments via the media relay.
5. Recurring-expense automation and budget/debt notifications via the shared
   notifications door.
6. CSV import/export.
7. Extract `internal/finance` + schema + API into a dedicated service; move the
   mobile app to it.

## Risks / dependencies

- Identity door availability for member names; the token is already present.
- Cross-workspace authorization and atomic ledger pairs.
- Period/copy complexity; defaults and empty states.
- Shared workspace privacy; warn on invite.
- Performance with a growing ledger; balance cache and measured rollups.
- Scope catalog growth; group finance scopes in Users.
- Release order: lumen migrations/API before mellon; the cms migrate job is the
  only schema path.
