---
tags: [mellon, lessons]
updated: 2026-11-25
---

# mellon — lesson ledger

The standing doctrine lives in the repo's
[DESIGN.md §2](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) and its
[AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md). This

- **2026-11-24 — the widget home: three layers, one plugin seam.** The
  dashboard became the user's home (Round A, `9fc0eeb`): the grid, the
  card shell, and the widget BODIES are separate — **a widget is a
  folder + a registry line**, and the registry is the only thing the
  grid/store/persistence read. The layout is DATA (id/span/hidden)
  reconciled against the registry at read (unknown ids dropped, new
  widgets appended — the theme-registry drift pin, reused) with spans
  CLAMPED to grid+minimum. **The scope gate sits above persistence:**
  an unheld scope means the body never mounts, its calls never fire —
  lumen's truth over the browser's memory. **The server load dials no
  scoped API** — that was the 500 cliff; the bodies fetch client-side.
  And the storage seam (localStorage behind an interface) keeps the
  future server-side per-user layout a second implementation, not a
  rewrite. Remaining honest gaps: the pure test's place expectations
  were wrong twice before the run went green (place-before keeps
  order; sanitize filters rather than rejects) — read the failures,
  don't trust the first expectations.
- **2026-11-24 — resize round (B): measure, don't assume; and happy-dom
  realities.** The corner grip emits PIXEL deltas and the GRID converts
  them to spans (the card stays dumb) — but the column unit must be
  MEASURED from the card's own rect, never assumed, and the row unit is
  a FIXED 88px track (`grid-auto-rows`) because resize math needs a
  constant. Preview applies live WITHOUT persist; the release persists
  once. **happy-dom lessons (three failures → three pins):** keyboard
  events must dispatch on the element that OWNS the handler (the
  article, not the grid wrapper — events propagate up, never down);
  happy-dom's KeyboardEvent init drops modifier getters — define
  `key`/`shiftKey`/`altKey` on a plain Event via `defineProperty`; and
  a fixture asserting a reflow must hold its entries in `$state` — a
  plain const swallows the write. Also: half-applied batch edits leave
  THREE files inconsistent — after a failed assert mid-batch, re-read
  every file the batch touched before the next edit.
- **2026-11-24 — an effect must never read the $state it writes (the
  depth-exceeded loop).** The owner's console: `effect_update_depth_
  exceeded` on every dashboard hydration. Cause: the page's `$effect`
  calls `init()`, which assigned `this.entries` and then READ it back
  for the storage save — that read registered the effect's own write
  as a dependency, so the next run's write re-triggered it: a
  self-sustaining loop. Two-part fix in `dashboard.svelte.ts`
  (70a940f): init never touches `this.entries` (a local carries the
  reconciled array to both the assignment and the save) and init runs
  ONCE per username (`loadedKey` guard — per-user init is not a
  per-navigation one). **The regression pattern worth copying:**
  `store-fixture.svelte` mounts the page's EXACT shape (an effect whose
  call writes state) — reverting the fix failed 3/3, applying passed
  3/3, so the test provably guards the bug. **And the diagnostic trap
  the owner fell into: "restart the server" cannot fix a client-side
  state loop — match the error's stack to a layer before reaching for
  the restart lever.**
- **2026-11-24 — the gesture split: a draggable parent swallows pointer
  gestures on its children.** The corner grip "became" drag-and-drop:
  the article is the HTML5 draggable (the reorder source), and a
  press+move on ANY child seeds a native drag — pointer capture cannot
  prevent that (drag initiation lives below the pointer-event layer).
  Fix (7b66076): the resize zones are drag-immune three ways —
  `draggable="false"` (never a seed), `pointerdown` `preventDefault`
  (kills the compat mousedown that seeds one), and a `dragstart` trap
  (`stopPropagation` + `preventDefault`) as belt-and-braces. **And the
  compounding-delta bug it uncovered: a resize callback must carry
  ABSOLUTE targets, not deltas — deltas measured from drag START
  applied against the LIVE span compound (right-drag = instant
  full-width). The reference is the drag START geometry, never the
  live state the drag itself mutates.**
- **2026-11-24 — the smoothness round (B3): three interlocking machines,
  and a silent no-op class.** (1) **A CSS hook that exists but is never
  referenced is a silent no-op** — the grid div never carried
  `data-dashboard-grid`, so the fixed-row CSS (`grid-auto-rows`) had
  done nothing since Round B; the build was green the whole time.
  Attribute hooks need an assertion that the styled element carries
  them (the grid now does, and the geometry parser reads it). (2) The
  Grafana feel = fine steps + NO reflow mid-drag: the grid doubled
  (12/24 cols, 44px rows — `migrateLayout` scales stored layouts ×2 and
  stamps `version: 2` so the ×2 happens exactly once; sanitize must
  PASS the version through, not strip it — stripping would re-scale
  every load), the card floats pixel-continuously while the grid holds
  a PROVISIONAL span (never applied mid-drag) and renders the blue
  placeholder from track geometry parsed once per gesture. (3) The
  reorder ghost is the post-editor sidebar's machine on the grid: the
  card leaves the flow, a ghost item opens the landing slot, drop lands
  into it — and FLIP (WAAPI: snapshot rects, invert, play) animates
  every layout change. **Test-infra pins:** a `<script module>` fixture
  shares state across tests — keep per-test state in the INSTANCE
  script; happy-dom drops `clientY` from DragEvent init the same way it
  drops KeyboardEvent modifiers — define it on the instance; and the
  old `':after'` marker was parsed with `split(':after')`, whose result
  can never equal `'after'` — 'below midpoint' silently placed before
  (the new `beforeIdOf` maps the marker honestly).
- **2026-11-24 — the snap-back and the vanishing panel (02710c8), the
  owner's real-browser reports.** (1) **A preview that lies is worse
  than no preview:** the resize float and provisional targets had no
  upper clamp — they promised sizes beyond the grid's own ceiling
  (GRID_COLS × MAX_ROW_SPAN), and the release "corrected" the lie
  (the card visibly snapped smaller). Clamp the preview to the same
  bounds the commit will enforce — the preview and the persisted value
  must come from ONE arithmetic. (2) **Never unmount a drag source
  mid-drag:** the browser fires `dragend` on the drag SOURCE; once
  detached (the old machine replaced the card with the ghost), the
  end-handling never runs, `dragId` sticks, and the card stays hidden
  until a remount — the owner's "clicked the grip, panel gone until
  refresh". Fix: keep the source mounted, `display:none` in place (the
  gap still closes; the component and its fetch survive), ghost as a
  sibling, plus a document-CAPTURE dragend listener as the guaranteed
  net (dragend does not bubble; capture still descends to a connected
  target; and it fires AFTER drop, so it can never pre-empt the
  landing). FLIP must skip 0×0 rects — hidden elements would animate
  from the top-left corner. (3) **Process pin: never sweep unexplained
  working-tree changes into a commit** — an owner hand-edit to the
  registry's minSpans rode into a fix commit unnoticed because whole
  directories were staged; stage the files the round touched, and ask
  about anything else.
- **2026-11-24 — the coordinate model (Round C, 66ab9ed): the layout
  core became the Grafana classic schema.** Every widget carries
  `{ id, x, y, w, h, hidden }` on a 24-column canvas of 44px rows —
  free placement, holes stay holes. The engine lessons: **(1) gravity
  must preserve the store's array order** — process sorted top-down,
  write back in input order, or the tray's listing churns. **(2) A
  hand-edited store can lie about its version stamp** — migrate by
  SHAPE (`'x' in entries[0]`), not by stamp. **(3) With gravity, a drop
  onto "between two stacked widgets" legitimately re-settles the
  stack** — the moved item rises to its free slot; don't write tests
  that expect gravity to respect a mid-air target. **(4) Test fixtures
  must keep their state in the INSTANCE script** (module scope bleeds
  across tests — bitten twice now). **(5) Revert-proofs must stash the
  MACHINERY, not the tests** — stashing the whole test dir proves
  nothing. The drag machine: HTML5 DnD retired entirely (one pointer
  gesture system — the native-drag hijack class is structurally
  impossible now); the card header is the handle with a 4px click
  threshold; the wrapper pointer-follows in px while the store previews
  the RESOLVED shadow layout (`view = $derived(resolveDrop(...))`) so
  other widgets glide out of the way through their position
  transitions; release persists, Escape cancels. **And a process slip
  caught and recovered: C1 was committed straight to main — park on a
  branch, `reset --hard` main back, squash-merge properly; the pin
  ritual has no fast-forwards and no direct commits.**
- **2026-11-25 — Round D (f985b2a): placed-or-absent — the schema, the
  picker, and the semantics that follow.** The availability model
  changed: a widget is PLACED or ABSENT — schema v4 drops `hidden`
  (the migration chains v2 → coordinates → strips hidden; v3's
  unpinned entries DELETE under the new model). **The load-bearing
  semantic: reconcileLayout must NOT append unplaced registry widgets**
  — that Round A behavior would resurrect deleted panels on every
  reload; appending is the explicit `add` verb via `firstFit` (fills
  the first free slot — holes before growth, matching the picker's
  promise). The picker's previews mount REAL bodies in `preview` mode
  (the contract: every body honors the prop — render the structure,
  never fetch; the fetch-spy test proves opening the panel fires ZERO
  relay calls). The owner's calls are recorded in the contract: delete
  without confirm, first-run seed, static previews → then the
  structure-preview upgrade the same day. **And a hazard with teeth:
  a stash pop whose pathspec misses a file leaves MERGE CONFLICT
  MARKERS in unrelated files (tsconfig.json sprouted markers during
  the Round D revert-proof) — after any stash dance, grep for `<<<<<<<`
  before trusting the tree.**
- **2026-11-24 — the mobile header (26c2c1f): percentage-of-viewport
  thinking beats squeezing.** The Dashboard title + two pill buttons
  sat in one non-wrapping flex row — the buttons overflowed the phone
  viewport (horizontal scroll) and wrapped their own text. The fix is
  the standard pattern: stack on mobile (title, then the two buttons
  side by side — both fit at 375px), `whitespace-nowrap` on the pills,
  back to one row at sm+. Smaller lesson from the same day: the posts
  preview's placeholder bars collapsed to zero width — percentage
  widths inside an indefinite flex-parent need the parent to say
  `flex-1` (the tags preview dodged it with fixed widths; the pins are
  structural, since happy-dom computes no flex layout).
- **2026-11-25 — the docs round (439fa07): the walkthrough found its
  tier.** Adding a widget now has a dedicated runbook chapter (ch. 15)
  at the owner's request — a DEVELOPMENT procedure in the runbook is a
  deliberate tier amendment (recorded in doc-map.md), not a tier
  violation: the runbook's shape (junior-readable, exact commands, a
  close-out ritual) IS the walkthrough's shape, and single-homing
  holds — runbook ch. 15 = the walkthrough, mellon DESIGN §11.4 = the
  contract, the vault = the history and scars. The docs audit also
  caught the stale voices: the vault's §1c was a two-round patchwork
  (Round A text contradicting the coordinate paragraphs) and DESIGN's
  `/` route row still described the pre-widget-home mega-load — both
  rewritten to the coordinate reality, and the local plan-file pointer
  dropped for links a contributor can actually open.
- **2026-11-24 — the resize float's minimum-size grab (b3842a1): a
  rename smuggled a unit change past the tests.** The C-round prop
  rename (colSpan/rowSpan → w/h) made the machine's `start` capture the
  GRID-UNIT counts where the float arithmetic needs PIXELS — corner
  grabs collapsed to `max(minW, 12 + pixels)` (the minimum the owner
  saw), and edge modes rendered literally 12px. Fix: `start` carries
  BOTH worlds explicitly — pxW/pxH (the float's reference) beside w/h
  (the target arithmetic). **The pin: a rename is a semantic change —
  re-audit every consumer of the renamed value, not just the compiler
  errors.** The regression needed honest pixel geometry: happy-dom's
  zero rects cannot tell pixels from grid units, so the dom file mocks
  `getBoundingClientRect` for the canvas and card (restoring the
  dropped edge-lock test with exact values in the bargain).
- **2026-11-24 — the canvas gutter (0d216af): absolute placement
  removes the grid's gap for free.** The coordinate canvas tiled cells
  perfectly (x + w = next x) — neighboring widgets TOUCHED. The fix is
  the react-grid-layout margin rule: the CELL pitch is
  `(canvasWidth + gap) / 24` and each widget renders one gap narrower —
  adjacent cells keep exactly one gap, a full-width widget still spans
  the canvas exactly. The ROWS already followed this shape (that's why
  vertical gaps always worked) — the bug was only ever the columns.
  Responsive `calc()` (percent + px gap) keeps the browser re-deriving
  on resize without JS. **Rule: when absolute placement replaces a
  gapped grid, the gutter must move INTO the geometry — every consumer
  (entries, placeholder, drag pitch) shares one pair of helpers.**
- **2026-11-24 — the portal renders lumen's scope truth; it never
  enforces.** The RBAC wire flip (f9d0c53): `Principal` carries id+scopes
  (role is GONE), every role-shaped consumer was swept (the nav's Admin
  group, the settings shell's Users door, the /admin/users gate, the
  account menu's label), and the users page became the grant surface —
  the scope picker IS the creation grant, the per-user editor REPLACES
  the set (the copy says the user's other sessions die: lumen bumps
  token_version on every scope mutation). The catalog card makes scope
  onboarding a portal action; lumen's delete-refusal (409 with the holder
  counts) renders VERBATIM — the ghost-field doctrine applies to a
  permission refusal exactly as it did to a pin lock. And the dev-loop
  rule the bug taught (2026-11-24): **the two halves of the wire
  hot-reload on different clocks** — mellon's Vite reloads in seconds,
  lumen's Go binary needs a restart; when the wire flips, restart BOTH
  halves before diagnosing (the gates now degrade on a scopes-less whoami
  instead of 500ing the portal). The nav-scope round (`975cce2`): **the
  menu shows only what the principal may open** — the rail's groups
  declare their requirement as data, empty groups collapse, the palette
  inherits the same honesty (its rows arrive from the mounted page), and
  the courtesy gates in each section's page server land a bookmarked URL
  on the dashboard — affordance, not enforcement, in the honest order.
  The CI lint's second catch (`6b55b9c`) — requireScope's unused url
  param and the dead KeyRound/Plus imports — and the confession, third
  repetition: **a gate whose output you summarize is a gate you didn't
  run, and a batch that can't show its gate output verbatim hasn't run
  it either.** The standing rule is now absolute: every gate, full
  output, every time — no exceptions for "short" fixes. The Scopes
  section round proved the rule PAYS (`2623721`): the courtesy gate was
  imported but never wired (an unused import was the only visible
  symptom of a page that would have let any authenticated user read the
  catalog through the 403-less door), and the lint caught it before a
  deploy could.
- **2026-11-23 — the adapter's knobs are read at IMPORT — image-level ENV
  or nothing.** `BODY_SIZE_LIMIT` is evaluated when `build/handler.js` is
  statically imported, so a `server.js` assignment is too late (no dynamic
  import to pre-empt without churn). The ceiling ships as a Dockerfile
  `ENV` (`110M`, e749f03) — atomically with the code that enforces the
  matching pre-check, so no rollout window exists where the old ceiling
  meets the new offers (and Deployment env can still override it).
- **2026-11-23 — vendor registry items by DIRECT FETCH when the CLI would
  clobber a customized component.** `add attachment` resolves to the vega
  style and works, but its `registryDependencies` includes `button` — and
  OURS carries the cast variants (SHADCN-PLAN 3.1). Fetching the item JSON
  and rewriting `$UTILS$`/`$UI$` to the `#lib` aliases lands exactly the
  component and touches nothing else. Same round: the registry's spinner
  imports `@lucide/svelte` (a SECOND icon lib) — the vendored copy points
  at the project's `lucide-svelte` instead; one icon vocabulary.
