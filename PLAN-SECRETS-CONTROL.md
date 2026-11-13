# PLAN — Secrets Control Plane (apps are data)

**Status:** Phases A + B EXECUTED on `feature/secrets-control-plane` (lumen + mellon) — awaiting owner review/merge. Phase C deferred. **Repos:** `lumen/` (API), `mellon/` (UI), `vortex/` (deferred).
**Doc owner:** this file is the contract — update task checkboxes and the Decision Log here, not in chat transcripts.

## 0. Mission

`console.gofar.id` becomes the **central control surface for the whole infra**, starting with
the secrets plane: OpenBao stores secrets for _every_ service, so the portal must treat app
namespaces as **data, not code** — onboard any app, edit per-env values under a global
key-set invariant, inspect/pin/restore versions, and search within the selected env.
`lumen` is the first tenant, not a special case.

## 1. Owner-ratified decisions (2026-11-09)

| #   | Topic         | Ruling                                                                                                                                                                       |
| --- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Pin semantics | Pin = **operator intent** (badge/metadata). Reads ALWAYS serve head; any specific version is _viewable_ (`?version` already exists) — pin never reroutes reads or consumers. |
| D2  | Rollback      | **Included**: restore a version's values onto the CURRENT key set, saved as a new head. Removed keys do not resurrect.                                                       |
| D3  | Search        | **Current env, client-side**: fuzzy on key names AND values. No server search surface (values never flow wider than the view you already hold).                              |
| D4  | Env model     | Onboard seeds the **trio default** `dev/staging/production`; `POST /bao/{app}/envs` extends an app later, seeded with the canonical key set.                                 |
| D5  | Destroy       | App/env **destroy is out of API scope** (delete-grant is too heavy for a UI; Bao-side drills stay operator-only).                                                            |

## 2. Frozen design contract

Code to this table; if reality forces a change, record it in §8 before writing code.

### 2.1 lumen — `/admin/bao/*` (admin bearer; AppRole relays to Bao)

