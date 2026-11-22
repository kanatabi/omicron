---
tags: [mellon, lessons]
updated: 2026-11-22
---

# mellon — lesson ledger

The standing doctrine lives in the repo's
[DESIGN.md §2](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) and its
[AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md). This

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