- **2026-11-23 — the portal color picker rides the SAME seam as the
  themes: inline style, not a native control.** The stock
  `<input type="color">` could only speak 6-digit hex (every oklch token
  showed the neutral chip). The Figma-anatomy picker
  (`4f51398`): `color.ts` bridges hex↔hsv AND oklch↔srgb (the OKLab
  matrices — pure, round-trip-tested), the chip paints the value ITSELF
  via `background-color: {value}` (CSS renders hex AND oklch natively —
  zero conversion to preview), the picker works in HSV and WRITES hex
  (alpha < 100% earns `#rrggbbaa`), and an unparsable raw value stays
  untouched until a real pick. **Single-open is structural, not
  coordinated:** the page owns ONE `openToken`, each chip's controlled
  Popover reads `open={openToken === tk}` — opening another chip closes
  the previous as a state fact, not a message. And the pointer surfaces
  are real sliders (aria-valuenow/valuetext, tabindex, arrow keys) — a
  drag surface without keyboard is doctrine #4 broken.
- **2026-11-23 — the settings master/detail shell.** The single-column
  settings page died twice: the theme grid alone outran the viewport,
  and "add another setting" had no answer. The shell (`66225a2`):
  `settings/+layout.svelte` = a section nav (sticky column on lg, chips
  on mobile, active by pathname) + slot; sections are CHILD ROUTES
  (`appearance/`, `editor/`, `security/`) whose actions travel with them;
  `/settings` redirects to the first section — **and the redirect keeps
  `requireAuthed`, because the auth-gate guard walks every
  +page.server.ts and the one exception would be the exception** (the
  guard caught its own omission within the round). USERS is a nav item
  that leaves the section, not a card. A new section = a folder + one
  nav entry.
- **2026-11-23 — GENERATED themes: map the palette source, never
  hand-port.** The AnuPpuccin set (24 schemes, `a1b724e`) exists because
  its stylesheets re-express every colorscheme in the Catppuccin variable
  style — one uniform shape, so a script parses → maps onto the CORE
  grammar (a documented per-mode table) → emits the CSS + registry, and
  the registry↔CSS palette test covers all 24 for free. The license is
  part of the artifact: GPL-3.0 demands the credit IN the CSS file.
- **2026-11-23 — per-theme modes beat a global both-modes rule.** The
  moment a catalog includes dark-only schemes (Dracula, Coffee), the
  rule "every theme ships both modes" dies; what survives is
  **`ThemeDef.modes` everywhere**: the segmented renders only the
  current theme's modes, `setTheme` validates the pair, the layout's
  cookie correction flips an impossible pair to an available one. A
  theme+mode cookie must never be able to describe a combination the
  theme doesn't ship — and the rule reaches EVERY consumer of the shape:
  the theme card's hardcoded both-panes killed SSR the moment a
  dark-only theme joined (e947a17). A new field on a shared shape is a
  sweep, not a spot fix.
