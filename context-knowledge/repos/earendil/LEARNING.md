---
tags: [earendil, lessons]
updated: 2026-11-25
---

# earendil — lesson ledger

- **2026-11-25 — duplicate src is LEGAL payload — a src-keyed each is a
  500.** The owner enabled in-gallery on a second upload of the SAME
  file (different alt text) and /gallery went down: lumen's storage
  lets multiple media rows share one object (identical bytes ->
  identical content-hash path — the eager-GC contract), so the gallery
  payload legally carries two items with the same src. Both photo
  loops (PhotoGallery, PhotoStrip) keyed `{#each}` on `photo.src` ->
  each_key_duplicate. Fix: key by the LIST INDEX — the grids are
  static (no client reordering), so the index is the honest identity,
  and no payload shape can crash them. **The rule: a keyed each must
  key on something the BE contract guarantees UNIQUE — or on the
  index.** The admin is unaffected (it keys by the unique media-row
  id). Recorded corollary: the FE-renders-BE-as-is doctrine means both
  duplicates RENDER — curation decides what belongs in the gallery.
The repo's standing lesson list lives in its own
[AGENTS.md §10](https://github.com/kanatabi/earendil/blob/main/AGENTS.md)
(ten entries, each minted by a real bug fix). This ledger records the walked
events that minted entries there and anything newer. Newest first.

- **2026-11-25 — the syndication round: the JSON-LD pattern gains a
  SERVER variant, and the at-html disable comment must be ONE line.**
  The layout's Person JSON-LD walks AGENTS §10.9's two traps with the
  split-tag pattern client-side; the per-post Article JSON-LD (built in
  `+page.server.ts`, injected via `{@html data.jsonLd}`) needed a third
  guard: **`<` escaped to `\u003c` in the stringified JSON** — a post
  title containing `</script>` would otherwise close the tag early
  (server-side strings aren't inside a script block, but the RENDERED
  page is). And the second trap: eslint's `svelte/no-at-html-tags`
  disable must be a **SINGLE-LINE** `eslint-disable-next-line` comment
  — a multi-line HTML comment breaks the association and the rule fires
  anyway (cost one lint cycle). Same-day corollary: the picker-preview
  bar lesson from mellon — percentage widths inside an indefinite
  flex-parent collapse to zero; earendil's prose guards exist for the
  same class. Update note in the vault README §5/§9.
- **2026-11-22 — THE WHOLE-POST CACHE + THE STREAMED LOAD: the navigation
  never blocks.** The owner's report: the homepage's article click = the
  2–5s stuck navigation. The cause: the post page's load awaited the lumen
  fetch AND the full markdown render before the route resolved — the
  SvelteKit router navigates only at the load's resolution. The mermaid =
  innocent (the placeholders + the client hydration — the agreed pattern,
  already shipped). Two levers: **(1) `renderMarkdownCached` — the
  whole-post cache keyed by the sha256 OF THE MARKDOWN: the key IS the
  invalidation** (an edit = new bytes = a new entry — zero staleness, zero
  invalidation logic, zero cross-replica logic: each pod computes the same
  answer); the published post = immutable between edits → the steady-state
  hit rate ≈ 100% → the render's seconds → ~1–5ms. **(2) The streamed
  load**: only the post's metadata is awaited; `html`/`toc` ride the SAME
  render promise un-awaited → the route completes at the fetch, the article
  + the TOC stream behind the prose-shaped shimmer (`{#await}` in the
  page). The cold post (the first view after an edit) = the shell + the
  skeleton instead of the stuck homepage; the warm hit = a blink. Standing
  rules: immutable content is cached content-addressed, never invalidated;
  a page's shell must never wait on its heaviest subtree. The tap-preload
  policy on the article cards = kept (the documented decision); the hover
  upgrade = now affordable if the owner wants it.

  decision); the hover upgrade = now affordable if the owner wants it.
