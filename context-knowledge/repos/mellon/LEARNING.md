---
tags: [mellon, lessons]
updated: 2026-11-20
---

# mellon — lesson ledger

The standing doctrine lives in the repo's
[DESIGN.md §2](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) and its
[AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md). This
ledger records walked events. Newest first.

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