- **2026-11-23 — an editor for a person, not for its author.** The theme
  editor's first cut was technically honest but owner-unfriendly (the
  report: "too technical"). The restyle (`1e95381`): the MEANING leads —
  every row is a named color (a friendly label map; the token name
  demotes to a subtitle), the picker (with its hex field) is the ONLY
  editor, the raw inputs and the token filter are cut (16 friendly rows
  scan; search loses), and the preview is the CO-STAR — a 420px sticky
  column with a generic portal miniature (chrome bar, card, verbs,
  markers, diff bars). **The copy rule it minted: name the anatomy,
  never the page** — page names drift; helper copy that names them goes
  stale by design. Header: the name IS the title (the rename pattern),
  secondary actions live in the ⋯ (one primary verb, uniform pills). The
  follow-up pass (`45af045`): **the preview panes ARE the light/dark
  switcher** — a button per pane (aria-pressed, the theme-card grammar)
  selects the half being edited, so the control you look at and the
  control you click are the same thing; `preview live` became a ⋯-menu
  CheckboxItem (the diff page's 'Changed only' pattern) and the editor
  split 50/50 with full-width panes. The second correction (owner:
  "over-stretched, kayak pipih"): the width reverts and the pane grows
  by ANATOMY instead — **the miniature is the COMPLETE token inventory**
  (chrome bar, card + input on background, muted strip, the accent hover
  row, the marker list rows, the diff bars), so every token has a
  judgeable surface in both modes; a pane stretched wide shows off
  nothing a content-rich pane at its natural width doesn't show better.
  The pane became ONE shared component (`5a9df37`): **`ThemePane` paints
  the COMPLETE token inventory for the theme card AND the editor** —
  the card showed 8 tokens while the editor showed 16, two truths about
  the same theme; and a preview that omits keys inherits the WORN theme
  and lies, so the preview grammar is the full CORE list by
  construction. The appearance section followed: the MODE control leads
  the header (it flips what the grid shows), 4-up portrait cards, panes
  stacked full card width. The stacking lasted one pass (owner: every
  card a paired poster): **the variant lens lives IN the card's header**
  (`3b82dd9`) — one pane per card, a mini segmented flipping a LOCAL
  preview (default = the worn mode, clamped to the theme's modes; it
  never writes the cookie — a preview lens is not a mode write), and
  single-mode themes say so in plain text. And the round's own lesson
  (`135a660`): the mode control's move to the header was ANNOUNCED in
  the pane round but its edit script hit a failed assert before writing
  the file — only the grid sed survived. **A multi-edit script that
  asserts per-step must not lose the earlier steps' writes to a later
  failure** — write per-file immediately, or verify the end state, not
  the intention. The round AFTER that: the CI lint caught three loose
  ends my local gates "passed" — because the runs were TAIL-piped
  (`npm run lint 2>&1 | tail -1` shows only the prettier line). The
  standalone-gates rule was repeated, and the repeat is its own lesson:
  **a gate whose output you summarize is a gate you didn't run.** Plus
  the shape rule it surfaced: an svelte-ignore directive ends at the
  code name — trailing prose parses as more ignore codes.
- **2026-11-23 — a picker control that IS its own indicator.** The
  opacity row was three disconnected pieces (a visual bar, a native
  range beside it, a % label) — the thumb didn't live on the track it
  described. One pointer-captured track now (the hue-bar pattern),
  thumb riding it. And the swatch row's wrap taught the labeling rule:
  **two sources wearing the same costume read as one** — THEME and
  RECENT are separate labeled lines now (the same leading-gutter
  grammar as OPACITY), with the remember-+ at the END of the recents
  line, where "add the current color" reads. The polish walks
  (`c854077`): **a thumb bigger than its track must travel INSET by its
  own radius** — and the track's overflow-hidden belongs to the gradient
  child, not the track, or the thumb gets shaved at the ends; and a
  fixed-item row in a fixed-width popover WRAPS (7 per line, the 8th
  below), it never overflows. The crispness pass (`8be1dc3`): **1px
  borders alias blocky at fractional zoom — circles wear inset RINGS
  (painted post-transform) and hovers change rings, never
  `hover:scale-*`** (a transform resamples the raster); and a
  checkerboard at swatch size wants 4px/20% tiles, not 8px/30%.
- **2026-11-23 — an effect must never READ a `$state` it also writes.**
  The theme editor's seed effect assigned `tokens`/`computedBase` and then
  read them in the same run (building `forkBase` from the just-written
  tokens, the `new` branch from the just-written `computedBase`) — every
  read in an effect is a dependency, so each run re-triggered itself until
  `effect_update_depth_exceeded` killed the page (the owner's 500). The
  pattern that holds: **compute into LOCALS, write each `$state` exactly
  once at the end.** Same class hardened next door: the layout's
  ghost-cookie fallback called `setTheme` (which reads `themeState`)
  inside the effect that writes it — and `setTheme` now resolves its pair
  at CALL time so the VT callback reads nothing reactive (in VT-less
  browsers the callback runs synchronously, inside the caller's tracked
  scope — correctness must not depend on `startViewTransition` existing).
- **2026-11-23 — a mode-keyed `dark:` variant, not theme-keyed.** When the
  theme grew from a boolean to a family, the trap was keying the `dark:`
  utilities (and the shiki dark override) on the theme id: every NEW
  theme's dark half would silently lose every `dark:` utility and keep
  light code blocks. The split that survives growth: `data-theme` = the
  palette family, `data-mode` = light|dark, and EVERYTHING mode-sensitive
  keys on `[data-mode='dark']`. Per-theme CSS blocks define ONLY the CORE
  tokens — the shadcn aliases stay in `:root`, because `var()` resolves
  against the element's own cascaded values (override `--brand` in a theme
  block and `--primary` flips with it, no alias re-declaration).
- **2026-11-23 — inline custom properties OUT-RANK every CSS block; the
  built-in path must REMOVE them.** Custom themes apply as inline custom
  properties on `<html>` (the only cascade level that beats every theme
  block). The symmetric half is easy to forget: switching back to a
  built-in must `removeProperty` every token, or the last custom's values
  keep overriding every later theme forever. Same seam, two directions —
  and the pre-paint script must do BOTH synchronously for first paint.
- **2026-11-23 — `getComputedStyle` only sees the worn cascade; read the
  theme's UNWORN mode out of `cssRules`.** Forking a built-in needs BOTH
  modes' token values, but computed style answers only the mode currently
  applied. Same-origin stylesheets expose `cssRules` — walk them for the
  `[data-theme=…][data-mode=…]` block (cross-origin sheets throw; skip).
  And the URL-predicate lesson's sibling for cookies: an id containing
  dashes must parse its mode from the LAST dash, never `split('-')[1]`.
- **2026-11-23 — the URL-predicate `invalidate` is a no-op without
  `depends()`.** The picker's per-upload refresh (and the photo-detail
  save's "server facts refresh underneath the form") used
  `invalidate((u) => u.pathname === …)` — but Kit 3 matches the predicate
  ONLY against hrefs a load declared via `load.depends()`, and no load in
  this repo ever did; the calls invalidated nothing and the listing stayed
  stale. The house refresh primitive is `refreshAll()` (Kit 3's
  non-deprecated `invalidateAll`: re-runs every load of the active page,
  keeps `page.state`) — the photos picker and the detail save now ride it.
  Rule of thumb: `refreshAll` for "the page's own data changed";
  `invalidate(url)` only when a load has `depends()`ed that URL.
- **2026-11-23 — a grid with nothing to pick is dead UI; gate it on the
  thing that gives it purpose.** The /photos dialog's library buttons were
  no-ops (`onPick?.(p)` with no onPick) — the gate is `onPick &&` on the
  section, not a mode check: the editor's `upload` mode DOES pick
  (upload-THEN-insert), so mode alone is the wrong signal (05149a5).

- **2026-11-22 (p) — THE ORPHANED-GRANDCHILD REGRESSION + the desktop file-header.**
  The owner's screenshots: the Posts title, the search bar, and the status chips
  TOUCHING — a regression from the viewport-fit split (b61dead): grouping the fixed
  controls into a plain `shrink-0` wrapper made title/search/chips GRANDCHILDREN of
  the page's `gap-6` flex column, and **a flex gap spaces its DIRECT children only —
  a plain block stacks its own children with zero margin**. The fix: the wrapper
  owns its rhythm (`flex flex-col gap-4`; `gap-6` keeps the break to the rows
  region; the scroller's `pr-1`→`pr-2` — rows no longer kiss the scrollbar). The
  same round, the md+ split-table's two bare column labels became **the desktop
  FILE-HEADER** (the GitHub's): one row — the chevron (the desktop collapse, the
  mobile `$bindable` free-collapse mirrored, the header stays when collapsed), the
  identity (`title · rev`), the `+N −N` stats in the diff tints, the side story
  (saved (head) ⇄ pending · forked from rev N) muted at the right edge — the slot
  the future actions ride. Standing rules: **when a restructure inserts a wrapper,
  the moved children's spacing dies with the move — re-establish the rhythm ON the
  wrapper** (flex gap is not inheritance); the dom test pins the header anatomy
  end-to-end (identity, both stats, the side note, the collapse round-trip).

- **2026-11-22 (o) — THE SPLIT-TABLE: the GitHub's file-diff anatomy.** The
  owner's reference = GitHub's split view: the aligned rows, the
  line-number gutters, the ± signs, the tints per side. The lib carried
  it: **`alignDiff` emits `SplitRow.ln` (the counters walk: the left
  increments on the same/del, the right on the same/add; the null side =
  the no number) — ADD-ONLY: the secrets' version-compare = the same
  lib's consumer, ignoring the new field** (the lib's shape changes =
  add-only when a second consumer exists). The trace rows = the GitHub's
  file-header (the chevron LEFT, the +N −N stats computed from the rows)
  + **the free collapse: `open = $bindable` per row** — the shared-state
  mapping had forced an accordion nobody asked for (the 'not allowed to
  collapse' = the mapping's bug, not the component's). **The scroll =
  the rows' region; the trace's triggers = `sticky top-0`** — the
  headers never leave the viewport while the bodies scroll past (the
  inner-scroll experiment failed: an unbounded Collapsible content has
  nothing to scroll against). The pane's own label = removed — the
  trace's title carries it (the md+'s = the grid headers). Standing
  rules: a scroller needs a HEIGHT BOUND from its ancestors (the
  `min-h-0 flex-1` chain — an `overflow-y-auto` with no bound scrolls
  nothing); the row-level state = `$bindable`, never a shared variable
  mapped through `onOpenChange`.

- **2026-11-22 (n) — THE TRACE ROWS: the shadcn Trace's anatomy, ported.**
  The owner found the shadcn Trace (the collapsible lines — the icon, the
  title, the chevron; the row = the trigger, the detail = the content) and
  asked for it as the diff page's mobile full view. **The base registry =
  React/TSX — not installable into a Svelte portal**; the ANATOMY ports
  one-to-one onto the vendored bits-ui Collapsible (`TraceRow.svelte`: the
  icon chip, the mono title, the optional muted description, the rotating
  chevron, the scrollable content). The mobile's full comparison = the two
  trace rows (both documents EXIST on the phone — the desktop-split's
  semantics, stacked collapsed; the pending open by default); **the scroll
  = inside the open body — the row's headers never leave the viewport**
  (the tabs-scrolled-away complaint = dead by construction). The
  desktop's split = unchanged; ONE snippet pair renders every mode.
  Standing rules: the shadcn's base registry = React — the Svelte port =
  the anatomy onto the kit's primitives (check `ui/` first); a script
  that edits-then-asserts must WRITE before the late assert can void the
  edit (the lost import, twice-walked now); the kit's alias = `#lib`,
  never `$lib` (the app-sidebar's pattern).

- **2026-11-22 (m) — THE BAND = THE BOX'S BOTTOM EDGE (the sticky band's
  three sins, walked).** The owner's screenshots caught the diff page's
  band: (1) **the floating** — `sticky bottom-0` inside a parent with no
  overflow rule = the tall content SPILLS past the bounded section and the
  band strands mid-view (a sticky can never leave its parent's box — the
  spill goes past BOTH); (2) **the sore background** — the band painted
  `bg-card` over the box's `bg-background` (a pinned band inside a surface
  paints THAT surface); (3) **the gap below** — the box's own padding
  (`px-4 py-6`) showed under the band. The fixes: the section =
  `overflow-hidden` (the spill clipped); **the panels = the scroll panes**
  (`min-h-0 flex-1 overflow-y-auto` — the card's border fixed, the content
  scrolls inside); **the band = a STATIC flex child (`mt-auto`) in the
  box's surface, full-bleed (`-mx-4 -mb-6`, re-padded inside)** — the band
  IS the box's bottom edge, clipped flush by the box's rounded corners;
  the toggle = the tabs' scale (the controls in one row = one scale).
  Standing rules: a pinned band = a layout child, not a position chase —
  bound the pane, static the band; the band's surface = its container's
  surface; never leave the container's padding under a full-bleed row.