| Endpoint                      | Change       | Semantics                                                                                                                                                                                                                                                                                                           |
| ----------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /bao/paths`              | none         | already dynamic (scans `kv/metadata/`); lists EVERY app subtree — keep it so                                                                                                                                                                                                                                        |
| `POST /bao/apps`              | **new**      | body `{app, envs?}`; slug `^[a-z][a-z0-9-]{1,31}$`, no leading `_`; default envs = trio; creates each env as empty bundle `{}`; 409 if any env of the app already exists                                                                                                                                            |
| `POST /bao/{app}/envs`        | **new**      | body `{env}`; seeds the new env with the app's **canonical key set** = union of sibling envs' key sets, all values `""`; 409 if the env exists                                                                                                                                                                      |
| `PUT /bao/{app}/{env}`        | **extended** | existing CAS bundle write + **key-set mirror fan-out**: diff saved key set vs that env's PREVIOUS head; adds (`""` values) and removals applied to **all sibling envs**; values travel only for the written env; sibling writes CAS against each sibling's own head — stale ⇒ 409 `{"error":"mirror stale: <env>"}` |
| `GET /bao/{app}/{env}`        | none         | head, or `?version=N` (D1 — pin never affects this)                                                                                                                                                                                                                                                                 |
| `GET /bao/{app}/{env}?meta`   | **extended** | adds `pinnedVersion` (nullable), read from KV-v2 `custom_metadata`                                                                                                                                                                                                                                                  |
| `PUT /bao/{app}/{env}/pin`    | **new**      | body `{version}`; validates the version exists; PATCHes `custom_metadata {"pinnedVersion":N}` on `kv/metadata/{app}/{env}`                                                                                                                                                                                          |
| `DELETE /bao/{app}/{env}/pin` | **new**      | clears `pinnedVersion` from custom_metadata                                                                                                                                                                                                                                                                         |

### 2.2 Invariants & doctrine (binding)

1. **Apps are data** — zero app-specific logic in lumen/mellon; no allowlists; `{app}` is an opaque validated slug. (A future `if app == "lumen"` anywhere = design violation.)
2. **Key sets are structurally identical** across all envs of an app; values are per-env. The mirror on the write path is the enforcement point.
3. **Head is what you see** — editors, consumers (ESO), and reads never consult the pin.
4. **Vocabulary** — app slug == the infra service name (vortex kustomize dir / Argo app name). GitOps still owns deployments; this portal owns secrets.
5. **Logging doctrine holds** — new endpoints log `op + app + env + version + key-counts`, NEVER values. No `sys/` routes. No destroy endpoints (D5).
6. **Blast radius** — the only new Bao capability grant is `patch` on `kv/metadata/*` (dev-plane.sh + §5.6 prod seed note). Read/list/write on `kv/data/*` stay as-is.

### 2.3 mellon — `/secrets` page

- **App picker** (grouped from `paths` data) → **env tabs** (child of selected app) — replaces path chips; everything renders from data (no hardcoded env/app).
- **+ onboard app**: name field → `POST /bao/apps` → select it, land on `dev`.
- **+ add env** (small action on the env tab strip) → `POST /bao/{app}/envs`.
- **Search bar** (D3): client-side fuzzy (subsequence scorer, unit-tested) over current env's rows, key + value; "n of m keys" counter; clear-x.
- **Pin badge**: header shows `v{head}` + `pinned v{N}` when set (amber when `N ≠ head`); badge click → **diff pinned-vs-head** (reuse `lineDiff`/`diffLines`).
- **History drawer**: per version row — `view` (read-only payload), `diff` (exists), **`pin`** (PUT pin), and **`restore`** (D2: overlay that version's values onto current key set → normal save flow, so mirror fan-out applies).
- Dirty-dot / unsaved / watermark behavior unchanged; Watermark still masks values.

## 3. Task breakdown — Phase A: lumen (start here; its API is the contract)

**Branch:** `feature/secrets-control-plane` forked from `refactor/layered-architecture`
(handlers + adminsvc already live there; merge order: layered → main FIRST, then this —
see §7 risks). Validate with dev plane up: `scripts/dev-plane.sh` → `dev-plane.env`.

- [x] **A1 — pure core** `internal/adminsvc/secrets_pure.go` + `_test.go`
      Validate `keyDelta(oldSet, newSet) → (adds, removes)`, `unionKeys(map[env][]key)`,
      slug validation, canonical-set selection. NO Bao/DB imports.
      **Accept:** table-driven unit tests pass with no network; covers empty-env,
      remove-all, add-after-remove races as pure data.
- [x] **A2 — bao client** `internal/bao/bao.go`
      `Meta` gains `PinnedVersion *int` (parse `custom_metadata` from
      `GET kv/metadata/{app}/{env}` — Meta op must start reading the metadata endpoint);
      `PatchMetadataCustom(ctx, app, env, map)` for pin/unpin; `CreateIfAbsent`-style
      write helper for seeding empty bundles.
      **Accept:** unit tests for parsing (fixture JSON); wire-shape documented in code.
- [x] **A3 — service methods** `internal/adminsvc/` (secrets section)
      `OnboardApp`, `AddEnv`, `Pin`, `Unpin`, and the **WriteSecret mirror** (uses A1's
      keyDelta + reads sibling heads). Sibling CAS-stale ⇒ typed error carrying env.
      **Accept:** integration test (A5) proves fan-out; pure logic already proven in A1.
- [x] **A4 — handlers** `internal/api/admin/secrets.go`
      Mount the four new routes per §2.1; status mapping: 400 slug, 409 exists/stale,
      404 pin-version-unknown, 503 plane-disabled (existing pattern). Logs per §2.2-5.
      **Accept:** handlers stay thin (adminsvc owns logic — the repo's import rule
      still holds, check `db50d1b`-era test that guards it).
- [x] **A5 — dev plane + integration tests**
      `scripts/dev-plane.sh`: policy gains `path "kv/metadata/*" {capabilities=["read","list","patch"]}`.
      `internal/api/bao_integration_test.go` additions (same env-gating style): onboard
      `itest-app` → paths shows 3 envs; write w/ key added → siblings gain `""` key;
      remove → gone everywhere; pin/Unpin/meta roundtrip; sibling-stale 409.
      **Accept:** `go test ./...` green (with plane) and green (skipped, without plane).
- [x] **A6 — docs**: `lumen/DESIGN.md` §9 mirror (apps-are-data rule, endpoints table,
      pin semantics D1); journal in `lumen/PLAN.md`.

**Gate A:** `gofmt -l .` empty · `go vet ./...` · `go build ./...` · `go test ./...` ·
manual curl of every new endpoint against the live dev plane.

## 4. Task breakdown — Phase B: mellon (after A4/A5 ship)

- [x] **B1 — API layer**: `src/lib/api/types.ts` + `fetch-adapter.ts` — new methods
      (`onboardApp`, `addEnv`, `pin`, `unpin`), `SecretMeta.pinnedVersion`, mirror-stale
      error surfacing; extend the test-only twin if AdminApi has one there (check
      `mock.ts` scope) and keep contract tests honest.
      **Accept:** unit tests for adapter (mapping, 409 shapes) pass offline.
- [x] **B2 — fuzzy scorer** `src/lib/fuzzy.ts` (pure) + tests: subsequence + prefix/word
      bonus, stable ranking. **Accept:** vitest cases incl. empty query = identity order.
- [x] **B3 — pickers + onboarding**: app select / env tabs / `+ onboard app` dialog /
      `+ add env`. Data-driven only — grep gate: no `'lumen'|'dev'|'staging'|'production'`
      string literals in the page logic (defaults come from the API/`POST` contract).
- [x] **B4 — search bar**: filter rows via B2 on key+value, n-of-m counter, escape clears.
      Keyboard-first.
- [x] **B5 — pin UI + history actions**: badge, badge→pinned-vs-head diff, per-version
      pin/view/restore. Restore = overlay-onto-current-keys then normal dirty-save path (D2).
- [x] **B6 — console harness scenario**: end-to-end on throwaway `harness-app`:
      onboard → trio exists → edit dev adding KEY → switch staging → KEY present empty →
      search filters → pin v2 → badge amber after a v3 write → restore v2 → unpin.
      Teardown: none (dev plane is in-memory/re-seedable; document in the test comment).
      **Accept:** full mellon gate suite + `npm run test:console` green.
- [x] **B7 — docs**: `mellon/DESIGN.md` §9 rewrite (control-plane posture), journal in
      `mellon/PLAN.md`, root `AGENTS.md`/`INFRA_ARCHITECTURE.md` §5.6 note: prod
      `fzr-portal` policy must include `patch` on `kv/metadata/*`.

**Gate B:** `prettier` · `npm run lint` (standalone, exit 0) · `npm run check` 0/0 ·
`npm run test:unit` · `npm run build` · `npm run test:console`.

## 5. Task breakdown — Phase C: deferred (explicitly NOT in this round)

- [x] C1 — apps×envs **overview matrix** pane (head/pin/empty-key drift per app) — the
      data model (meta.pinnedVersion + paths) is already shaped for it.
- [x] C2 — `driftcheck` pin-aware (warn when head ≠ pin in CI/CLI). Shipped
      branch `feature/c2-pin-driftcheck` (unmerged): meta seam + unit tests +
      LIVE proof (real pin-under-head, default exit 0 warns, --strict-pin exit
      1, plane restored, battery 7/7).
- [x] C3 — ExternalSecret CR alignment — ABSORBED by the 2026-11-10 key-set
      cutover (property==secretKey 1:1 doctrine in the CR headers did the
      generator's job by hand; the portal matrix + pin-aware driftcheck now
      watch alignment continuously — a generator would emit what the CRs
      already ARE). Portal-suggests-YAML stays a recorded future, not a task.
- [ ] C4 — prod seeds (vortex): §5.6 policy w/ patch cap; kv seeds for new apps.
- [x] C5 — integration-path isolation: the battery must OWN an `itest/`
      prefix (relay test currently purges/reseeds `kv/lumen/dev` — the same
      path a HUMAN browses; an old-worker + shared-queue incident proved the
      collision class). Move relay-test ownership to `itest/*` paths.

## 6. Test ledger (where each promise is enforced)

| Promise                         | Guard                                          |
| ------------------------------- | ---------------------------------------------- |
| key-set invariant across envs   | A1 unit + A5 integration + B6 harness          |
| pin never reroutes reads        | A5 (read after pin == head)                    |
| app-agnostic                    | B3 literal-grep gate + code review rule §2.2-1 |
| no values in logs               | A4 review + existing doctrine                  |
| search correct + no server leak | B2 unit (pure), D3 by construction             |
| rollback keeps keys current     | B5 + B6 restore leg                            |
| dev plane policy patch granted  | A5 (pin op fails loudly without it)            |

## 7. Risks & orders

- **Merge order dependency**: layered refactor is unmerged. Ship layered→main (owner), then
  rebase/merge `feature/secrets-control-plane`→main. Do NOT fork from main — the handler/
  service split moved under the owner's feet mid-flight.
- **Sibling CAS races** (two tabs editing): mirror returns named-env 409; UI shows the
  existing conflict copy + reload. Acceptable at admin-single-operator scale; documented.
- **Pin before patch-capability**: if dev-plane isn't re-run, pin endpoints fail with a
  permission error surfaced as 502/500 — the runbook line in A5 docs ("re-run
  scripts/dev-plane.sh after pulling").
- **`harness-app` residue** in dev plane: intentional (D5); `FORCE=1 make seed` clears.
- **KV v2 custom_metadata availability**: OpenBao inherits it (dev runs real OpenBao,
  per bao.go header) — verified by A5 integration, not assumed.

## 8. Decision log (append-only)

- 2026-11-09 — D1..D5 ratified by owner (chat → this doc).
- 2026-11-09 — **A1 shipped** (`lumen@20336ee`, branch `feature/secrets-control-plane`
  off post-merge main — the §7 merge-order risk retired). Naming deltas from the
  sketch: functions exported (A4's package + integration tests consume them);
  `unionKeys` implemented as `CanonicalKeySet(map[env]payload)` — takes payloads
  directly so A3 never hand-rolls the projection; `KeySet` added as the sorted
  projection both share. The mirror's write-gate (`ApplyDelta → changed`) is the
  §7 two-tab-race answer: raced siblings keep their values AND skip the write
  (no gratuitous version bump, no fake 409) — unit-proven as pure data.
- 2026-11-09 — **A2 shipped** (`lumen@9382b75`). Bonus find by the fixture
  test: the pre-A2 `Meta` decoder string-keyed the versions map into
  `toNum` → EVERY VersionInfo.Version was 0 in production (mellon history
  showed 0/0 since day one; the twin was right, live was lying). Fixed via
  `strconv.Atoi` + skip-unparsable. New wire ops: `PinnedVersion *int`
  (custom_metadata, D1 intent-only), `PatchMetadataCustom` (RFC 7396 —
  unpin = null), `CreateIfAbsent` (cas=0) with `remapExists` →
  ErrAlreadyExists for onboarding collisions. B-phase note: mellon needs NO
  twin change — live finally matches it.
- 2026-11-10 — **Phase A complete** (lumen branch `feature/secrets-control-plane`:
  A1 20336ee, A3 7fb5ba0, A4 77b8064, A5 98563b9, A6+A2). Deviations recorded:
  ① the mirror IMPLEMENTS RECONCILE (siblings pulled toward the saved shape)
  instead of delta-vs-previous-head — strictly stronger: an interrupted mirror
  heals on the next write; value-only edits bump nothing (proven live in A5).
  ② pins ride custom_metadata AS STRINGS (engine is map[string]string; numeric
  answers 500) and the PATCH needs `application/merge-patch+json` (SDK sends
  scim+json → 415). Both discovered by the live battery, documented in lumen §9.
  ③ A5's own script learned to CAS-from-meta after the mirror 409'd it — the
  invariant refusing a naive test is the invariant WORKING.
- 2026-11-10 — **Phase B complete** (mellon same branch: B1, B2, B3-B5 5c588cc,
  B6, B7). Twin now carries the INVARIANT (mirror/union/pin as executable
  contract); harness 45/45 exit 0 driving the whole lifecycle UI against live
  lumen+OpenBao (T-plane1..7). Svelte trap family extended: regex quantifiers
  in static attributes are EATEN as interpolations; markup expressions may not
  START with a regex literal (parses as block-close). Test truths: aria-label
  pinning over nth selectors; no auto-travel after add-env (tab-then-visit);
  the modal history drawer must be dismissed before header-edge clicks.
  D5 honored: harness apps persist (run-fresh names; FORCE=1 make seed resets).
- 2026-11-10 — **dev-box state for the morning**: lumen :8080 serves the
  BRANCH build (`make server` from feature/secrets-control-plane, nohup — the
  pre-A server was retired; `make dev` reuses whatever serves :8080, so
  restart it after reviewing to pick merged main). Pins NOT moved: both
  children carry pending work on unmerged branches, by design.
- 2026-11-10 — **owner add-on: palette verbs** (mellon `33d0c3c` "register
  control-plane verbs"): secrets verbs registered in the §7
  command contract incl. the filter editField buffer; harness 48/48.
  Test-harness truths journaled: palette-target-by-aria-label, cancel
  over Escape, settle-before-count.
- 2026-11-10 — **dev-plane collision finding (owner's "can't see the
  value")**: lumen/dev had been purged mid-cycle — the A5/A6 integration
  battery OWNS kv/lumen/dev (bootstrapPlane purges it at run start), so a
  test run racing a human's browser session can show empty/gone state.
  Plane RE-SEEDED via scripts/dev-plane.sh (values back: v1 trio). Phase C
  candidate C5: move relay-test ownership to an `itest/` prefix so human
  dev data and the battery never share paths.
- 2026-11-10 — **compare round shipped** (mellon `73f5d26`; design ratified
  in chat): same-path versions ONLY (cross-env diff refused by doctrine —
  per-env secrets side by side is a leak pattern); presentations
  table/split/inline × content parsed/raw (raw visibly disabled in table —
  the UI states its own rules); masking applied BEFORE serialization
  (displayValue is the single rule, shared with the editor's reveal-all and
  viewing panel); reveal-all display-only, never persisted; prefs persist
  behind the primitive-flag guard (the INTERNAL-200 lesson applied
  preventively); nav child 'compare' TRIED per owner, with longest-match
  highlighting fixing the double-lit rows nested hrefs caused; mobile
  header stacks (the owner screenshot), orderEnvs gives dev→staging→
  production everywhere. Battery truths: '2 of 4' assertion was MY math
  error — reality said 3 changed keys and the UI was right; the raw-json
  click deadlocked on the button the UI deliberately disables — commented
  choreography now. Harness 55/55 (+7), 71 units, visuals in shots/.
- 2026-11-10 — **mobile honesty sweep + sheet ruling** (mellon, this-day
  commit): bottom-sheet rails show the PRE-DRAG view (owner): collapse-only
  — SectionCard `reorderable` prop + `movable` snippet params on all three
  rails; desktop unaffected. Two owned regressions fixed: the backwards
  `max-lg:hidden` sheet trigger, and `[data-pane] contain: layout style`
  REMOVED (stacking contexts buried sibling popovers — the re-anchor sweep
  missed paint order; the perf it bought was marginal next to the slot
  cache). Popover placement gained a viewport-fit FLIP (the older bug
  containment had masked); palette right-anchored; breadcrumb truncate finally
  bounded. Harness 64/64 (+7), lessons folded into DESIGN §6.1-adjacent
  journal. C5 (itest prefix isolation) still open.
- 2026-11-10 — **tag desk round** (branch `feature/tag-desk` in lumen+mellon,
  owner-ratified design): ① migration 0006 tags.created_at/updated_at (any
  desk touch stamps updated_at; recency true from today, not retroactive —
  said in the SQL itself); ② cloud→featured ② tag MATCHING moves to
  MEILISEARCH ({id,name} docs, counts/featured hydrate from Postgres —
  superseded doctrine recorded honestly: "a name, not a document" held only
  while prefix lookup was the engine's best offer; typo tolerance is now ONE
  story across posts/photos/tags); ③ desk list doors (/admin/posts,
  /admin/photos) accept ?q → engine route with facets; photos date windows
  CANNOT ride (PhotoDoc lacks day) → chips visibly pause during search;
  ④ featured is MANUAL promotion only (owner ruling), public widget =
  featured AND posts > 0 ("a featured tag at zero is ready, not display-
  worthy") — earendil untouched, contract shape preserved; ⑤ the /tags desk
  page: lean rows (checkbox/name/posts/featured-pill), row→dialog (rename/
  feature/used-by roster/timestamps/delete-with-count), bulk feature via one
  tx (updated = ACTUAL changes), engine search bar + pager on the URL;
  ⑥ dashboard becomes an append-ready card grid (posts/photos/tiles/tags,
  Traffic slot contract commented). Orchestration: 2 recon + 3 implementation
  subagents over disjoint file ownership; main held the convergence gates.
  Runtime discipline learned the hard way twice: queue-affecting deploys MUST
  restart the running `lumen` (an old worker binary rejected index_tag jobs
  sharing the dev queue), and pgrep/pkill patterns self-match the invoking
  shell — filter by /proc/comm before killing.
- 2026-11-10 — tag-desk round MERGED to main (lumen 7b744cb + hygiene fix
  ed23dc3 purging .vite junk an `add -A` swept in; mellon ff1d135) and pins
  bumped at root. Gates at both merge tips green (lumen 7/7 live battery,
  mellon 79/79 console harness). Phase C + C5 (itest prefix isolation)
  remain open by design.
- 2026-11-10 — **estate round executed** (branch `feature/estate-round` both
  repos, unmerged for review): C5 (battery owns itest/relay — proven by a
  plane restart mid-round) and C1 (summary sweep + matrix page + twin + 6
  harness asserts, 85/85). Gate discipline repaired mid-flight after two
  tail-masked-exit slips: every gate now records its exit code explicitly.
- 2026-11-10 — **ESO pin raised 0.1.4 → 2.15.0** (vortex branch `chore/pin-eso-2.15.0`,
  unmerged). The 0.1.4 was an un-confirmed placeholder from the pre-1.x chart lifecycle;
  ESO unified operator+chart versioning in 2.x, and v2.15.0 is current (published today;
  operator tag + helm-chart tag + artifacthub cross-checked — the v1.5.0 the older docs
  cite does not exist as a tag). Never deployed => pin-before-first-install, no migration;
  all CRs already on stable external-secrets.io/v1. First-sync checklist now rides the CR
  comment (kubeVersion vs k3s, helm show values key audit, store-Ready order); verified
  during k3d rehearsal, not at prod. INFRA §5.6 + tree line updated to match.
- 2026-11-10 — **gitops alignment round** (vortex branch `chore/gitops-repo-and-es-keys`
  + `chore/container-hygiene` on all three children; estate-round merges pinned at root):
  repoURLs repointed to kanatabi/vortex (9 machine-critical spots incl. the hub);
  ExternalSecret key sets CUT OVER to the real env contract (property == secretKey,
  1:1 — the old lumen trio was drift that would have booted prod pods blind while
  every shape check passed; SESSION_JWT_SECRET was missing entirely); ORIGIN ruled
  dead and removed everywhere (no reader in any repo); NEW rulings recorded in the
  CR headers: LUMEN_MEDIA_* waits GATE #9, LUMEN_BAO_* relay creds ride the §5.6
  bootstrap family NOT an ExternalSecret (bootstrap paradox); dev overlays added for
  the local-cluster ESO rehearsal (bases stay ESO-free — opt-in by path). Container
  audit: all three Dockerfiles EXISTED (previously unbuilt) — lumen gained a
  .dockerignore (dev-plane.env would have baked into images), earendil/mellon comment
  fictions corrected; PROOF: docker build x3 + live SSR/auth smoke against dev-lumen
  all exit 0. NOTE: the owner merge sweep missed vortex `chore/pin-eso-2.15.0` —
  still unmerged; the new branch is file-disjoint so either merge order works.
- 2026-11-10 — **single-node + runbook round** (vortex branch `feature/single-node`
  4 commits + lumen `feature/c2-pin-driftcheck`, both unmerged): the 1-node shape
  is now first-class GitOps (components/single-node + selfsigned, overlays/local
  chain, apps/single-node hub CRs with STRUCTURAL wave gating — store-Ready
  before apps, seeded-Bao before store); mellon got its manifests; the
  REPLACE_AT_BOOTSTRAP placeholder is DEAD (appRole.roleRef verified against the
  shipped 2.15.0 CRD — both Bao creds now ride the bootstrap Secret; doctrine
  restated: Git templates, Secrets bootstrap, Bao values); lumen got the
  lumen-bao-credentials envFrom landing (optional:true keeps k3d honest);
  RUNBOOK.md at root = one doc for minikube rehearsal + single-VPS production +
  scale-out, pins researched and named (argo v2.13.2 vs k3s 1.37 flagged
  known-unverified until the live walk). Dev plane proven as the seed-shape
  reference: portal/eso policies, role writes, driftcheck live demo.
- 2026-11-11 — **RUNBOOK Part A walked to completion** (the "first live walk"
  item closed). Full estate Synced/Healthy on minikube; portal login proven on
  both postures (http→non-Secure cookie, https websecure→Secure); pin-drift
  amber cell demonstrated through the matrix; PreSync `lumen migrate` hook
  executed on real syncs. Rounds that came out of the walk (all merged):
  mellon `fix/session-cookie-secure` + `fix/preview-runtime-bundle` (the
  self-contained-server doctrine amended — jsdom/shiki are bundle-hostile,
  prod node_modules now ship; SSR externals audited to bare-specifier zero),
  lumen `feature/c2-pin-driftcheck` (driftcheck pin-aware + `migrate` verb —
  battery 7/7 post-merge after an overnight dev-plane container loss),
  vortex forwarded-headers + DSN-truth sweeps, earendil env.ts fossil.
  Vault was BORN, died (lost unseal key — /tmp is not offline storage, the
  runbook's own rule violated by its author), and was reborn: the A8b reinit
  recipe (incl. the hostpath ns/claim-keyed data-dir trap) is walk-proven.
  Earendil `about-page` + `hero-ascii-reveal` ruled STALE (Option A: never
  merge, keep as refs — content landed via earlier PRs; trees are far behind
  main). C2 also formally closes what C1's matrix previewed: pin intent is
  now watched by CLI, CI (--strict-pin) and the portal simultaneously.
- 2026-11-11b — **post-walk hardening** (owner driving the portal live caught
  what the smoke missed): earendil's deepest route (/posts/[slug]) 500d on
  ERR_MODULE_NOT_FOUND markdown-it — vite externalizes ALL node_modules in SSR
  builds, so every undeclared-at-runtime dep was a landmine in BOTH SSR apps
  (mellon's preview proxy fell to the same class minutes earlier; fixed there
  first). Policy now: markdown-it family noExternal (pure JS bundles),
  shiki/jsdom chain external + pruned prod node_modules in the image (package-
  layout resolvers, unbundleable in any output mode); audits grep bare
  specifiers, humans don't discover them at runtime. Deepest-route rule written
  into RUNBOOK A10. Owner decisions executed: lumen runtime distroless ->
  pinned alpine:3.24.4 (uid 65532 + CA certs kept — `kubectl exec` matters
  more than purity when the pod misbehaves); earendil ingress cut over to
  gofar.id/www (their own commit, walk-verified). Full post pipeline proven on
  cluster: anchor-h1, Shiki fence, mermaid-src, task-list, search leg — zero
  module errors. Portal CSRF confirmed healthy on both paths (the 403 that
  started this was a curl missing Origin, and the answer is the guard WORKS).
- 2026-11-11c — **setup-wizard round** (merged lumen+mellon mains): the estate
  bootstraps itself — /setup registers the first admin via TOFU (advisory-lock
  atomic; 410 Gone forever after; no admin-password Job in the primary path,
  CLI demoted to recovery), must_change temps (server-generated syllable
  passwords, one-time reveal, ~50 bits) are guided back through /setup, and
  the 428 forced-change lock is transport-enforced in lumen (roles/flags read
  per request — never JWT claims). lumen migration 0007 + battery e2e on a
  scratch schema; mellon twin mirrors the invariants + 8 new harness asserts
  (94/94). Cluster redeployed along the way: one-shot lumen migrate Job (the
  PreSync hook automates that ordering forever), portal + users desk verified
  live on the rehearsal cluster. Wizard security note queued FOR GATE #5: the
  TOFU window (empty users + reachable portal) is bounded by console.gofar.id
  staying dark until #10 — the registration endpoint is the estate's only
  unauthenticated write, and the review should say so out loud.
- 2026-11-11d — **IA round merged (mellon feature/nav-ia)**: nav is now
  Content / CONTROL PLANE (Configs = summary-matrix landing, Vault, Compare —
  future GitOps features live here) / Admin (Users); Settings + identity
  (username · role, from whoami) + End session form the footer account story.
  Routes /configs[/vault|/compare] + /admin/users with 308 word-migration
  redirects (query-preserving; owner DECIDE-2). Password: ONE flow
  (performPasswordChange: change→revoke→re-mint) behind two doors — wizard
  forced mode + new Settings security card (voluntary rotate). Sentence-case
  sweep across rendered chrome (brand 'mellon' stays lowercase; mid-sentence
  wraps untouched). Harness 94/94; cluster redeployed + every route 200 live.
  Sweep hazards logged for future us: a template token-line sweep hit a
  SHORTHAND PROP (pinned — svelte-check caught it), a nav locator collided
  with the settings card (assertion scoped), and child loads shadowing the
  layout's `principal` key became `account`.
- 2026-11-11e — hotfix post-IA (owner-found): mixed actions in
  settings/+page.server.ts (default vim + named password) violated Kit v3's
  "named actions exclude default" rule -> EVERY settings POST 500d
  (action_default_with_named). Named-only fix merged; T-wiz9 regression
  pinned (95/95); cluster re-verified. Lesson added: routes' actions are an
  either-or contract, and no test had ever POSTed the settings forms before.
- 2026-11-11f — Chrome drag-lifecycle round (owner-reported): the portal's
  mouse drags died in real Chrome while every synthetic-DragEvent test passed
  — the harness's blind spot, now closed by T-dragm (real CDP drag session,
  96/96). Two fixes merged (mellon fix/chrome-drag-lift): the drag-image
  capture race (bar removed at setTimeout(0) while Chrome snapshots on the
  NEXT FRAME -> empty capture voids the drag; bar now lives to dragend) and
  the hidden-source commit classic (lift deferred one task). Lesson for all
  future browser-touching work: headless + synthetic events cannot see Chrome
  lifecycle semantics — tests must drive the real input pipeline, and the
  human browser is the last gate (owner verification pending on their Chrome).
- 2026-11-12 — **Phase 6 executed: anvil (fifth submodule, @50e1257) + CI across
  all four consumers.** anvil ships validate-all (+expected-kinds table,
  generated from and re-verified against reality: 25 dirs), diff-render
  (rendered-manifest diffs — reviewers see what Argo applies), set-image-pr
  (bump branch + deploy-bump PR, dedupe, --dry-run proven), guarded
  auto-merge (label ∧ head-prefix ∧ path-fence ∧ line-fence ∧ checks-green ∧
  DEPLOY_AUTOMERGE=on — absent=OFF), and two composite actions with ZERO
  third-party dependencies. En route discovery with teeth: kustomize edit
  REWRITES files canonically → first bot diff would have tripped its own line
  fence; fixed human-first via vortex canonicalization commit (seeded no-op
  images: stanzas) — measured dry-run now diffs exactly two lines. Workflows
  live: lumen/earendil/mellon gates + publish-and-pin on main; earendil gains
  the live-contract job (real lumen + pg16.6 + meili v1.56.1 seeded corpus —
  the program's first rule, automated); vortex validate + auto-merge wired
  but switched OFF until the owner creates DEPLOY_AUTOMERGE. Owner one-timers
  remaining: GHCR package visibility after first push (inherits repo
  visibility), the variable itself, and the first real bump walkthrough.
  Noted drift found on the way: compose pins meili v1.56.1, cluster manifests
  v1.10.0 — reconcile before VPS (engine versions move search semantics).
- 2026-11-13 — **Release-only deploy model executed (Phase 6b).** Owner ruling:
  a `release.yml` dispatch (patch|minor|major) IS the deploy decision — branch
  merges gate and ship NOTHING. Chain: gates → anvil `semver-release` (newest
  v-tag + bump math → tag + GitHub release; no-tags: major→v1.0.0 ceremony,
  minor/patch→v0.1.0) → `publish-image` (build AT the tag; `:latest` alias is
  tooling-only, banned from pins) → `deploy-bump` PR (vortex fenced auto-merge
  behind DEPLOY_AUTOMERGE, absent=off). anvil refactored @59e8090 (publish-and-
  pin split + deleted; set-image-pr now PAT-authenticates the CLONE — vortex is
  private and anonymous clone 404s; the contract-job failure was the same
  privacy-lie mechanism until the owner made lumen public, dissolving the need
  for a cross-repo read token). Consumer workflows: ship deleted from 3× ci.yml,
  release.yml added (lumen 431479b, earendil 9fb56ca, mellon f75917a); prettier
  polices the new YAML in both node repos (the earendil self-inflicted red gate
  turned out already fixed by the owner — 5406567, direct-to-main, noted).
  Wave-3 integrity sweep caught a REAL defect agents' reports could not: all
  three earendil anvil pins were 39-char transcriptions (GitHub resolves
  `uses:` only at dispatch — CI was structurally blind to it); repaired a4b50c3,
  all 9 refs byte-verified against anvil main. Same sweep rewrote stale ci.yml
  headers (lumen 0a71470, mellon 7b1efa9). Vortex: meili manifests v1.10.0 →
  v1.56.1 (7e32ad4) — cluster now runs what dev+CI test. Docs: RUNBOOK gains
  A12 (ship-a-release + owner pre-flight), B5 and §5 rewritten to release-only;
  INFRA Phase 8 amendment callout; AGENTS #4 now says released v-tags only.
  Remaining owner one-timers before first-light: GHCR package visibility
  (private packages ⇒ ImagePullBackOff at first v-tag sync; public recommended),
  then one watched manual cycle (suggest lumen major → v1.0.0) before any
  DEPLOY_AUTOMERGE exists.
- 2026-11-13 (2) — **Phase 6c: approval-gated releases (the human-controlled
  semver the owner asked for).** Model superseded once more, to its resting
  shape: merge-to-main runs gates and PARKS THREE waiting jobs —
  semver-patch|minor|major — on the protected `release` environment; a human
  approves EXACTLY ONE (approving = the release decision, bump level literal,
  zero derivation), the job pushes the annotated tag via the new
  **RELEASE_BOT_PAT** (Contents:RW on the three app repos only — compartmented
  from the vortex bump hand) **because a GITHUB_TOKEN-pushed tag never
  cascades to another workflow: the silent no-deploy trap; push-release.sh
  now REFUSES outright without the PAT — a red job beats a ghost release.**
  The tag push fires release.yml: build (:vX.Y.Z + :latest alias) → deploy-
  bump PR → fence → Argo. No gates in release.yml — the tag can only exist on
  a gates(+contract)-green commit, so re-verification would be theater.
  ci.yml gains a concurrency queue (no two runs compute the same next-version).
  anvil @7183eb2; consumers lumen 63d4c7b, earendil fded870 (semver needs
  gates AND contract — never release the blog against a drifted API), mellon
  85bc42c; all 15 pins programmatically copied + byte-verified (the 39-char
  incident is now doctrine: sed from rev-parse, never the transcript).
  FAIL-OPEN WARNING recorded in anvil README + RUNBOOK A12 + every workflow
  comment: a job referencing a NONEXISTENT environment gets it auto-created
  UNPROTECTED — protection must predate the workflows. PROVEN the same hour:
  lumen run #4 parked `waiting` on the first approval-model merge (verified
  via public API from the workstation). Owner one-timers now done:
  RELEASE_BOT_PAT, three `release` environments. Remaining: GHCR visibility
  flips for earendil/mellon packages before their bump PRs merge; first
  cascade (approve lumen semver-major → born v1.0.0) is the untested seam;
  pre-existing lumen ci.yml hand-edit found uncommitted in the worktree,
  stashed (`stash@{0}`) — superseded by feat/approval-jobs, owner may drop.
- 2026-11-13 (3) — **Phase 6d: the first live approval taught the platform,
  twice, for free.** Lesson 1: environment reviews BATCH PER ENVIRONMENT —
  one approval of the shared `release` env released all three bump jobs
  (v0.1.0 + v1.0.0 pushed; patch died red on the duplicate-tag guard — the
  guard proving itself unrequested). Fix: nine per-bump environments
  (`release-patch|minor|major` x3 repos), environments NEVER shared; lumen
  run #5 then parked all three jobs waiting INDEPENDENTLY (API-verified) —
  fix proven same hour. Lesson 2: a fine-grained PAT without the
  **Workflow permission** pushes refs whose events GitHub never even
  records (events API: two ReleaseEvents, ZERO PushEvents) — so release.yml
  got no trigger at all; the "cascade key" was missing half its teeth. Fix:
  owner granted Workflow:RW to release-bot + spec corrected estate-wide
  (anvil README trap list, A12, AGENTS #4, INFRA callout); filter syntax
  also moved from unverified regex-in-slashes to the DOCUMENTED glob
  v*.*.*. Branches (a2c4fd7/0f95cb4/2dbef02) merged ONLY after the nine
  envs existed — merging first would have failed open. Damage: zero (the
  v0.1.0/v1.0.0 tags never reached vortex; cleanup: delete v0.1.0
  release+tag, cosmetic). Mains: lumen 6da64c7, earendil 0643280, mellon
  0455546; anvil d398094. First light now = one approval click (semver-patch
  on lumen run #5 → v1.0.1 → the full cascade + build + first bump PR) or
  the dispatch path (release.yml, tag: v1.0.0).
- 2026-11-13 (4) — **Phase 6e: informed deploys + the live-fire surprise.**
  Owner ruled the bump-PR step must be a MANUALLY TRIGGERED, EVIDENCED act:
  release.yml split `deploy` into deploy-plan (automatic rehearsal against
  real vortex main — pin pre-flight + exact diff + full validation, writes
  nothing; piped to the run summary for the human) and deploy (PARKS on a
  new protected `deploy` environment; approval re-validates and opens the
  PR — set-image-pr now REFUSES to push a render that fails validation,
  --skip-validate emergency-only). anvil @259da81 (deploy-plan action +
  validate-before-push + README Backlog recording the DEFERRED centralized-
  settings design: provision/settings.yaml + estate-provision PAT; org
  migration analyzed-and-declined for now; terraform rejected for plaintext
  state). auto-merge guard #5 fail-open closed (empty check list was
  passing when checks simply had not been created yet; now polls 3 min,
  requires the check to EXIST and be SUCCESS). Consumers: lumen cfaeb8e,
  earendil 5ec8bcc, mellon 9e1b2aa — 6/6 pins re-verified to the new anvil
  SHA by all three agents, gates green, merges parked three fresh waiting
  jobs per repo (CI-only changes — let them expire; approving would cut a
  pointless release).
  LIVE FIRE, discovered during the round (owner had been clicking in
  parallel — good pressure test): bump PR #4 (`lumen → v1.0.0`) MERGED via
  UI, Argo synced, pods verified running ghcr.io/kanatabi/lumen:v1.0.0,
  /healthz ok — the estate's first ghcr deploy, and the first proof the
  whole doctrine works. A `v0.2.0` bump branch appeared purely from a tag
  push — cascade confirmed alive post-PAT-fix. Debris to close (owner):
  open PRs for bump/lumen-v0.2.0 (same commit, LOWER version — merging
  would downgrade the pin) and the three pre-doctrine `sha-*` bump PRs
  (lumen-sha-202af5c, mellon-sha-cf9c545, mellon-sha-e230468 — Phase-6a
  ship-era leftovers; sha-tags violate release-only, close unmerged).
  earendil holds v0.1.0+v1.0.0 releases with NO bump branches — their
  release.yml runs failed or skipped (private, unseen); releases-without-
  deploys are legitimate doctrine states, revisit when earendil's first
  real merge happens; its Actions logs then tell the story.
  RUNBOOK A12 rewritten to plan/gate/open + "merge only when green" + the
  manifest-edits-don't-need-GitHub correction; INFRA callout extended.
- 2026-11-13 (5) — **Phase 6f: version truth + settle.** Owner caught the
  live bug by EXPECTING the right thing: approving semver-major on lumen
  computed v1.0.0 (already exists, died exit-128) because next-version.sh
  asked `git describe` for "newest" — describe sorts equidistant tags by
  TAGGER DATE, and lumen's history (v1.0.0 minted at 18:27, v0.2.0 minted
  later) poisoned it. Owner ruling: vendor the arithmetic instead of
  reinventing it — anvil now carries **semver-tool 3.4.0** (commit
  837ad91…, Apache-20 text beside it, sha256 provenance header, body
  byte-identical verified; the FIRST vendored dep, README codifies the
  rule: pinned, audited once, zero runtime fetches, upgrade=deliberate PR).
  Selection stays ours and VERSION-ordered (sort -V over --merged HEAD tags);
  collision guard refuses when the computed tag exists locally OR on origin
  (remote branch = the double-approve race, reproduced in the battery with a
  stale clone). Battery caught a self-inflicted again: I guessed the tool's
  subcommand `check` — it is `validate`; prerelease bumps follow the TOOL's
  mechanical rule (3.0.0-rc.1 + minor = 3.1.0), asserted so surprises are
  red tests, never red releases (estate tags remain strict vX.Y.Z).
  SETTLE (owner pain: approving one job left the run Waiting 24h and stalled
  the ci queue): after a successful release the job declines the run's
  remaining release-* reviews via the pending_deployments API — auth rides
  RELEASE_BOT_PAT acting as owner-reviewer (owner granted Actions:RW, fence
  3 verified: never own env, never deploy/other names, run-scoped only,
  warn-only failure policy, empty = nothing to decline). Battery 17/17.
  anvil @696fc49; pins swept programmatically (18/18 byte-verified, diffs =
  6 pin lines only): lumen 9f98300, earendil 36bd320, mellon cd010de.
  v2.0.0-on-lumen is now one approval away on the pin-bump run.
- 2026-11-13 (6) — **Phase 6g: incident round + the estate's first real
  release.** A host reboot (uninvited) re-sealed Bao — all three ES red
  (`could not get secret data from provider`), apps dark on config-drift —
  healed by the A7 ritual in minutes (`bao operator unseal <key>` as an
  ARGUMENT in non-tty exec; stdin piping fails; ESO bounce skipped its
  backoff). The same window caught the meili engine bump mid-flight: v1.56.1
  REFUSES the 1.10.0 volume (refuses — does not migrate), taking lumen
  (bootstrap-fails on the engine, exit 1) and the blog feed down with it;
  and minikube local-path keyed the recreated PVC back to the SAME host dir
  (async reclaim loses every race), so "delete the PVC" remounts the old DB.
  Honest wipe (node-side rm), engine boots empty, cmd/seed RECONCILE mode
  (rows untouched, index_post enqueued per PUBLISHED post) → 1 doc = the
  1 published post; feed green through ingress. Two receipts earned: the
  engine-bump recipe (A11) and the reindex-verb gap (backfill = seed today;
  proper fix = admin reindex-all + portal button, logged).
  MEANTIME the release chain walked itself: owner approved the lumen run →
  **v2.0.0** (version-ordered compute worked in anger — the describe fix,
  live), cascade fired, deploy-plan evidence, deploy gate, bump PR #5,
  merged — pods verified on ghcr v2.0.0. The informed chain is proven end
  to end. settle POST declined silently in production (warn-only held;
  siblings declined by hand) — diagnostics shelved by owner, evidence
  frozen (session notes DEFERRED-settle-diagnostics.md).
  Pre-enable audit of auto-merge (owner asked to flip the switch): TWO real
  blockers found cold before the toggle — the B-fix poll broke on
  IN_PROGRESS (would bail every PR forever), and vortex's merge permission
  was contents:READ (403 on every eligible merge). Fixed: anvil 9128181
  (terminal-state poll, SUCCESS-only), vortex b1f6789 (contents:write,
  scoped and documented). Switch is now owner's 15-second act; first
  auto-merged PR gets watched live.
- 2026-11-13 (7) — **Phase 6h: the auto-merge name-contract bug, found by
  its first real patient.** Owner enabled DEPLOY_AUTOMERGE and released
  mellon v1.0.0 — PR #7 (bump/mellon-v1.0.0) correctly stayed open: the
  guard's log said `validate-manifests not green (<never created>)`, and
  archaeology of the two workflows found the true bug: check-run NAMES come
  from the JOB, and vortex's job id was `validate` — the guard had been
  polling a name that never existed. The v1 fail-open (empty=proceed) had
  been MASKING this on every PR; my fail-open fix converted silent-pass into
  loud-ineligibility — a bug found by fixing its hiding place, again.
  Fixes cold: anvil 7976886 (guard accepts both `validate` and
  `validate-manifests`, 15-min terminal poll, dumps observed check names on
  bail — this class is now self-diagnosing); vortex dede983 (job gets an
  explicit `name: validate-manifests` + a do-not-rename warning comment; pin
  swept). Mock battery replayed PR #7's exact shape: all six guards GREEN,
  dry-run merge decision, exit 0. Re-trigger path for #7: fix the mellon
  package visibility FIRST (see below), then remove+re-add the deploy-bump
  label — the `labeled` event runs the guard fresh (workflow reads anvil
  main-tip by design, no re-pin). NEW OWNER DEBT surfaced by this same
  release: ghcr.io/kanatabi/mellon is PRIVATE (private repo inheritance —
  the standing skip from the checklist); merging #7 before flipping it
  strands mellon pods in ImagePull. Sequence: package public -> label
  cycle -> auto-merge watched live.
- 2026-11-13 (8) — **Phase 6i: the bolted-shut kill switch.** PR #8
  (bump/earendil-v1.1.0) passed every fence and died on DEPLOY_AUTOMERGE —
  not because it was off, but because the guard PROBED IT THROUGH AN API THE
  WORKFLOW TOKEN CANNOT USE: 403 "Resource not accessible by integration"
  is GitHub's design, not a misconfiguration; repo variables are reachable
  in workflows ONLY via the vars context. The switch the owner had just
  created was unreachable by its own reader — a bolted-shut box, discover-
  able only when the first eligible PR hit it (fail-safe survived: bailed,
  PR stayed with humans — the direction was right, the mechanism was dead).
  Fix: vortex d77d4b2 passes vars.DEPLOY_AUTOMERGE into the guard step's
  env (comment explains why the API is not the door); anvil 0b90ba4 reads
  env first, keeps the API only as a manual-run fallback, and SANITIZES it
  to literal on/off — the 403 error body once printed as the "value"; no
  error object can masquerade as a verdict again. Mock battery covers all
  three paths, including the exact production error JSON → <absent> →
  silent bail. PR #8 gate: earendil package visibility FIRST (its v1.1.0
  build made the package, private-by-inheritance — the same trap #7 nearly
  was, and the mellon #7 merge proved the flip works), then remove+re-add
  the deploy-bump label: fresh run, new env door, first AUTO-MERGE in
  anger.
- 2026-11-13 (9) — **GATE #9 CLOSED + the production runbook set shipped.**
  Owner ruled media provider = Cloudflare R2 ($0 egress, one vendor for
  DNS/guard/Access/media/backups; GATE #9's "provider choice" deferred
  since M5). Executed as the CR pre-announced: vortex 94db3ca extends the
  production lumen ES with the exact LUMEN_MEDIA_* family bound in
  internal/config (CREATE_BUCKET deliberately absent — prod never
  auto-creates cloud resources), lumen 8866e53 finalizes the sample-doc
  family; validate-all 25 dirs GREEN. Owner rulings recorded in the same
  breath (INFRA amendments adjacent to their superseded text): third
  sanctioned human surface `anor.gofar.id` (alt `beacon`) — Grafana behind
  CF proxy+challenge+Access, the no-public-API invariant untouched; admin
  mesh = Tailscale (NetBird plan superseded); backups = restic→R2 own
  bucket; Contabo-first provider direction, commands provider-neutral;
  wizard fix deployed & live (v1.0.1 — ghost username field, form-shape
  test + T-wiz10 harness tripwire shipped first).
  Deliverable: **`runbook/`** — 14 Obsidian-ready chapters (00–13),
  VPS-first, junior-tone with why-boxes, DNS records/challenges/certs +
  maintenance story, vault bootstrap incl. the incident-proven non-tty
  unseal line, releases chapter honestly flagging settle's production
  decline (habit: decline two), media with the presigned option written
  as an explicit PR-shaped upgrade-not-yet-needed, backup/DR with the
  monthly restore drill, access roads (SSH-tunnel-first + Tailscale),
  operations calendar with the five incident cards (each one we already
  paid for), references. Old RUNBOOK carries the archive banner; AGENTS
  pointer moved; .gitignore added for .obsidian/.
  Status honesty: every VPS-specific step is drafted-from-rehearsal, and
  the frontmatter says so — Part B's first walk converts claims to proof;
  the calendar's first entry post-go-live is "update status markers after
  each chapter walks green."
- — (append deltas here: contract changes, deviations, new rulings)
