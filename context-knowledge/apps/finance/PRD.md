---
tags: [finance, prd, product]
updated: 2026-11-29
status: approved
---

# Finance & Budgeting — Product Requirements

> Companion documents: [ADR](../../decisions/finance-app.md) · [Tech Spec](TECH_SPEC.md) ·
> [Plan](PLAN.md) ·
> [UI reference](https://app.flowstep.ai/file?activeFileId=c92688f2-4123-4448-9d3f-1eb4864d3f60)

## 1. Summary

A personal and shared budgeting application inside the mellon console. Users
record expenses manually, plan budgets for recurring or fixed periods, save
toward future plans, track household contributions, and analyse spending
against budget. No bank/payment integration, no billing, no automated
transaction import. A dedicated mobile app is a later consumer of the same API.

## 2. Problem

The estate has no way to plan or track money. Existing tools are either
personal-only (no family sharing), bank-locked, or too generic for the owner's
actual pattern: monthly household budgeting, separate goal plans (holiday,
college), savings links between plans, and credit-card/loan obligations.

## 3. Goals

- One workspace model that works for a single person and for arbitrary groups
  (family, brothers, parents), with explicit membership and roles.
- Plan any budget: recurring (weekly/monthly/quarterly/semiannual/yearly) or
  fixed (vacation, college fund, renovation).
- Record expenses quickly, including a multi-item basket with per-item budget
  categories.
- Save toward a future plan from a current plan, and contribute to a shared
  workspace, without confusing either with spending.
- Track credit-card and loan liabilities, and see both accrual budget and cash
  flow.
- Analyse budget vs actual, savings progress, debt, and member contributions.
- Keep the same design language, theming, and identity as the rest of mellon.

## 4. Non-goals (MVP)

- Bank/payment integration, billing, automatic transaction import.
- Barcode lookup / in-app scanning (deferred; all entries manual for now).
- Multi-currency conversion and FX (IDR only; schema is currency-ready).
- Offline mode or a native mobile app (the API is designed for one later).
- Receipt image storage, recurring-expense automation, budget alert push
  notifications.
- Per-expense privacy inside a shared workspace.

## 5. Personas and jobs

| Persona | Workspace | Job |
| :--- | :--- | :--- |
| Owner | Personal | Track personal spending and save toward goals |
| Owner | Family (5 members) | Plan the household month, share expenses, agree on savings |
| Owner | Brothers / Parents | Run a smaller shared budget with a subset of people |
| Household member | Family | Add expenses, see the budget/analysis they are scoped for |
| Household admin | Family | Invite members, set roles, manage accounts and plans |

## 6. Product principles

1. **Workspace is the sharing and privacy boundary.** A one-member workspace is
   private; a multi-member workspace is shared. There is no per-plan or
   per-expense ACL.
2. **Budget is a plan, not a bank account.** Budget lines and ledger entries are
   different things. Savings and contributions are not expenses.
3. **Manual entry is a first-class path.** No integration is required for any
   core flow.
4. **Accrual and cash are both visible.** The budget answers "what can I still
   spend?"; the cash view answers "what leaves my account, and what debt is
   due?"
5. **Portal-native.** Reuse mellon's shell, tokens, type, shape grammar and
   permission model; do not invent a second design system.

## 7. Concepts

| Concept | Meaning |
| :--- | :--- |
| Workspace | Named membership group; owns members, roles, accounts, default currency |
| Plan | Budget container: recurring or fixed; plan-specific categories and currency |
| Period | A concrete date range generated from the plan; holds the budget |
| Budget line | Allocation for an expense category, debt payment, or card reserve |
| Expense | One purchase/receipt; belongs to a plan and period; has items |
| Basket | The editing flow for a multi-item expense; one purchase |
| Account | Workspace-level cash/bank/e-wallet/credit-card/loan |
| Ledger entry | Actual money movement (expense, income, transfer, debt payment, interest, contribution) |
| Plan link | A user-owned savings/contribution bridge between a source plan and a target plan/workspace |
| Contribution | One planned/confirmed/skipped instalment of a link |
| Workspace contribution | Unrestricted transfer to the target workspace's operating account |
| Plan funding | Restricted transfer to a target plan's savings account |

## 8. User journeys

### 8.1 First run

1. User opens Finance from Tools.
2. If no workspace: create the first workspace (name, currency, timezone).
3. Create a plan: recurring or fixed, dates/recurrence, currency, copy policy.
4. Set the period budget: planned income, category allocations, commitments.
5. Add the first expense or basket.

### 8.2 Monthly household budget

1. Workspace "Family"; members invited with roles.
2. Plan "Family Monthly" with recurrence monthly, anchored to payday.
3. Admin sets planned income and category allocations; recurring categories
   (subscriptions) copy from the previous period.
4. Members add expenses; each expense carries a plan category.
5. The overview shows budget remaining (accrual) and cash/debt.
6. Analysis compares spend by category, pace, and period.

### 8.3 Vacation plan funded from a personal monthly plan

1. Family workspace has a fixed "Vacation 2027" plan with expected budget.
2. Personal Monthly plan creates a plan-funding link of 1M/month to the
   Vacation plan, with the family savings account as destination.
3. The source period reserves 1M automatically; the target shows a 1M/month
   pledge.
4. Each month the user confirms (or auto-confirms) the contribution; the target
   `funded` increases.
5. At 100% funded, an alert appears; the user can unlink or keep a buffer.
6. During the trip, expenses are recorded in the Vacation plan; `available`
   decreases; `spent` and `funded` remain separate.

### 8.4 Household contribution

1. A member creates an unrestricted workspace contribution to the Family
   operating account, one-off or recurring.
2. The target workspace sees it as a member contribution (not earned income);
   it is usable in the workspace budget.
3. The source workspace records a transfer out; it is not an expense.
4. Expected recurring contributions appear in the target workspace overview;
   actual contributions appear in the ledger.

### 8.5 Basket with mixed categories

1. Open "New basket"; choose plan, date, account, description.
2. Add items manually (name, quantity, unit price); assign each item a category
   from the plan (e.g. Groceries, Household).
3. The expense total is the sum of items; saving commits the expense, its items,
   and the ledger entry atomically.
4. The budget analysis attributes each item to its category.

### 8.6 Credit card and loan

1. Card purchase: recorded as an expense from the card account; category spend
   is counted immediately; the card liability increases.
2. Card payment: a transfer from bank to card; not an expense; cash flow shows
   the payment.
3. Loan: a liability account with a schedule; each instalment is a debt-payment
   budget line; payment is a transfer plus an interest expense.
4. The monthly overview shows accrual remaining and a cash/debt card with
   outstanding balances and due amounts.

## 9. Functional requirements

### 9.1 Workspaces and membership

- FR-W1: Create, rename, archive a workspace; choose default currency/timezone.
- FR-W2: Invite a portal user; accept/decline; 7-day TTL; one pending invite per
  workspace+invitee.
- FR-W3: Roles `admin` and `member`; multiple admins; the last admin cannot be
  removed or demoted.
- FR-W4: A member with the required scopes can read/add expenses; actions are
  gated by estate scope + workspace role.

### 9.2 Plans, periods, categories

- FR-P1: Create recurring or fixed plans; recurrence weekly/monthly/quarterly/
  semiannual/yearly, anchored to a start date; optional end date.
- FR-P2: Plan-specific categories with name, icon, colour, sort, recurring flag.
- FR-P3: Generate periods from the schedule; fixed plans have one period.
- FR-P4: Budget is per period; planned income; expense/debt/card budget lines.
- FR-P5: New-period copy policy `none | all | recurring_only`; recurring
  categories/commitments copy; the user can edit.
- FR-P6: Plan currency defaults to the workspace currency; IDR in MVP.
- FR-P7: Budget lines are independently editable; two members changing
  different categories in the same period both succeed; a same-line edit is a
  visible conflict, not a silent overwrite.

### 9.3 Expenses and baskets

- FR-E1: One purchase = one expense; an individual expense is a one-item basket.
- FR-E2: Basket items: name, quantity, unit price, amount, category; mixed
  categories allowed; barcode field is not used in MVP.
- FR-E3: Expense header: plan, period (derived), account, description, date,
  total, created_by; soft delete.
- FR-E4: Server validates that every item category belongs to the expense plan.
- FR-E5: List/filter by plan, period, category, account, text; keyset
  pagination; an all-plans view shows a plan column.
- FR-E6: No discount/tax allocation in MVP; total = sum of item amounts.

### 9.4 Accounts, income, transfers

- FR-A1: Workspace accounts: cash, bank, e-wallet, credit card, loan; signed
  opening balance; optional credit limit/statement/due days/interest.
- FR-A2: Actual income entries at workspace level; planned income per period.
- FR-A3: Transfers between accounts; card payments and loan payments are
  transfers; interest is an expense.
- FR-A4: Account balance is the signed ledger sum + opening balance.

### 9.5 Savings links and contributions

- FR-C1: Link a source plan to a target plan (plan funding) or target workspace
  (workspace contribution); one-off or recurring cadence.
- FR-C2: Plan funding destination: target workspace savings account; restricted
  to the target plan.
- FR-C3: Workspace contribution destination: target operating account;
  unrestricted; reported as a member contribution.
- FR-C4: Modes: envelope (no account movement) or transfer (ledger entries);
  per-link anonymous and auto-confirm flags.
- FR-C5: Each period generates planned contributions; source budget reserves
  them; target shows pledged and funded.
- FR-C6: Confirm/skip a contribution; confirm creates the transfer/envelope and
  updates funded; skip releases the source reservation.
- FR-C7: Alert at funded ≥ expected; unlink or keep for buffer.
- FR-C8: Same-currency links only in MVP; schema has fx_rate for later.

### 9.6 Analysis

- FR-AN1: Plan/period: budget vs actual by category; remaining; pace.
- FR-AN2: Savings: expected, pledged, funded, spent, available.
- FR-AN3: Workspace: totals and per-plan breakdown; earned income vs member
  contributions.
- FR-AN4: Cash flow: ledger by account/kind; debt outstanding; due amounts.
- FR-AN5: Period comparison; top categories; largest expenses.
- FR-AN6: Accrual and cash views visible; accrual is the primary budget number.

### 9.7 UX

- FR-U1: Desktop: Tools → Finance; finance sub-sidebar with workspace selector
  and Overview/Budget/Expenses/Analysis/Settings; plan+period selectors in the
  content header; one workspace selector only.
- FR-U2: Create plan from the plan-selector dropdown (`+ New plan`) and from the
  empty state; plan creation generates the first period.
- FR-U3: Mobile: app-local bottom tab bar + add-expense FAB; workspace/plan
  selectors in the header; no sub-sidebar.
- FR-U4: Portal components/tokens: Inter, mono for money, 8px/6px/4px shape
  grammar, neutral surfaces, violet primary/active only.
- FR-U5: All themes and light/dark modes supported.

## 10. Permissions

| Action | Read scope | Write scope | Workspace role |
| :--- | :--- | :--- | :--- |
| View workspace/plans | `finance:read` or `finance:workspace.read` / `finance:plan.read` | — | member |
| View expenses | `finance:expense.read` | — | member |
| View analysis | `finance:analysis.read` | — | member |
| View contributions | `finance:contribution.read` | — | member |
| Create/edit plans, categories | — | `finance:plan.write` | member |
| Edit budget/commitments | — | `finance:budget.write` | member |
| Add/edit/delete expenses | — | `finance:expense.write` | member |
| Create/confirm contributions | — | `finance:contribution.write` | member |
| Invite/remove members, roles, archive workspace | — | `finance:workspace.manage` | admin |

`finance:read` implies all granular read scopes. There is no broad write scope.
A member with only read scopes behaves as a viewer.

## 11. Non-functional

- **Privacy:** finance rows are scoped to workspace membership; no email or
  identity directory in finance payloads. A single-member workspace is the
  private boundary. No per-expense privacy.
- **Performance:** keyset pagination, indexed aggregates, header totals, no
  N+1; designed for growth beyond five users; no impact on other DB users.
- **Availability:** online only; no offline queue in MVP.
- **Accessibility:** keyboard, focus, labels, contrast in every theme/mode;
  money in tabular mono.
- **Operability:** cms-plane app; no new database/DSN; migrations new files;
  admin scope seed; release with lumen then mellon.
- **Extraction:** API is versioned, bearer-authenticated, workspace-scoped,
  DTO-based, idempotent on create; no mellon/session coupling beyond the
  bearer.

## 12. Scope

**MVP:** workspaces/members/invites; plans (recurring/fixed) and periods;
plan-specific categories; per-period budgets and copy policy; accounts; income
(planned + actual); expenses/baskets; plan funding and workspace contributions;
credit-card/loan ledger; analysis/accrual+cash; desktop and mobile shell;
scopes/roles.

**Later:** barcode lookup and scanning; FX/per-plan currency; offline mobile;
dedicated mobile auth/token strategy; receipt attachments; recurring-expense
automation; budget/debt notifications; CSV import/export.

## 13. Success measures

- A five-member household can set up a monthly plan and add an expense in under
  two minutes each.
- A vacation plan can be funded from a personal monthly plan with a visible
  funded/expected progress and no double counting.
- The overview remains responsive with 5 users, multiple plans, and years of
  expenses; all list endpoints paginate.
- The finance UI is indistinguishable from the portal in type, shape, colour
  and interaction grammar.

## 14. Open questions

- Dedicated mobile auth: the current session is a 12h bearer; a native app will
  need a refresh/passkey strategy. Not in MVP.
- Workspace contribution's expected amount is shown at workspace level; whether
  it should auto-populate a specific plan's planned income is deferred (see
  Tech Spec §5.7).
- Cross-workspace FX and per-plan currency are schema-ready but not built.
- Barcode provider/key and iOS scanning fallback are deferred.