- **2026-11-22 (l) — THE DIFF PAGE: the doctrine's full application.** The
  owner's reports: the action buttons overflowed the phone's viewport
  horizontally; the full comparison stacked two whole documents; the
  compact view was opt-in. The fixes, under the viewport-fit doctrine:
  **the sticky verb band** (the photos' pattern, the third use — the
  Discard/Save pinned to the pane's bottom; the mobile = the stacked
  full-width, the overflow = impossible); **the view toggle = beside the
  tabs, right-aligned** (the view control belongs with the view tabs; the
  band = the verbs only); **the mobile default = Changed only**
  (the `browser ? matchMedia(...).matches : false` init — the SSR renders
  the full, the client adopts the compact); **the full comparison = the
  editor-preview's grammar** (the mobile = the Saved/Pending tabs; the md+
  = the split) rendered by **ONE snippet pair** — the markup cannot drift
  between the modes; **the metadata table = its OWN horizontal scroll**
  (the `overflow-x-auto` wrapper over a `min-w-[48rem]` floor — the values
  keep their natural readable width; the page never scrolls sideways).
  Standing rules: the action band = the VERBS, always visible; the view
  toggles live with the view tabs; a table wider than its pane scrolls in
  its own box; shared snippets over duplicated markup — drift = the test's
  job to catch, the snippet = the way to make the test unnecessary.

- **2026-11-22 (k) — THE VIEWPORT-FIT DOCTRINE: the box never scrolls.** The
  owner's principle: **every piece of chrome and every control is always in
  the viewport; only content scrolls, inside its own pane.** Two violations
  walked: (1) the editor's panes' grid carried a magic height guess
  (`h-[calc(100svh-13.5rem)]`) — the guess drifted per device, the BOX
  scrolled, the toolbar/meta left the viewport; the fix = the flex truth
  (the column gains `min-h-0`; the grid = `min-h-0 flex-1` — whatever space
  remains IS the pane's height; the fit = BY CONSTRUCTION, zero
  arithmetic). (2) The lists (posts + photos, the same shape): the whole
  column scrolled — the title/search/filters scrolled away with the rows;
  the fix = the split (the controls = `shrink-0`, the rows = the inner
  scroller `min-h-0 flex-1 overflow-y-auto`). Standing rules: **never
  guess heights with svh-calc — bound with flex (`min-h-0 flex-1`); the
  scroll container = the deepest region that owns the data, never the
  chrome's box.** And the hints went hybrid: **below sm (no hover on
  touch) the hint renders inline in the open panel; at sm+ the
  CircleHelp + the Tooltip** — one prop, two renders, zero JS.

- **2026-11-22 (j) — THE SNACKBAR v2 + THE HOVER AFFORDANCE.** The owner's
  reference picked the shadcn Alert's CARD shape: bottom-RIGHT (not the
  center), ~22rem, the circled icon + the BOLD TITLE + the muted
  description, the ×. **The lifetimes (the owner's sticky-danger
  agreement): ok/warn = 5s; danger = STICKY until dismissed — an error
  that dissolves while unread is a missed failure.** The flash API = the
  object shape ({kind, title, description?, sticky?, action?}); the ACTION
  rides in-card — **the save conflict's 'Review diff' door lives IN the
  snackbar** (the conflict = the actionable state: a momentary surface
  can never hold it). The editor's save/publish pills = retired; the
  meta bar keeps only the autosave pill. The section hints migrated to
  the **CircleHelp + the kit's Tooltip** (the owner: the '?' BUTTON, the
  native icon not a text glyph; lucide's CircleHelp = the exact shape) —
  **bits-ui 2.21 ships NO HoverCard primitive** (the module probe
  walked), so the affordance rides the Tooltip (the hover on desktop;
  focus/tap on touch — the trigger is focusable). The granularity law:
  the SECTION hints = the hover affordance; the FIELD hints = inline
  under their labels. Standing rules: the momentary vs the persistent
  notification = different surfaces; check the kit BEFORE importing a
  new primitive; the apostrophe-in-single-quoted-it() = the recurring
  parse error (the double quotes for any string with a possessive).

- **2026-11-22 (i) — THE SNACKBAR + THE PHOTOS' PANEL RESTRUCTURE.** The
  owner's pick: the shadcn Alert's ANATOMY (the bordered card, the leading
  icon, the variants) built in the kit's own bits-ui idiom — **no base-ui
  mixing** (the estate = bits-ui; the linked alert = the base-ui registry).
  `flash.svelte.ts` = ONE module owning the state; ONE Snackbar instance in
  the app layout; the pages fire `flash(kind, text)` — the auto-dismiss at
  3s, a fresh flash restarts the timer. The momentary flashes moved (the
  photos' save/failure, the editor's export confirmations); **the
  persistent statuses keep their homes** (the autosave pill = its own
  contract). The photos' panel: the Download = up to the file section
  (below the img URL, the copy-button's style), the Save = the full rail
  width, the Delete = below it full-width + **the danger red at rest**.
  Two walks: **the runes modules need the svelte compiler — the node test
  project deliberately runs without it, so anything touching a
  `.svelte.ts` module rides `.dom.test.ts`** (the naming contract
  extended); **never nest a button inside a button** (the Download row's
  first draft did — the single row-button is the fix); and the commit
  message's backticks are EXECUTED by zsh (the amend re-worded — quote
  the code spans in the messages).

- **2026-11-22 (h) — THE PANEL HINTS, THE MARKDOWN IMPORT, AND TWO RULING
  MISSES.** (1) The owner chose the IN-PANEL hint over the '?' tooltip —
  the question is asked when a panel opens, and tooltips are poor on
  touch; `SectionCard` grew an optional `hint` prop (one muted line at
  the open panel's top). (2) **The markdown import** (the posts list →
  'Import markdown' → the file picker): the frontmatter = the YAML via
  **js-yaml — whose ESM interop ships NO default export** (`yaml` from the
  default import = undefined; the named `load` import is the contract) —
  the title/date map from it, the H1 fallback STRIPS ITSELF from the
  content (the blog renders the title; a duplicate H1 would read twice),
  the malformed frontmatter = prose not a crash. The draft = created
  review-ready, never auto-published. **The v1 boundary: images stay as
  text** — the `![[attachments]]` links need the media relay's upload
  path first (the cue layer flags them visually). (3) The case sweep
  missed the rail's export labels (the palette's titles were fixed, the
  rail's weren't — same handlers, two label sites: **grep every label
  site, not one**). (4) The photos panel: the Save pinned to the uniform
  h-8; the Delete = **the danger red AT REST** (the ruling — it had only
  the border/hover danger). Standing rules: js-yaml = the named import;
  a ruling's fix sweeps every SITE of the pattern, not the first one.

- **2026-11-22 (g) — THE BOOT WARM-UP: a process's expensive one-time builds
  run at BOOT, never on the first request.** The owner's re-test on gofar.id
  (right after the v1.6.0 deploy) still showed a stuck 3–5s click — the
  server acquitted by curl (the post = 13ms, the data request = 15ms; the
  whole-post cache working) — the real killer: **the Shiki grammar build =
  the seconds of sync, event-loop-freezing CPU on the first render each pod
  serves**; the first traffic after a deploy froze the pod (the click's
  request queued behind the build; the stream could not flush). The fix =
  the boot warm-up via `hooks.server.ts` (the only eager touchpoint — the
  render module is DYNAMICALLY imported by the relay route): the engine
  builds at the pod's startup, where the k8s lifecycle expects the CPU (the
  old pod serves; the readiness probe retries); the boot logs
  `[boot] markdown engine warm`. The mobile pane-controls row also gained
  its own spacing (`pb` over the safe-area inset + the horizontal nudge —
  the owner's report: the toolbar jammed against the content box's edges).
  Standing rule: **the cold path = a deploy-window tax, never a
  visitor/user tax** (earendil's twin landed the same round — its ledger
  carries the reader-side entry).

- **2026-11-22 (e) — INCREMENTAL PREVIEW PAINT: render-everything,
  patch-the-diff.** The parked lever landed: after the fence cache the
  long-doc tail = the full `{@html}` swap (the browser re-parsed the entire
  preview per keystroke). The architecture that avoids every plugin
  landmine: **the pipeline keeps rendering the WHOLE document** (footnotes,
  link refs, spanning containers — the correctness by construction; the
  render never learns about the diff), and `preview-diff.ts` patches the
  container at the BLOCK level. The contracts the tests pin: **the diff key
  = the rendered CONTENT (outerHTML), never the source range** — an edit
  shifts every block below, the range keys would mass-mismatch; **the
  mermaid unit = the pair (pre.mermaid-src + its dataset.mmd sibling),
  keyed by the fence SOURCE (the hidden attr masquerades as a change) and
  kept VERBATIM** — the SVG box = expensive hydration state a keystroke
  must not destroy; the stale box leaves WITH its unit on a source edit.
  The walk = the two-pointer over the units (markdown = the source order —
  no reorders exist), the frontier = the old cursor's NODE (an index into
  the live children shifts under inserts — walked). Standing rules: diff
  the APPLICATION, never the render; key by content, not position; keep
  the hydration state inside the diff's units.

