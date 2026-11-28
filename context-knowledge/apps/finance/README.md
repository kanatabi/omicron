---
tags: [finance, index, plan]
updated: 2026-11-29
status: draft
---

# Finance app — document set

Promoted from the Plan directory on 2026-11-29. The document set lives at:

- `context-knowledge/apps/finance/PRD.md`
- `context-knowledge/decisions/finance-app.md` (the ADR)
- `context-knowledge/apps/finance/TECH_SPEC.md`
- `context-knowledge/apps/finance/PLAN.md`
- this README

## Documents

| Document | Purpose |
| :--- | :--- |
| [PRD](PRD.md) | Product requirements, personas, journeys, functional/non-functional requirements, MVP scope |
| [ADR](../../decisions/finance-app.md) | Architecture design review: decisions, alternatives, consequences, review checklist |
| [Tech Spec](TECH_SPEC.md) | Concrete schema, ledger rules, API contract, migrations, frontend, performance, testing |
| [PLAN](PLAN.md) | Milestone breakdown M0–M8 plus later backlog and risks |

## Locked product decisions

- Workspace = arbitrary membership group; one-member workspace is private; no
  per-plan/per-expense ACL.
- Workspace → Plan (recurring or fixed) → Period; plan-specific categories;
  per-period budgets; copy policy `none|all|recurring_only` + per-category
  recurring.
- Expenses are per plan/period; baskets are one purchase with item-level
  categories; manual entry only.
- Accounts are workspace-level; ledger entries are actual money; budget lines
  are the plan. Income is planned per period + actual at workspace level.
- Contributions: plan funding (restricted, target savings account) and
  workspace contribution (unrestricted, target operating account); cross-
  workspace; envelope/transfer; anonymous; auto-confirm; one-off or recurring.
- Full liability: card purchases are expenses, card payments are transfers,
  loan instalments are debt payments + interest; accrual and cash views.
- Scopes: broad `finance:read` implies granular reads; writes granular only;
  roles admin/member; last-admin guard.
- IDR-only MVP; per-plan currency/FX schema-ready.
- Barcode, offline, native app, and FX are later.

## Open decision (one)

Automatic expected **workspace contributions** are currently specified at the
workspace-overview level (expected vs actual). A workspace can have multiple
plans, so the documents do not auto-inject the expected amount into a specific
plan's `planned_income`. If the owner wants it inside a specific plan, we need to
choose an **operating plan** (e.g. a plan flagged as the workspace's operating
budget) and make the expected contribution part of that plan's planned income.
See PRD §14 and Tech Spec §5.7. This is the only remaining product ambiguity.

## Design reference

[Flowstep — Finance](https://app.flowstep.ai/file?activeFileId=c92688f2-4123-4448-9d3f-1eb4864d3f60)
(desktop overview/budget, mobile overview/basket; portal restyle pass done; the
mobile selects/chips still need the 8/6px shape pass in code with the real
portal components).
