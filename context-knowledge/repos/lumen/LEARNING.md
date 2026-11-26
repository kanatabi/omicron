---
tags: [lumen, lessons]
updated: 2026-11-26
---

# lumen — lesson ledger

The standing rulings live in the repo's
[AGENTS.md](https://github.com/kanatabi/lumen/blob/main/AGENTS.md); the wire
contract in its DESIGN.md. This ledger records walked events that minted
them. Newest first.

- **2026-11-27 — the passkey audit: a TTL shorter than the prompt, an
  unread clone signal, and a 500 where a 409 belonged.** The full read of
  the C1 round found four classes the happy-path battery didn't. (1) The
  begin-state TTL was 3 minutes while the library advertises a 5-minute
  prompt (`webauthn/const.go`) — slow ceremonies died with "challenge
  invalid or expired"; TTL is now 5m, coupling documented. (2) The
  library's `Authenticator.CloneWarning` (set when the counter does NOT
  advance; 0→0 never warns) was ignored, so a cloned authenticator could
  mint — now refused with an audit line. (3) A duplicate registration hit
  the credential-id PK and became a 500; 23505 now maps to
  `ErrCredentialExists` → 409. (4) A `len(id)==16 → []byte(id)` branch in
  `uuidBytes` would have returned a 16-CHARACTER string as an ASCII user
  handle — dead, removed. Also: the register response's `createdAt` was
  never read back (empty), the label had no server cap (64 runes now), and
  `state.go`'s comment claimed "replay-proof" when the token is only
  TAMPER-proof (replay inside the TTL is bounded by the counter — the
  recorded trade-off). The integration battery now proves the denials:
  replayed assertion 401, duplicate 409, label 400, scoped delete 204, and
  an unconfigured plane's 404 "no such method". Lesson: a happy path plus
  a tampered-state check is not an audit — read the library's own signals
  and the wire's status table.

- **2026-11-26 — "no such method" is the unconfigured-feature voice, and an
  ES data list can omit a key the code binds.** console.gofar.id's passkey
  button answered 400 `no such method`; the string was lumen's own
  (`internal/api/admin/webauthn.go` — an unconfigured feature is ABSENT),
  relayed verbatim by mellon's action catch, so it read like a Kit error.
  Two halves were missing: no RELEASED image called `EnableWebAuthn`
  (12b95c5 wired it AFTER v5.2.0 shipped), and foundation/lumen's
  ExternalSecret never rendered the pair — even though `lumen config keys
  --role admin` had listed it since the role split, i.e. the admin render
  contract had silently lost a bound key. Standing rule: the ES data list
  ≡ `config keys --role <plane>`; a mismatch there IS the bug class, and
  the boot log (`webauthn: not configured — the passkey method is off`)
  names it out loud.
  The rename trap underneath: 12b95c5 renamed the BINDING to
  `LUMEN_WEBAUTHN_ORIGINS` while the vault key kept its singular. One key
  SET per app is load-bearing here — the relay's mirror reconciles a
  path's shape toward the saved sibling's, so a shared-only new key would be
  STRIPPED (with a version bump = a surprise epoch desync) by the next cms
  save. The ES maps property -> env name; that seam is the migration's home.

- **2026-11-24 — the cms plane was the FIRST scope-separated client; the
  spine generalized an existing seam.** The RBAC design needed "an app BE
  checks the token and enforces its scopes" — and `internal/authz` had
  already built exactly that for the cms plane (introspect at the admin
  verify door, cache positives ≤30s, fail closed). The spine extended the
  DOOR (it answers scopes) instead of inventing a new mechanism; JWKS
  stays the recorded later optimization. The store's assignment lever is
  token_version itself: **every scope mutation bumps it**, so a demotion
  is immediate — the 12h TTL never shields a demotion.
- **2026-11-24 — a permission catalog is DB data, not code.** The scope
  catalog is portal-managed (`users:manage`-gated; delete REFUSES while
  held, counts riding the 409) so onboarding a scope is a portal action,
  never manual SQL. lumen's own route→scope table stays in code (routes
  are lumen's); app namespaces belong to the apps that enforce them —
  lumen only stores who holds what.
- **2026-11-23 — a byte cap does not bound memory; a pixel cap does.** The
  20 MiB upload limit felt like the memory guard, but a 100 MB JPEG can
  declare 100+ MP, and the decode heap (~1.5 B/px YCbCr + raw bytes +
  re-encode) OOMs independently of body size. `Process` now runs
  `image.DecodeConfig` BEFORE `image.Decode` and rejects >60 MP (415 with
  the dims) — `8aff8db`. The http-server limit went to 768Mi (vortex
  `0a76ae7`) as the headroom that makes the bound honest; the error copy
  derives from the constant (`media.MaxLabel()`), so cap and copy can't
  drift apart.