- **2026-11-22 (d) — THE LONG-DOC PREVIEW AND THE SMOOTH SYNC (two fixes, one
  round).** (1) The preview's 2-3s on vault-scale docs = **Shiki
  re-tokenizing every fence on every render** — O(total code volume) per
  keystroke. The highlight is a PURE function of (lang, content) (the
  dual-theme output bakes CSS vars) → a bounded Map cache in the fence
  wrapper; the data-source-lines anchor re-injection stays PER RENDER (the
  positions shift). Live typing = one miss, the rest hits. The mermaid SVG
  cache (bc3e014) = the same pattern. (2) The synced scroll's jagged
  followers were QUANTIZED, not frame-starved: the preview chased the
  editor's INTEGER top line; the editor chased the preview in floored
  line-height jumps. Fix = the sub-line precision over the SAME
  source-line-anchored map: topLine() = line + the pixel fraction (CM's
  cached height map — no layout reads); lineForOffset = the float;
  scrollToLine = block.top + fraction × block.height; the blank seams =
  the linear bridge. **The line-domain CONTRACT (walked): a block owns
  [start, end + 1) in line space — the fraction INTO the last line lives
  above `end`; the seam owns [end + 1, next.start); the two are disjoint
  and the px map is continuous at the knots — the round-trip
  offset→line→offset = the identity.** Any floor()/≤end clamp re-jags the
  chase. Standing rules: cache the pure renders, keep the per-render parts
  (the anchors) outside the cache; the sync maps are float maps.

