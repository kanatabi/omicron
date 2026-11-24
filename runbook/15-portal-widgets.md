---
tags: [runbook, mellon, portal]
updated: 2026-11-25
status: >-
  reference — the walkthrough matches the coordinate model as built
  (mellon 66ab9ed + the gutter and float fixes through b3842a1). Every
  file path and field below is live code; the CONTRACT this walkthrough
  follows lives in mellon DESIGN.md §11.4 (the widget home), the
  history and scars in the omicron vault's mellon note.
---

# 15 · The Portal's Widget Home — adding a widget to mellon

> **Why this chapter:** mellon's `/` is the owner's personal app center
> — a per-user, customizable widget canvas (the Grafana "custom grid"
> model). Adding a widget costs **one folder + one registry line** —
> nothing else in the codebase changes. This chapter walks that
> procedure end to end; the design contract lives in mellon's
> `DESIGN.md` §11.4.

## The mental model (one screen)

- The dashboard is a **coordinate canvas**: every widget carries
  `{ id, x, y, w, h }` on a **24-column** canvas of **44px rows**.
  Percent columns keep it responsive; holes stay holes.
- The **registry is the plugin seam**: `mellon/src/lib/dashboard/widgets/registry.ts`.
  The canvas, the card shell, the tray, the layout store, the
  persistence, and the collision engine all read the registry — and
  nothing else. Adding a widget touches ONLY the registry plus a folder.
- `scope` gates the **mount**: a widget whose scope the signed-in user
  doesn't hold never mounts, and its data calls never fire. `undefined`
  = any authenticated user.
- **Placed-or-absent** (schema v4): the canvas holds only placed
  widgets. Deleting a panel removes it entirely — the picker offers it
  unselected again (re-add gives the default span at the first free
  slot; the old position is not kept, the Grafana rule). Each user's
  arrangement persists per-user (localStorage behind a storage seam —
  a server table is the recorded second implementation), and a
  brand-new user's canvas auto-adds the widgets their scopes allow.

## The walkthrough: five steps

### Step 1 — create the widget folder

```
mellon/src/lib/dashboard/widgets/<id>/body.svelte
```

`<id>` is the widget's identity **forever** — it keys the persisted
layout, so pick a kebab-case name and never rename it. Existing
examples: `recent-posts/`, `recent-photos/`, `recent-tags/`.

The body component's contract (it has **no props**):

- **Self-contained data**: fetch what you show through the shared relay
  client (`import { client } from '#lib/api/client.ts'`) in an
  `onMount` — the dashboard page's server load dials **no** scoped API
  on purpose (a scope-less user's home must render, never error — the
  500-cliff rule).
- **Own states**: render your own loading skeleton, your own error line
  (`role="alert"`, lumen's copy verbatim — the relay honesty rule), and
  your own empty state.
- **Own business only**: never import or touch the layout store, the
  grid, or other widgets. Content taller than the card scrolls inside —
  the card's body area is `overflow-y-auto`.
- **Style like the others**: `text-sm` titles, `font-mono text-[10px]`
  meta lines, `truncate` on anything that can overflow. The card shell
  already carries focus, ARIA labels, and the keyboard handlers.
- **Don't swallow the grid keys**: `Alt+arrows` (move) and
  `Shift+Alt+arrows` (resize) are the card's handlers; links and buttons
  inside the body are fine.
- **Honor `preview`**: the body takes an optional `preview` prop — when
  set, render the widget's REAL structure with placeholder shapes
  (skeleton bars in the real row layout, real chrome like a status
  pill) and NEVER fetch. The Add-Widget panel mounts bodies in preview
  mode so the user sees the shape they'll get at zero relay cost.

### Step 2 — register it (ONE entry)

In `mellon/src/lib/dashboard/widgets/registry.ts`, add one entry to
`WIDGETS`:

```ts
{
  id: '<id>',                       // forever — the layout key's identity
  title: 'Budget summary',          // the card's header (uppercase, small)
  description: 'the family budget, month to date',
  href: '/budget',                  // optional — the "see all" door
  scope: 'budget:manage',           // optional — a lumen scope; omit for everyone
  defaultSpan: { col: 6, row: 6 },  // first placement: col = 1/24 canvas, row = 44px units
  minSpan: { col: 2, row: 2 },      // resize/nudge clamps
  body: BudgetBody                  // the component from Step 1
}
```

Field semantics:

| Field | Meaning |
| :-- | :-- |
| `id` | kebab, unique, **never renamed** — persisted layouts reference it |
| `href` | optional deep link; omit when there is no desk to summarize |
| `scope` | a lumen scope string from the catalog (§ settings/scopes); unheld ⇒ never mounts |
| `defaultSpan.col` | canvas columns — the canvas is 24 wide, so `6` = a quarter, `12` = half |
| `defaultSpan.row` | row units — each is a 44px track (plus the 16px gap) |
| `minSpan` | the resize and keyboard-nudge clamps (the owner runs `{2, 2}` today) |

### Step 3 — nothing else. Really.

Reconcile handles the rest at load: an unknown id **drops** and spans
**clamp** — but unplaced widgets are NOT auto-appended (deleted stays
deleted). Adding is the picker's verb: the **Add Widget** button opens
the side panel (static previews — the real bodies never mount there,
so opening it fires zero relay calls), rows multi-select, and the
footer commits the whole selection; each lands at the first free slot
via `firstFit`.

### Step 4 — the data behind it

If the widget needs a call that doesn't exist yet, add it to the API
mirror first (`src/lib/api/types.ts` + `fetch-adapter.ts` + the fixture
twin for tests) — same rules as every relay call: the browser never
sees lumen or a token, and unknown paths refuse loudly
(`routing.ts`). Existing content calls (`listPosts`, `listPhotos`,
`listNewestTags`) are already wired.

### Step 5 — gates and close-out

```
cd mellon
npm run lint && npm run check && npm run test:unit && npm run build
```

Then the workspace ritual (chapter 09 has the full ceremony):
branch → squash-merge to `main` → push → bump the omicron pin → update
the vault's mellon note (the same-round rule). New scope? That's a
lumen catalog change — chapter 06's app flow plus the RBAC spine
decision record in the vault's decisions tier, never manual SQL.

## The pitfalls that earned their scars

- **The `/` server load must stay API-free.** The dashboard once dialed
  four scoped APIs at the door and 401'd per probe forever; widget
  bodies fetch client-side, and only when mounted.
- **An effect must never read the $state it writes** — the layout
  store's `init()` runs once per username and never reads its own
  write (that loop depth-exploded every hydration once).
- **A preview that lies is worse than no preview**: resize previews
  clamp to the same bounds the commit enforces.
- **Never unmount a drag source mid-drag** — the browser fires
  `dragend` on the source; the card shell's machines already handle
  this, which is one more reason bodies stay inside the shell.

## Where the other docs live

- **Contract** (field semantics, canvas geometry, invariants):
  mellon `DESIGN.md` §11.4 — "The widget home".
- **History and scars** (every bug this machinery survived):
  the omicron vault → `context-knowledge/repos/mellon/README.md`.
