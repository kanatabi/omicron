---
tags: [mellon, lessons]
updated: 2026-11-15
---

# mellon — lesson ledger

The standing doctrine lives in the repo's
[DESIGN.md §2](https://github.com/kanatabi/mellon/blob/main/DESIGN.md) and its
[AGENTS.md](https://github.com/kanatabi/mellon/blob/main/AGENTS.md). This
ledger records walked events. Newest first.

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
- **2026-11-13 — the wizard joined the threat surface.** The setup wizard's
  unauthenticated write path earned first-class TOFU analysis (V7) after this
  note's original scope was written; the detailing lives in this vault:
  [../archive/mellon-THREAT-NOTE.md](../../archive/mellon-THREAT-NOTE.md).