- **2026-11-22 (c) — LOCK OPERATIONS RUN UNDER NPM 10 — THE CI'S AND THE
  IMAGE'S NPM — NEVER THE LOCAL npm 11.** The gates went red (`Missing:
  @sveltejs/kit@2.70.4 from lock file`) with a lock the local `npm ci`
  called fine: bits-ui's nested `runed` peers kit ^2.21; the tree runs kit
  3; **npm 11 (local node 26) SKIPS the unsatisfied peer when writing the
  lock; npm 10 (node 22 — the CI's AND the Dockerfile's `node:22-alpine`
  build) RESOLVES it to a nested copy and demands it in the lock**. The
  runtime image is node 22 — the local node 26 is the divergent one.
  Regenerated with `npx npm@10 install --package-lock-only`; verified
  `npm ci` green under BOTH. bits-ui 2.22.0 (the kit-^3 peer) considered
  and rejected: its required zod peer (absent here) re-arms the trap.
  Standing rule: every lock regen = `npx npm@10 …`; a lock written by any
  other npm is a CI/image build break waiting to fire. (ab1f3cc = the same
  war, first battle.)

- **2026-11-22 (b) — THE DEFLIST CUE'S TWO WALKS: the space form and the
  lastIndex leak.** The common deflist form is `: definition` (colon + SPACE)
  — the cue's `^\s*:[^\s]` only matched the glued `:def` — the COMMON shape
  was the one unmatched. And the `g`-flag's `lastIndex` PERSISTS across
  `exec` calls: after one match, the next line's `^`-anchored match is
  skipped until a failed exec resets it — the every-other-line alternation.
  Standing rules: the line-anchored cue patterns must tolerate the space
  after the trigger; reset `lastIndex` per line for every global regex
  (or don't share one regex object across lines).

- **2026-11-22 — THE EMOJI MENU'S DEATH WAS THE FILTER, NOT THE PAINT (and the
  two phantom fields that cost four round-trips).** The owner's "the menu
  stopped showing after the skin" walked the entire CM completion pipeline via
  console traces: arming ✓ (`input.type` annotated ✓), the source ✓ (1,903
  returned, `aborted: false`), the resolution ✓ (`setActive` dispatched) — and
  `CompletionDialog.build` STILL returned null: `sortOptions` filtered EVERYTHING
  out. The killer: **CM's FuzzyMatcher has a single-character-query rule — a
  one-char pattern only matches options whose label STARTS with that char**. The
  skin round's glyph-first label (`⛺ :tent:`) failed it on all 1,903; the stock
  `:tent:` labels passed — the before/after timeline explained. **The seam CM
  ships for exactly this: `label` (the filter + apply text) vs `displayLabel`
  (the rendered row)** — never put decoration at the head of a label the filter
  sees. Two instrumentation traps to never re-walk: **`ViewUpdate.userEvent` and
  `Transaction.userEvent` (instance) DO NOT EXIST** — `t.userEvent` reads
  `undefined` silently (the type error only appears in svelte-check, which
  vitest strips); the real reads are the annotation
  `t.annotation(Transaction.userEvent)` (static) and the SPEC's own keys. A
  `dispatch({})` from `@codemirror/language`'s `forceParsing` is a red herring
  nobody calls; and `effects: <single StateEffect>` (not an array) makes a
  `.length` probe read `undefined`. Standing rules: the completion's LABEL is
  CONTRACT (the trigger-char prefix); decorate via displayLabel; trace at the
  annotation/spec level, never the phantom properties.

- **2026-11-21 — SHAPE UNIFORMITY: the seeds must establish what the mirror
  enforces.** The key-set mirror reconciles sibling shapes on every portal
  save — so a NON-uniform seed is a bomb whose pin the first save pulls
  (walked twice in one day: mellon's split seeding flattened staging +
  production, dropping their real keys; lumen's shared was still the
  walkthrough's 3-key shape, one save away from the same). Owner ruling:
  every path of an app carries the SAME key set, unused keys EMPTY — the
  runbook §6 seeds now establish it (per-key used-by notes name which
  path's copy each ES pulls), a post-seed guard diffs key sets across
  paths, and the live estate was re-seeded to the law (JWT secret verified
  byte-identical through the reseed; both mellon ESes re-rendered green
  with the knob in its designed home). Consequence worth keeping: a key
  that should exist on only ONE path is now a CONTRACT VIOLATION — the
  env-model's answer is the empty placeholder, and "which copy is
  consumed" is a property of the ES remoteRefs, never of presence.
- **2026-11-21 — the diff page's two presentations + the shared DIFF_BLOCK
  language.** The markdown tab = two TEXT PANES (free-flowing lines, not a
  bordered grid), whole file by DEFAULT with changed rows block-highlighted
  (`bg-diff-del/15`/`bg-diff-add/15` — solid row blocks, not font tints),
  `Changed only` collapsing to regions ±2 context + gap bands
  (`splitRegions`); the metadata tab = the vault's table view (status
  chips, Hide-unchanged button, body EXCLUDED — a body row rendered the
  whole document twice, walked). The `DIFF_BLOCK` map lives in
  secrets-diff.ts and is consumed by the compare page (split/inline/table)
  and the vault drawer — ONE highlight language. Two process notes: (1)
  the toggle affordance is the vault's reveal-BUTTON (aria-pressed +
  amber active), never a checkbox; (2) hunk-level conflict resolution is
  PARKED with a design: two-way per-region choice (no ancestor exists —
  posts have no version history), compose client-side, save rebased.
- **2026-11-21 — synced scroll is source-line anchored, never percentages.**
  The split-editor scroll sync's only honest form: the RENDERER knows which
  source lines each block came from (markdown-it `token.map` → a core rule
  stamps `data-source-lines`), the editor builds a cumulative-height map
  from the rendered blocks, and each pane's scroll resolves the other
  through it (interpolated inside fences — a 20-line fence is one tall
  block; per-line truth doesn't exist there). Percentage mapping would lie
  the moment a diagram appears. Three pipeline details worth keeping: the
  Shiki renderer DROPS token attrs (re-inject on its `<pre>`); singleton
  tokens (fence/hr) have `nesting === 0` — anchor them too; a hydrated
  mermaid box replaces the hidden source pre — the SIBLING donates the
  geometry. And the flush-before-navigate rule: any SPA navigation flushes
  the live draft to the pending-edit store FIRST — an in-memory draft dies
  with the component; the flush is the handoff (and it resets the
  autosave window).

- **2026-11-21 — a green test suite can still fail the run: unmounted
  transitions reject, and a piped gate lies.** Two findings from one CI
  red (223/223 tests passed; the run exited 1): (1) happy-dom's Web
  Animations implementation rejects `finished` with an AbortError on
  `cancel()` — Svelte's teardown aborts any slide/fade still in flight
  when testing-library unmounts, and vitest fails the run on unhandled
  rejections even with zero failed tests. Fix: stub
  `Element.prototype.animate` with a cancel-noop Animation in the test
  (vault-page.dom.test.ts; promote to a dom setupFile the next time a
  page hits it). (2) The failure was INVISIBLE locally: `npm run
  test:unit | grep …` makes `$?` read GREP's exit code, not vitest's —
  the gate passed locally and failed in CI. The gate discipline now has
  teeth: run gates UNPIPED (output to a file, `$?` of the gate itself),
  and treat a piped exit code as unverified.
- **2026-11-21 — the preview inherits earendil's prose bugs: vendored CSS takes
  a parity commit in the same round.** earendil's overflow fix (space-free
  tokens painted past the article column; the typography plugin ships no
  overflow-wrap) applies verbatim to mellon's vendored `.preview .prose` block
  — the editor preview overflowed on the same markdown, breaking §11.4's
  "renders exactly as the public site will" promise. Mirrored the guard
  (`850d1b4`, branch `fix/preview-prose-overflow-wrap`): `overflow-wrap:
  break-word`, not `anywhere` (intrinsic sizing of grids/tables must not
  change), fenced code keeps its horizontal scroll. Standing rule: whenever
  earendil's `layout.css` prose/raw-CSS blocks change, diff mellon's vendored
  exceptions and mirror the delta immediately — the preview's fidelity is a
  contract, not a courtesy. **Audit addendum:** the audit round also minted a
  mellon-side rule of its own — the preview pane's `overflow-y-auto` masked
  the table gap (the pane panned instead of the table); parity now means
  wrapper-for-wrapper (`.table-wrap`, `572c28b`), not just "it doesn't reach
  the page". And the portal's own text surfaces needed the same base guard:
  `truncate` covered the lists, but dialog/toast strings and the posts-list
  title link had no guard at all.
- **2026-11-21 — a hairline pill is text, not a button (D14).** The owner:
  "I don't like this kind of button" — the quiet chip's anatomy was
  bg-transparent + a 1px border-border hairline: on any surface it read as
  bare text. The fix gave it the SELECT-TRIGGER's anatomy (bg-card + the
  border — the picker-pill look the owner did NOT flag on the same screen).
  Standing rule: **a secondary action needs a SURFACE to read as a control;
  "transparent + hairline" is a label**. When the owner flags a control's
  look, scan the screen for the sibling control they did NOT flag — the
  difference between them is the answer. twMerge note: the base's
  `border border-transparent` + variant's `border-border` merge fine — the
  hairline WAS rendering; the surface was the missing half.
  - **2026-11-21 — native confirm() is the same leak class as native
    <select> (D15).** The owner hit the OS dialog on the vault — browser-owned
    UI, unthemeable, custom copy ignored. The replacement: a house `Confirm`
    over `ui/alert-dialog` (mounts already-open via conditional render, the
    destructive verb fills --danger, busy-aware dismissal). The unsaved-changes
    guards rework: `beforeNavigate` CANCELS the navigation, asks in the
    estate's voice, then re-navigates past a `guardOff` latch — the event's
    destination is `e.to.url` (a NavigationTarget union; `e.url` does not
    exist there). `beforeunload` stays native — the browser owns that chrome.
    Also: the vault NEVER HAD a navigation guard — the report's real defect
    was silent loss on leave, and the dialog was the row-× flow wearing the
    wrong clothes.
    - **2026-11-21 — the registry's Cancel rides buttonVariants' DEFAULT SIZE
      (D16).** The confirm footer's verb (primary: h-auto py-2 — auto height)
      stood beside a Cancel fixed at h-8 — the class override (px-4 py-2) never
      touched the height because the HEIGHT lives in the size variant. Standing
      rule: **when a footer mixes a cast Button with a registry
      Cancel/Action/Close, override the height anatomy on the registry one
      (h-auto + matching py) or the pair renders uneven**; pin it with a
      class-list test — happy-dom's getComputedStyle is unreliable for borders.
      - **2026-11-21 — the lock is a CI artifact; the pipe lies; JS strings eat
        backslashes.** Three findings from mellon's FIRST CI run on the shadcn
        branch (it died at `npm ci`, and would have died at lint right after):
        (1) **npm 10 vs 11 disagree on optional peers** — bits-ui's runed has the
        optional peer `@sveltejs/kit ^2.21.0`; npm 11 (local Node 26) leaves it
        out of the tree, npm 10 (Node 22 = CI + the runtime image) nests kit-2
        copies in. A lock generated on npm 11 fails `npm ci` on Node 22 (EUSAGE,
        "Missing: @sveltejs/kit@2.70.4"). Remedy: regenerate with
        `npx -y npm@10.9.2 install --package-lock-only`, prove with
        `npx -y npm@10.9.2 ci --dry-run` — and the npm-10 lock satisfies npm 11
        too, and npm 11 does not strip the entries on regenerate (stable both
        ways). (2) **`eslint … | tail; echo $?` reports TAIL's exit code** — four
        lint errors read as green across three rounds. Gates must run bare or
        under `set -o pipefail`; a worktree at the previous commit + a real
        `npm ci` is the honest reproduction harness. (3) **`'\\-'` in a JS
        string is `'-'`** — the "v-flag dash escape" fix (54f9853) never reached
        the browser: HTML compiles `pattern` attrs with the v flag, where an
        unescaped `-` in a character class is a SYNTAX ERROR, and a
        non-compiling pattern is silently IGNORED — username/app/env inputs had
        no client-side validation at all. The fix is `'\\\\-'` in source (the
        string then carries `\\-`), proven under `new RegExp(src, 'v')`.
        Meta-lesson: when a "fix" targets a string that leaves the JS runtime
        (attribute → browser compiler), trace the value through every
        serialization hop — the escape you wrote may vanish before it ships.
        - **2026-11-21 — a fallback-bearing bindable rejects undefined at
          HYDRATION; and no gate mounts a route.** v4.0.0 shipped a 500 on
          /posts and /photos: three pages declared a drawer trigger as
          `$state<HTMLElement | undefined>()` and bound it to Button's
          `ref = $bindable(null)`. SSR never executes bindings (server renders
          fine), the throw hits the PAGE boundary at hydration (the shell
          survives — unlike S2's root-boundary shell loss), and NO gate
          constructs a route component: 198 tests + a green build missed it.
          The rule was already written (the shell's burger comment) — it needed
          a SWEEP, and now a layer: route-mount smoke tests (the real page +
          `as never` fixture data, users-page.dom.test.ts's pattern) fail with
          the exact production error before the fix. Corollary: a bindable's
          fallback defines its absence value — ours are all `null` now; a
          future `$bindable(x)` with a non-null fallback re-arms the trap.
          ledger records walked events. Newest first.

- **2026-11-21 — the CLI's `--overwrite` reverts OWNED files; the test net
  catches it.** The S4 vendor run overwrote the cast button, the frost
  dialog, and the house input/textarea with registry-raw versions — and the
  `--overwrite` flag is REQUIRED for the new items. Standing rule: **after
  every `shadcn-svelte add`, restore the owned files from git BEFORE
  committing** (`git checkout --` the touched owned dirs); the cast/dom tests
  are the tripwire — a red suite during a vendor run means a revert, not a
  regression. Also: `git add` with one bad pathspec aborts the WHOLE add —
  commit (or `git show --stat`) and verify what actually landed.
- **2026-11-21 — bits-ui Command: the search is the INPUT's value.** A
  `bind:value` on `Command.Root` binds the SELECTED item, not the search —
  typing updated the input but the component's `q` never moved, and the
  create-row never rendered. Bind the `Command.Input`'s value. Two more:
  `onSelect` passes NO value (close over the row), and a bare `onOpenChange`
  attribute = boolean `true` (the shorthand needs braces — svelte-check's
  "boolean is not assignable to OnChangeFn" is the tell).
- **2026-11-21 — the registries' calendars smuggle native `<select>`s.** The
  shadcn calendar's month/year pickers hide a real `<select>` under the
  styled span — clicking it opens the OS popup, the exact thing the
  themed-dropdown doctrine bans (§5.3: the popup included). The grep gate
  (`'<select' src` → 0) caught it the moment `calendar`/`range-calendar`
  vendored. The fix kept the headless primitives as locale-aware item
  providers and moved the interaction to the block's Select; the placeholder
  math (`placeholder.set({month|year})`, multi-month index subtraction)
  moved to the captions. Also: Calendar requires `type=`, RangeCalendar has
  none; day cells are DIVS (`[data-bits-day]` inside `[data-calendar-cell]`).
- **2026-11-21 — a component rewrite keeps the CONTRACT, not the code.** The
  S4 widgets (Combobox 273→197, DatePicker 191→93, DateRange 240→138) rewrote
  IN PLACE over the block with byte-identical prop contracts — the five+3
  mounts didn't change at all, and each contract test (the replace-on-single,
  append-on-multi, create-then-select, ISO round-trip) pins behavior the old
  components ran UNTESTED for months. The honest re-seed rule for
  wire-driven widget state: complete windows sync the grid; a HALF window is
  an in-progress-pick echo and must not wipe it.
- **2026-11-21 — tailwind-variants emits variant groups in DEFINITION order.**
  With `variant` defined before `size` (the registry's own layout), the default
  size's `h-8 px-2.5` emitted AFTER the cast variant's `h-auto px-3 py-1.5`
  and WON — every pill would have rendered as a registry rectangle. Standing
  rules: **when one variant group must override another, define it LAST** (or
  verify the emit order with a two-probe eval before trusting a merge); and
  **Svelte 5 destructuring defaults are the component's REAL defaults** — tv's
  `defaultVariants` is shadowed by the destructure, so a "new default variant"
  is a two-place edit, and the safe sweep form is explicit variants at every
  call site (opt-in cast, registry default look stable).
- **2026-11-21 — actions can't ride components; labels can't nest labels.**
  `use:focusOnMount` on `<Input>` is a compile error (`component_invalid_directive`
  — directives bind to elements only), so any field with an action stays a raw
  `<input>`. And the house wrapper-label pattern (caption span INSIDE the
  label, implicit association) must never convert its caption to `<Label>` —
  a label inside a label is invalid HTML. The `ui/label` mono variant is for
  STANDALONE labels only.
- **2026-11-21 — sweep the evidence, not the plan.** The S3 button recon (48
  buttons) falsified three plan guesses at once: the action buttons are PILLS
  (`rounded-full bg-brand text-white`), not sm/md rectangles; the pages' ghost
  is text-hover-only (no `bg-accent/60` wash); the tree's toggles are native
  accent-brand checkboxes (a `switch`/`checkbox` vendor would have been dead
  weight AND a visual change). Standing rule: **recon the real class grammar
  before writing the variant map** — the plan's grammar was written from
  memory of a different file. Also: **static source guards must learn the
  component's tag** (`<Input` spreads name/type onto the real element, but the
  setup ghost-field guard parses SOURCE — `<input\b` missed it).
- **2026-11-21 — `<input pattern>` compiles with the v flag now.** The
  browser console complained on every keystroke: 'invalid character in
  class' — modern browsers validate the pattern attribute as a /v regex,
  and the v flag FORBIDS an unescaped trailing dash inside a character
  class (`[a-z0-9._-]` dies; `[a-z0-9.\-_]` lives). The pattern never ran,
  so the constraint silently didn't. Standing rule: **patterns in HTML
  attributes are v-flag regexes — escape the dash (and friends) inside
  every class**; the JS-side copies (mock.ts) run without the flag and
  must NOT be blindly "fixed" to match.
- **2026-11-21 — the hand-rolled popup lost to the dialog; S4's select
  arrived early.** After the portal + the event shielding STILL failed in
  the owner's browser (while the harness stayed green), the answer was to
  stop patching: the Role field rides the block's `ui/select` (bits-ui) —
  floating positioning + portal + focus scope are NATIVE, the whole
  measure-once-popup bug class deleted. Standing rules: **when a hand-rolled
  widget fights the block's layers twice, the fight IS the signal — pull
  the planned replacement forward for that site**; and bits-ui's Select
  commits on the POINTER PAIR (down preventDefaults focus, up commits) —
  a synthetic `.click()` tests nothing. The wire contract survived via a
  hidden input (the action still reads formData.get('role')). The other
  five Select sites stay on the hand-rolled one until S4 sweeps them.
- **2026-11-21 — a portaled popup is an outsider: shield its events.** The
  portal fixed the geometry and broke the picking — with the popup in
  document.body, a pointerdown on an option reads as INTERACT-OUTSIDE by
  the dialog's dismiss layer, which closed the whole dialog before the
  option's click could land. The clean part: bits-ui's dismiss layer
  EXPLICITLY ignores stopped events (`if (event.cancelBubble)` on
  pointerdown, `if (event.defaultPrevented)` on keydown) — so the popup
  stops propagation on pointerdown (+ focusin/focusout for the focus
  guard), and Esc closing the SELECT without the dialog is just
  preventDefault, which the layer already honors. Standing rule: **a
  portaled popup must shield pointerdown/focus events or the host dialog
  dismisses on its own options** — the layer's stopped-event contract is
  the sanctioned seam, not a hack.
- **2026-11-21 — once-measured coordinates are a liability: PORTAL the
  popup.** The transform fix wasn't enough — the Select's popup STILL
  detached inside the dialog. The deeper truth: the popup measured the
  trigger ONCE at open and pinned `position:fixed` viewport coordinates in
  an inline style — any movement of the surrounding layer (the dialog's
  entrance settle, h-fit resolution, a re-render) orphans the popup: it
  points at where the trigger USED to be. Standing rule: **a fixed-positioned
  popup that measures its trigger once must live in document.body** (portaled
  via an action) — body has no transformed/clipping ancestors in any context,
  so the measured coordinates can't be invalidated by the host layer. The
  outside-click handler must then EXEMPT the portaled listbox (it lives
  outside the component's root), and openPop re-measures on tick + rAF to
  ride out the host's settling.
- **2026-11-21 — a transformed ancestor hijacks position:fixed.** The
  user-creation dialog rendered with the Role select's popup floating at the
  viewport's bottom-right. The dialog centered via the block's
  `-translate-x/y-1/2`; CSS makes a TRANSFORMED element the containing block
  for `position:fixed` descendants — and mellon's Select popups are
  `position:fixed` with viewport coordinates from getBoundingClientRect, so
  inside any dialog their coordinates resolve against the dialog's box.
  Standing rule: **center dialogs without transforms** (`inset-0` +
  `mx-auto my-auto` + `h-fit`), or no fixed-positioned popup can live
  inside one. Same round: the block's dialog overlay is a whisper
  (`bg-black/10`) — mellon's dialog frost is the DeleteDialog vocabulary
  (`bg-background/70` + `backdrop-blur-sm`, theme-aware).
- **2026-11-21 — the DIALOG round: three owner asks, one vendored file.**
  `ui/dialog` joined the block (normalized in the same commit — the CLI
  re-writes files with the dead `data-open:` hooks, so EVERY vendor run
  re-applies the sed: a vendor commit without the normalization re-diffs).
  The user-creation form moved into a dialog (door above the table, close
  on success so the one-time password reveal reads next, failed submits
  stay open). The login's Enter round trip shows a spinner now — a form
  with NO progress indicator on a minting round trip reads as a dead click.
  And the case sweep continues: chips on the compare page (Parsed/Raw
  JSON/Show values) — the sweep rule of thumb so far: **interactive labels
  speak case; mono metadata (breadcrumbs, table headers, status badges,
  slug chips) stays lowercase** — when in doubt, ask which words the USER
  reads as a sentence.
- **2026-11-21 — D9b: the ceiling governs COMPONENTS, not furniture.** The
  owner's seven-report round on the secrets page. The box's D9 ruling
  (rounded-lg, no shadow) lasted one day — the owner's side-by-side claimed
  the old box back: `rounded-2xl` + `shadow-sm` is the DESIGNED furniture
  geometry; the ceiling and the no-shadow rule keep governing components
  (Palette/ImagePicker stay rounded-lg). Standing rule: **a doctrine
  written for components does not automatically govern furniture** — scope
  the rule, don't flatten the design. Same round, two more findings:
  (1) **the block's `w-full` + `mx-3` overflowed the viewport by exactly
  the margin** — the box touched the screen edge on desktop AND mobile;
  in a flex column, stretch() already sizes children minus margins —
  drop `w-full` whenever margins need to show. (2) **the vendored
  animations were hooked to attributes that don't exist** — the registry
  animates on `data-open:`/`data-closed:`; bits-ui sets `data-state`.
  Seven files normalized to `data-[state=open]:`/`data-[state=closed]:`
  (proven in the harness: the open sheet's attribute list has data-state,
  no data-open). And the lowercase-button sweep: interactive labels speak
  normal case (`Save as v2`, `+ Key`, `History`, `Save draft`/`Save Post`
  by publish state); mono metadata (breadcrumbs, table headers, status
  badges) stays lowercase — that's the vocabulary, not an error.
- **2026-11-21 — the two-click toggle was a DOUBLE NEGATION wearing state
  -dependent clothes.** The rail's collapse toggle worked only every other
  click. The wiring: `onOpenChange={(open) => navRail.setCollapsed(!open)}`
  called a setter whose body ALREADY stores the inverse of its open
  parameter — `collapsed = !(!open) = open` — inverted. The symptom was
  irregular because of the writable-derived override semantics: the
  Provider's `bind:open` write lands as an OVERRIDE on the derived, and it
  stands only when the store value does NOT change in the same flush — so
  some clicks moved the rail, some only flipped the persisted flag.
  Standing rules: **a setter named after its OUTPUT (setCollapsed) must not
  take its input named after its INVERSE** — renamed `setOpen(open)`, the
  name is the contract; and wire callbacks 1:1, no "helpful" negations at
  call sites. The harness now drives the REAL layout's footer toggle:
  one click = one flip, both directions, persistence following.
- **2026-11-21 — `data-active={false}` is not "absent" — and Tailwind's
  presence variants made the whole rail pay for it.** The owner's
  side-by-side (old vs new rail) showed bolder, darker rows and no hover
  lift. The class strings were IDENTICAL to the old design — the bug was in
  what the CSS MATCHES: the block's `data-active:` variants compile to
  attribute-PRESENCE selectors (`[data-active]`), and the svelte block sets
  `data-active: isActive`, which stringifies to `"false"` on every inactive
  row. Presence matches `"false"`: EVERY row rendered `font-medium` (500)
  and — beating `text-muted-foreground` on specificity — full foreground.
  The hover's text lift then had nothing to lift. Standing rule: **an
  attribute consumed by presence-selectors must be OMITTED when false**
  (`isActive ? 'true' : undefined`), never written as `"false"`. The class
  strings being identical is NOT the same as the styles matching — check
  the compiled selector's match semantics. Pinned by the harness
  (data-active present on the active row only).
- **2026-11-21 — the animation layer was never in the pipeline.** After the
  class-clobber fix the owner still saw no section animation, and the real
  story was two layers deep: tw-animate-css is a TAILWIND v4 stylesheet
  (`@theme inline` + `@utility` directives) — injected as a plain JS-side
  stylesheet those directives are browser-invisible, so no `animate-*` class
  ever existed. And it COULD not be imported from the tailwind entry: the
  package exposes its css only under the `style` export condition, which
  every resolver in this chain rejects (tailwind's loadStylesheet, enhanced-
  resolve — even relative node_modules paths — and vite's js resolution).
  Standing rule: **animation vocabularies ride the tailwind entry's @import,
  and when the exports map blocks resolution, vendor the copy into src/**
  (`src/lib/styles/tw-animate.css`, provenance header, regenerate on bump) —
  the build then emits real rules
  (`.data-\[state\=open\]\:animate-collapsible-down[data-state=open]`) and
  the sheet/dropdown/tooltip animations came alive in the same stroke.
  Three failed routes documented in layout.css's comment so nobody re-walks
  them.
- **2026-11-21 — the collapsed rail taught the SVELTE 5 CLASS-CLOBBER rule.**
  A static `class` attribute after `{...props}` **REPLACES** the spread's
  class — it does not merge (proven in the dom harness: the button rendered
  with only the static string). Live symptoms, all one cause: the collapsed
  rail's section labels rendered sentence-case and large (the vendored
  `text-xs tracking-widest uppercase` never arrived), never faded in
  icon-collapse mode (`opacity-0` + `-mt-8` never arrived), and the UserMenu
  rows silently lost their hover/focus classes. Standing rule: **inside a
  `child` snippet, compose — `class={cn(props.class, '…')}` — never a bare
  static class after a spread.** Pinned by a fixture + dom test. Same round:
  section collapse got its height animation — tw-animate-css ships
  `animate-collapsible-down/up` reading `--bits-collapsible-content-height`
  (0.2s ease-out; the global reduced-motion rule snaps it). And a standing
  Svelte comment rule, hit four times this round: **comments match their
  context** — `//` only inside script blocks (a `//` in MARKUP renders as
  literal page text — the owner screenshotted that too), `<!-- -->` only in
  markup, never inside a tag's attribute list, never inside a script block.