- **2026-11-22 — the photo GC: the delete's object epilogue, and the ledger
  path was the handle all along.** §8's keep-until-GC line is amended (owner
  call): the delete removes the row AND the object. The design that made it
  a one-day change: **the media_assets ledger's `path` IS the GC handle**
  (§6 said so from M5) — resolved at delete time by the longest SUFFIX-join
  of the row's src (the URL composes base + "/" + prefixed-path, so the key
  needs no schema column of its own); a missing ledger row resolves to ""
  and the GC SKIPS honestly (never guesses). The two traps the design
  already answered: **content-addressed dedupe** — a sibling photo row
  citing the same object must KEEP it alive (sibling count rides the same
  resolution), and **row-first ordering** — the request's contract is the
  library row; the object delete is a best-effort epilogue whose failure
  logs LOUD (`media.delete.failed`) but never reddens the request. The
  decision table is pure (`gcDecide`) — the offline gate owns the logic,
  the integration walk (real s3mem object: shared survives, last-owner
  dies) owns the wiring. Same round, found NOT fixed: `TestBaoRelay` /
  `TestEstateSummary` / `TestRoleSplit` fail on a CLEAN tree with the full
  make env — the dev Bao container lacks the `lumen/{env}` kv seeds (the
  runbook's open seed item) and `dev-plane.env` (the appRole) is absent;
  environment state, not code.
- **2026-11-22 — the EXIF capture: lumen never parses metadata, and the
  allowlist keeps it that way.** Round B (owner sketch): the capture moved
  CLIENT-side (mellon's exifr, the curated keys only) and lumen stores an
  OPTIONAL multipart `exif` field through `SanitizePhotoExif` — pure,
  offline-gated. The promise held STRUCTURALLY, not by vigilance: **GPS is
  not a key in the allowlist** (a denylist grows typos; an allowlist grows
  nothing), wrong-typed values drop, malformed JSON is a 400 (a client
  bug, never a silent swallow), an empty set stores NULL — the panel's
  honest empty state. `PhotoDoc` stays UNTOUCHED (EXIF is panel display
  data, never an engine field); `photos.exif` jsonb rides 0009 (cms plane).
  The integration walk PLANTS GPSLatitude/GPSLongitude on a real s3mem
  upload and proves the stored row carries the curated set and no GPS key
  — the promise is now TESTED at the wire, not just declared.

- **2026-11-15 — the observability amendment: every request and job
  speaks.** Three silent paths were found in ONE debugging night: the
  media relay's 500 (logged nothing), the catch-all's `_ = r` (the
  discarded error), the verify's reasonless 401. The amendment: the
  correlation seam (request-id in/out + down the ctx + into the job
  metadata) + the speaking-errors rule (the catch-all, the media S3
  errors, the deny's reason). The lesson's edge: **the machinery was
  half-built all along** (chi's RequestID middleware mounted but
  unread) — audit what EXISTS before building new.
- **2026-11-15 — the media relay's first real walk; the region seed was
  wrong.** The upload 500'd with lumen's generic `{"error":"internal
  error"}` AND zero log lines (the media handler swallows the S3 error —
  a logging gap to fix in code: `media.put.failed` must log the op +
  bucket + the S3 error code, never payloads). The diagnose-a-silent-S3
  probe that cracked it: a one-off `amazon/aws-cli` pod carrying the SAME
  rendered credentials named the error out loud — `InvalidRegionName:
  'r2' is not valid. Must be one of: wnam, enam, weur, eeur, apac, oc,
  auto`. The seeds (runbook ch.05) now say `LUMEN_MEDIA_REGION=auto`.
  Also walked: FORCE_PATH=false (virtual-host) reaches R2's API fine —
  ch.07's claim proven; the FORCE_PATH flip was a red herring.
- **2026-11-15 — a key family with TWO spellings is a drift vector.** The
  timeout keys were minted flat (`timeout_meilisearch`) by the obs
  registry, but config's resolution loop still filtered on the dotted
  prefix (`"timeout."`) — every binding silently fell through and every
  env override read NOTHING while the in-code defaults kept the tests
  half-green (the standalone viper probe passed, the flow didn't). The
  class: derived keys must have ONE spelling rule shared by the minter
  and every filter — the parity guard test now proves the rows against
  the registry, and the union arithmetic derives the shared count instead
  of hardcoding it. (The viper probe's lesson underneath: dotted keys
  can't hold a dep-default scalar AND an op-override map at one YAML
  path — flat underscore keys are the shape.)
- **2026-11-13 — the battery owns an `itest/` prefix, never the human path.**
  An old worker + shared queue reseeded `kv/lumen/dev` mid-walk (a human was
  browsing the same path) — the collision class. Minted the integration-path
  isolation rule (C5). Standing rule: AGENTS test-battery section.
- **2026-11-13 — a pin is a LOCK, not intent.** The redefinition walk
  (`230783b` + lumen `28e7811`) found "intent" unenforceable at the only
  write path that matters; pins now refuse writes (403) until unpinned, and
  mellon renders the wire copy verbatim. Standing rule: DESIGN §9 + the
  vault's [secrets-control-plane decision log](../../decisions/secrets-control-plane.md).
- **2026-11-13 (C1) — the estate matrix feed exists because drift was
  invisible.** `GET /admin/bao/summary` (lumen `9544ce4`) answers app×env
  head/pin/key-counts so mellon's matrix can surface empty-key and shape
  drift without exposing values.
- **2026-11-13 (A5) — two wire truths found only against REAL OpenBao.** The
  control-plane integration round (`98563b9`) caught live semantics the unit
  layer could not (policy `patch` capability; create-only write behavior on
  the wire). Standing rule: test battery tiering (`make test` vs
  `test-integration`).
- **2026-11-09 — layered HTTP is enforced by review, not by compiler.** The
  handler→service→store split (owner ruling) exists because a handler
  importing store was the actual drift vector; keep handlers
  decode/call/map/encode ONLY.
- Redaction is TESTED, not promised: `bao_integration_test.go` captures the
  slog stream and demands the marked value's absence — the guard exists
  because "we never log values" had to be proven at least once.
