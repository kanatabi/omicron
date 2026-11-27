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

## A note on the passkey login (the auth-method seam, C1)

 mellon's login screen gained **Login with passkey** beside the password form
 (WebAuthn — the private key lives in your authenticator: Bitwarden, iCloud, a
 key). Operationally it needs TWO optional env keys on the lumen-admin pod:
 `LUMEN_WEBAUTHN_RP_ID` (the REGISTRABLE DOMAIN — `gofar.id`: one shared
 lumen-admin serves every environment's mellon, so the registrable-domain
 rp-id lets console AND staging-console run the ceremony against the same
 credentials; a staging-registered passkey is offered on production too) and
 `LUMEN_WEBAUTHN_ORIGINS` (comma-separated browser origins, e.g.
 `https://console.gofar.id,https://staging-console.gofar.id`). BOTH unset =
 the feature is OFF and the login page's button degrades gracefully (lumen's
 methods endpoint omits it). Local dev: `LUMEN_WEBAUTHN_RP_ID=localhost` +
 `LUMEN_WEBAUTHN_ORIGINS=http://localhost:5173` (the origin must include the
 dev PORT). The first passkey is registered from the Security settings page
 (authenticated), then the login button works. The real-db ceremony was
 proven by the fake-authenticator integration test; the browser walk is the
 last-mile QA item.

### The browser walk (and the failure modes that bit)

Deploy order is the usual ladder — the admin plane (`foundation` chain)
FIRST: without its WebAuthn env every passkey route answers
`no such method`, and no mellon release can change that. Then mellon.
The walk: Settings → Security → **Add a passkey** → name it → the
authenticator prompt (`"name" is ready — use it on the login screen`),
then sign out → **Login with passkey** → the server's destination (the
portal, or `/setup?change=1` for a temp-password account).

The three failures this round produced, in the order they bit:

- **400 `no such method` on Add** — lumen's unconfigured-feature 404: the
  admin pod has no relying-party identity. Check
  `kubectl logs -n lumen deploy/lumen-admin-http-server | grep webauthn`
  (`not configured` = the env never arrived; the fix is the ES + epoch
  flip, not mellon).
- **`can't access property "publicKey", r is undefined`** — mellon read
  Kit's action ENVELOPE instead of its payload. `fetch('?/action')`
  answers `{type,status,location,data}`: the value is `data`, never the
  body itself. Fixed as a seam (`#lib/action-post.ts`, 2026-11-27).
- **the same message AGAIN after the envelope fix** — the envelope is
  TWO layers deep: `data` is a **devalue STRING** (Kit serializes the
  action's return with `stringify`; the client half is `deserialize` =
  JSON.parse + devalue.parse). The seam now decodes both success and
  failure payloads, and the battery builds every fixture through
  `devalue.stringify` — a hand-built plain-object fixture hides exactly
  this bug.
- **401 "invalid credentials" on login, while the admin log says
  `BackupEligible flag inconsistency`** — the credential row predates
  0013: the store kept no WebAuthn flags, and a SYNCED passkey
  (Bitwarden/iCloud) is BE=1, which the library compares on every login.
  Delete that passkey and re-register it after the 0013 deploy; the
  browser only says "invalid credentials" — the admin log is the truth.
- **`passkey ceremony incomplete`** — the finish action parsed
  `request.json()` while the client sent form fields (the 415 fix moved
  only the client half). Both halves of a wire move in one commit.

## The tasks application + notifications (the app-center, 2026-11-27)

The first lumen-native application: projects → tasks, with invites,
comments, a timeline and a stats rollup, plus the estate-generic
notification bell. **Admin plane only** — the cms fleets never mount these
routes and their databases never own the tables.

**Scopes.** `0014` seeds `tasks:create|update|manage` into the portal's
catalog. GRANT them through the portal (Users → scopes) — no migration
grants privileges. Reads and invite acceptance require ANY of the three;
creates need `create`; task edits/comments `update`; project settings,
invites, members and roles `manage`. Inside a project the member ROLE is
the second key: a `manage` holder who is not a project admin still gets
403 on that project's settings.

**The project rules the portal relies on.** Soft delete only
(`deleted_at` on projects/tasks; live lists filter), completion is a flag
(`completed_at`), there is no ordering column (the portal sorts), many
admins per project with the last-admin 409 guard, member removal
unassigns their tasks, an assignee must be a member, and deleting a user
promotes the next member (or soft-deletes a memberless project) through
the lifecycle hook after the user row is gone.

**Time.** `GET /admin/tasks` and `/admin/task-stats` read
`X-Client-Timezone` (IANA; UTC fallback). "My day" = due today + open
overdue; "this week" is Monday-start in the client's zone. The binary
embeds the zone database — the alpine image has none.

**Notifications.** `expires_at` is the TTL (30 days; an invite's
notification rides the invite's 24h). There is NO purge job yet (owner:
hold): every read filters `expires_at > now()`, so expired rows are
invisible but remain in the table. A future janitor will be in-process or
a CronJob — never River-periodic here (the admin plane runs no worker).

The SEND door (`POST /admin/notifications`) is app-to-app, in-cluster,
and gated by ONE shared token from the MANUAL Secret
`lumen-notification-token` (optional; env-only — not a config binding,
not a Bao/ES value, so no epoch flip):

```
kubectl -n lumen create secret generic lumen-notification-token \
  --from-literal=LUMEN_NOTIFICATION_TOKEN="$(openssl rand -base64 32)"
kubectl -n lumen rollout restart deploy/lumen-admin-http-server
```

Unset = the route is not mounted (a POST answers 405 on the GET sibling).
Rotate by replacing the Secret and restarting (read once at boot). The
audit lines carry app/type/counts/ip — never the token, title or body.

**Deploy.** The lumen release's `deploy-foundation` chain carries this to
the admin plane; the cms chains are unaffected. The envFrom that lets the
pod SEE the token lands with the vortex
`feat/notifications-token-secret` branch — merge it before creating the
Secret.

## Where the other docs live

- **Contract** (field semantics, canvas geometry, invariants):
  mellon `DESIGN.md` §11.4 — "The widget home".
- **History and scars** (every bug this machinery survived):
  the omicron vault → `context-knowledge/repos/mellon/README.md`.