- **2026-11-20 — the 500 page lost its shell, and it was HYDRATION, not
  routing.** The owner's screenshot showed the ROOT error boundary (the
  unshelled `gofar;` page) for a dashboard 500, and every framework reading
  said impossible: `nearest_error_pages` walks up from the failed node and
  renders the nearest `+error.svelte` INSIDE the layouts that loaded — the
  SSR was proven innocent by a headless repro (throwaway fake lumen:
  session 200, dashboard reads 404 → SSR of `/` rendered the shell on BOTH
  the S1 and S2 trees). The real crash was client-side, in the browser
  console: `props_invalid_value — Cannot do bind:ref={undefined} when ref
has a fallback value`. The shell's hamburger was
  `$state<HTMLButtonElement | undefined>()` bound into `Sidebar.Trigger`'s
  `$bindable(null)`; Svelte threw at hydration, the throw landed INSIDE the
  error-boundary render chain, and the client router fell back to the
  OUTERMOST boundary — discarding the shell. Standing rules: **a two-way
  binding into a `$bindable` with a fallback must initialize `null`, never
  `undefined`**; and when an error page renders "wrong", check the browser
  console for a hydration throw before doubting the boundary logic. Pinned
  by fixtures + a dom test (undefined throws / null mounts).
- **2026-11-20 — S2 rode the shell onto the sidebar block; five small,
  load-bearing lessons** (`feat/shadcn-s2-chrome`):
  1. **Match RENDERED geometry, not declared vars.** The plan set the
     collapsed rail to 3.5rem because `--container-nav-rail: 56px` said so —
     but that var had ZERO consumers (56px is the topbar's height in DESIGN's
     diagram); the rendered rail was `lg:w-[4.25rem]`. Dead theme vars are
     not a spec; the screenshot is.
  2. **Context is only readable BELOW the Provider.** Svelte's
     `getContext` fails in the component that calls `setContext` — so the
     shell's footer toggle and sheet dismissal (both needing
     `useSidebar()`) forced the rail into a child component
     (`app-sidebar.svelte`). Any block wiring that needs the context
     belongs in a child; the topbar gets it free via `Sidebar.Trigger`.
  3. **`npm install` can wipe `.svelte-kit`**, and the scaffold `prepare`
     script's `svelte-kit sync || echo ''` swallows the failure — the next
     `vitest run` dies with `TSCONFIG_ERROR: $app/tsconfig not found`.
     Fix: rerun `npx svelte-kit sync` (or `npm run check`). A failing test
     suite right after a dependency change means this, not the code.
  4. **bits-ui v2 composes through the `child` snippet** — `Item` has no
     `href` (links render via child snippet receiving the menu-item props),
     and a destructive form-submit row is an `Item` whose child is the
     real `<button type="submit">`.
  5. **The block's inset variant is a lie for this design** — its `p-2`
     chrome tile + expanded-gap math render a floating panel, while mellon's
     shell is a full-bleed ONE-chrome-mass. `variant="sidebar"` + the
     doctrine line on `Sidebar.Inset` reproduce today's geometry exactly
     (D13); the breakpoint moved 768 → 1024 so the hamburger owns everything
     below lg (D12).