- **2026-11-22 — THE COLD ENGINE: the last slow moment, retired at the boot.**
  After the cache + the stream rounds, the owner's re-test still showed a
  stuck 3–5s click on gofar.id — RIGHT AFTER the deploy. The server was
  acquitted by curl (the post = 13ms, the `__data.json` = 15ms — the cache
  working); the real killer: **the Shiki grammar build = the seconds of
  SYNCHRONOUS, event-loop-freezing CPU on the first render each pod
  serves** — the first traffic after a deploy froze the whole pod (the
  click's data request queued behind it; the stream could not flush). The
  fix = the boot warm-up: `hooks.server.ts` (the only eager touchpoint —
  the route modules load lazily; mellon's render module is doubly lazy,
  dynamically imported by the relay route) fires the engine build
  fire-and-forget at startup, where the k8s lifecycle expects the CPU (the
  old pod serves; the readiness probe retries). The boot logs
  `[boot] markdown engine warm`. Standing rule: **a process's expensive
  one-time builds run at boot, never on the first request** — the cold
  path is a deploy-window tax, not a visitor tax.

- **2026-11-21 — the typography plugin ships NO overflow-wrap; prose needs an
  explicit unbreakable-token guard.** A space-free token (pasted URL, key
  material, a keyboard-mash in a nested bullet) painted straight past the
  article column — and at phone widths the page-wide scrollable overflow turned
  the whole canvas into a pannable surface (body looked half-width, the fixed
  BottomNav sat in the left slice, full-page captures came out ~2× wide). The
  parent bullet "worked" only because its long lines had spaces — wrapping at
  spaces is not a wrap rule. Fix: one inherited `overflow-wrap: break-word` on
  `.prose` (`cde35a2`, branch `fix/prose-unbreakable-overflow`) + `break-words`
  on the post h1/preview. `break-word`, NOT `anywhere`: intrinsic/min-content
  sizing of grids and tables must not change; fenced code keeps its horizontal
  scroll (`white-space: pre` never wraps). Standing rule: earendil AGENTS
  §10 #10; mellon's vendored `.preview .prose` mirrors the guard (`850d1b4`) —
  keep the two blocks in parity. Diagnosed via markdown-it output (tight list →
  bare text node in `<li>`) + typography source (no wrap rule anywhere).
  **Audit addendum:** the audit walked every article-adjacent surface. Tables
  are the one thing wrap rules can NEVER fix (min-content is intrinsic) → the
  renderer wraps every table in a `.table-wrap` scroll box (`94155b3`). The
  base guard moved to `html` (every text surface: cards, search, about,
  captions); flex/grid items holding user text still need explicit `min-w-0`
  (breadcrumb, TOC entries, tag chips). Already safe, verified: images
  (preflight `max-width:100%`), code blocks (`pre` scrolls), mermaid (svg
  width 100% + failure path scrolls), `truncate` sites (nowrap unaffected).
- **2026-11-11 — `adapter-node` builds ship landmines without explicit
  bundling decisions.** The deploy container broke on the markdown family
  until deps were bundled/externalized deliberately (`8609828`, fix/ssr-dep-bundling).
  Standing rule: DESIGN.md deployment section + AGENTS §10.
- **2026-11-13 — platform semantics are learnable only live.** The per-bump
  environments + glob tag filter (`0f95cb4`) repaired two GitHub behaviors
  that no doc states plainly (environment approval scope; `on.push.tags`
  glob-vs-regex). Ledgered here because the fix rode this repo's release
  wiring; the full ruling lives in anvil AGENTS §5.
- **2026-11-15 — the correlation id is MINTED per call, never adopted.**
  earendil's seam (`requestid.ts`) mints a UUID per outbound call and
  echoes lumen's RESPONSE id when it answers — the echo wins, the minted
  id is the fallback (a caller that predates the echo still chains).
  Standing rule: one vocabulary file per app (`requestid.ts`), `request_id`
  in log fields, `X-Request-Id` on the wire — never `rid`, never a second
  spelling; the id rides error objects for logs but UI copy renders the
  wire message verbatim (ghost-field).
- **2026-11-15 — server-only machinery is INJECTED into shared code, and
  the metrics register is prom-client's DEFAULT global.** The SSR build
  bundles `src/lib/server/*` into a chunk while server.js imports the
  SOURCE file — two module instances of the same code. Per-instance
  `new Registry()` meant the hooks' observations landed in a register
  nobody scraped (the smoke test caught it: outbound series absent from
  /metrics); the DEFAULT global register (a property of the externalized
  prom-client module) makes every copy share one instance, and `define()`
  makes the metric definitions idempotent across copies. The same shape
  keeps the browser bundle clean: `client.ts` (shared) takes the
  observability seam as an INJECTED `instrument` param — server.ts passes
  the real wrapper, the browser gets an inert default (the proxy route
  bounds its own leg). Standing rules: metrics vocabulary in ONE plain-JS
  file; `$lib/server` imports never cross into shared client code (the
  build enforces it).
- **2026-11-15 — a probe that renders a page is a load generator.** The
  kubelet's probes hit `/` (liveness 20s + readiness 60s): each probe
  SSR-rendered the homepage and fired getPosts + listTags at lumen —
  the steady fake /api/* traffic the metrics exposed (exact beats,
  200s, 1ms, lumen-minted ids because the deployed image predated the
  correlation seam). The static `/healthz` door (the metrics hook
  already skipped it) + the vortex repoint is the fix. Standing rule:
  probes aim at static doors, never at pages — and when a rate graph
  shows exact fixed-period plateaus, suspect the probes FIRST.
- **2026-11-09 — real-first replaced mock-first** (owner ruling). The runtime
  always fetches lumen; the fixture twin is test-only. Standing rule: AGENTS
  §6.4. The trap it guards: any new "mock mode" runtime path.
- The ten §10 lessons (SSR paint vs hydration, scroller-absolute positioning,
  View Transition element split, SVG intrinsic size, touch reveals, Tailwind
  scanning, autofocus, hover-preload storms, script-adjacent gotchas) are
  dated by their fix commits in `git log` — `git log --oneline --grep` is the
  fastest way to date any of them.