- **2026-11-20 — the shadcn S1 round minted three small, load-bearing
  discoveries** (`feat/shadcn-s1-foundation`):
  1. **The CLI resolves `package.json` `imports` aliases without a
     `svelte.config.js`.** Both the shadcn-svelte docs and our own plan
     assumed alias resolution needed the config file; mellon keeps config in
     `vite.config.ts` and has no `svelte.config.js` on purpose — yet
     `shadcn-svelte@1.8.1 add` read `components.json`, resolved `#lib`, and
     emitted clean imports (zero `$UTILS$` placeholders). The documented
     fallback fetcher was never needed. Lesson: probe the tool before building
     its fallback — the plan's 30-minute probe saved a ~70-line script.
  2. **A `var()` alias only needs to be declared once.** The plan wanted the
     18 shadcn aliases duplicated into both theme blocks; they are `:root`-only
     because every one points at a core token that already flips — the cascade
     does the theming. The palette guard (which demanded "every token in both
     blocks") had to learn the literal/alias distinction rather than be
     relaxed; duplicating would have _satisfied the guard while creating the
     drift it exists to catch_.
  3. **vitest 3+ projects split cleanly by FILENAME** (`*.test.ts` → node,
     `*.dom.test.ts` → happy-dom), so a 157-test pure-node fleet gains a DOM
     project without one test changing environment. Mirror the app's forced
     runes in the project's `svelte()` plugin or tests compile components in
     legacy mode — and pass `configFile: false` or the plugin logs a warning
     about the config file that intentionally doesn't exist.
- **2026-11-20 — theming the editor's chrome is HALF a theme.**
  `CodeMirrorEditor.svelte` painted `&`, `.cm-content`, `.cm-gutters` and
  selection from the semantic vars and considered itself token-driven — but
  `basicSetup` registers CodeMirror's default highlight palette as a
  _fallback_, and that palette is a LIGHT one (`#219` for `tags.url` +
  `tags.labelName` — the language word in ` ```mermaid ` — `#a11`
  strings). On the dark canvas those landed at ~1.3:1: the owner's
  "washed-out `mermaid`" report. Fix: one non-fallback
  `syntaxHighlighting(HighlightStyle.define(...))` (a non-fallback style
  outranks the fallback regardless of extension order), every spec resolving
  from the existing vars — links = `--foreground` + underline (preview
  parity with `--tw-prose-links`), metadata = `--muted-foreground`. Lessons:
  (a) a _fallback_ extension is a starter, not a default — if you accept it,
  you own its colors; (b) the source pane must obey the same tokens as the
  render, or "true-to-prod" is a claim about half the screen.

- **2026-11-17 — single-select widgets must REPLACE, not append.** The
  Combobox served both modes with one `toggle`: `[...selected, name]` — the
  multi idiom. With a pre-populated selection (photo detail + the table/tile
  per-photo pickers), a new pick produced `[old, new]`, and every caller's
  `next[0] ?? null` kept the OLD collection — the detail page's Save never
  armed, the list pages PATCHed the old name to lumen. Bulk escaped because
  its `selected` starts empty (append-to-empty ≡ replace — why the bug hid).
  Fix: the mode ternary in the component; contract comment already said
  "replace + close" — the code just never honored it. Ruling: when one
  component serves two contracts, the mode switch owns the SEMANTICS, not
  just the chrome.

- **2026-11-13 — one broken lazy-chunk killed the ENTIRE relay.** The
  markdown stack wasn't bundled deliberately until a single bad chunk took
  every portal page down (`499d595`). Standing rule: AGENTS §5 (keep the
  chunk boundary; it is load-bearing).
- **2026-11-13 — mobile split must STACK, not shrink.** The compare view
  collapsed to unusable at phone widths until panes were stacked with a wrap
  toggle (`4783059`). Standing rule: DESIGN §11 view anatomy.
- **2026-11-13 — pin-as-lock needs UI honesty.** When lumen redefined pins
  (intent → lock), the portal's copy went verbatim-on-wire: 403 rendered as
  lumen wrote it, plus a re-pin affordance. Standing rule: ghost-field
  doctrine (§6.1) — never decorate relayed server copy.
- **2026-11-13 — the dual-upstream split is ONE auditable table.** The
  role-split round moved every call behind `routing.ts` (session/users/
  setup/bao → ADMIN_URL; content → CMS_URL; unknown → throw). Standing rule:
  AGENTS §4.
- **2026-11-15 — the correlation id is MINTED here, never adopted from the
  browser.** The browser renders nothing correlation-shaped; a
  client-supplied id header is a log-injection surface. The access line's
  `hop` comes free from the routing table (`upstreamFor` — the table that
  decides WHICH lumen also names the hop). The id rides error objects
  (`AdminApiError.requestId`) for logs and support escalation, never for
  UI (ghost-field doctrine — the wire copy renders verbatim).
- **2026-11-21 — autosave is a port, not a feature; and the save dialog
  names attributes, never values.** The pending-edit round's two minted
  rules: (1) the buffer lives behind `PostEditStore`
  (`{ draft, baseRev }` — the proposed lumen working-copy wire shape) and
  the diff functions take snapshot PAIRS — so the server-autosave +
  versioned-head future is a constructor swap plus an API source, zero UI
  rework; the staleness knob (`EDITOR_AUTOSAVE_SECONDS`, vault-fed,
  default 60) means idle-debounce AND max-staleness in one number, so a
  big value can never starve the buffer. (2) The save-confirm dialog
  lists changed attribute NAMES only (owner call) — values live on
  `/posts/[slug]/diff`, whose left side is ALWAYS fresh head from the
  server (the editor's seed goes stale across tabs; the diff page's
  conflict notice reads baseRev vs head rev, and its save-anyway rebases
  onto head rev — the CAS stays the referee).
- **2026-11-15 — one module, many copies: the register must be global.**
  The runtime executes the metrics registry's SOURCE copy (server.js) AND
  its bundled chunk (the hooks chain) — with per-instance `new Registry()`
  the observations landed in a register nobody scraped (the smoke test
  caught it: the access line spoke, the /metrics output stayed empty).
  prom-client's DEFAULT register + idempotent `define()` is the fix (the
  smoke proved it: the outbound series appear in the scrape). And the
  ops are ENUMERATED per call site with the type enforcing it — the wire
  paths embed slugs/usernames, so a path-derived label would be a
  cardinality bomb. Standing rules: the registry is ONE plain-JS file;
  ops are compiled-checked against the registry; budgets ride flat
  MELLON_TIMEOUT_* env keys (missing or empty = default).
- **2026-11-15 — two boot blockers the rollout taught (the portal stayed
  up through BOTH, which is its own trap):**
  1. **The runtime image needs package.json** — the `#lib/*` alias lives
     in its `imports` field; without it server.js dies at boot
     (`ERR_PACKAGE_IMPORT_NOT_DEFINED`, 99a7d47). The v3.1.0 pod
     crash-looped while the OLD pod kept serving — "the portal works"
     masked a stuck rolling update. Check `rollout status`/pod states,
     never just the browser.
  2. **Auth-in-layout does not gate page loads** — SvelteKit runs layout
     and page loads in PARALLEL; the kubelet's probe on `/` (unauthed)
     fired the dashboard's four lumen dials anyway: four 401s per probe
     forever (0f224b0). Every (app) page load now opens with
     `requireAuthed` (a LOCAL cookie check — no lumen dial) and the
     auth-gate guard test walks the route tree. The probes also point at
     the M0-era `/healthz` (a probe must never render a page). Standing
     rules: new page loads gate FIRST; probes aim at static doors.
- **2026-11-13 — the wizard joined the threat surface.** The setup wizard's
  unauthenticated write path earned first-class TOFU analysis (V7) after this
  note's original scope was written; the detailing lives in this vault:
  [../archive/mellon-THREAT-NOTE.md](../../archive/mellon-THREAT-NOTE.md).
