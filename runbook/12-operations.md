---
tags: [runbook, ops]
updated: 2026-11-13
---

# 12 · Operations Calendar & Incident Cards

> **Why a calendar:** every mechanism in this runbook fails *quietly and
> late* — expired tokens, stale backups, lapsed PATs, sealed vaults after
> a reboot. The calendar is the noise-making layer; the incident cards are
> what the noise means.

## Weekly (5 min — mostly a glance at anor)

- [ ] Alerts inbox: any fire? (certs/backup/disk/restarts — ch.09 §6)
- [ ] Argo: all Synced/Healthy? Anything "OutOfSync" you didn't expect?
- [ ] GitHub: any open bump PR waiting on you? (a forgotten Waiting job
      also silently queues the ci lane behind it — decline or expire)

## Monthly (30–45 min — Saturday, calm)

- [ ] **Restore drill** (ch.10 §4) — the one line that keeps backups honest
- [ ] **Media smoke** (ch.06 §3): upload → `img.gofar.id` loads → delete
- [ ] **Cloudflare-only firewall** (ch.02 §3): re-pull CF IP ranges into
      `/etc/cloudflower-v4.txt` (they change occasionally), `ufw reload`
- [ ] Cert-manager: nothing due (auto-renews) — just confirm alerts green
- [ ] "Under Attack mode" spot check: still OFF? (ch.04 Act 2 — the panic
      switch is never a lifestyle)
- [ ] OS: `apt list --upgradable` glance (unattended handles security;
      you handle the *reboot* — in a window, then ch.05's unseal ritual —
      Bao returns SEALED after every restart, that's by design)

## Quarterly (60–90 min)

- [ ] **PAT rotation** — `RELEASE_BOT_PAT` + `VORTEX_BOT_PAT` expire at 90
      days (calendar at day ~75!). Lapse symptoms: release dies at tag push
      (403) / bump-PR step 401 — nothing else breaks. Revoking RELEASE_BOT_PAT
      is the emergency brake on ALL releasing.
- [ ] Access/Teams review (ch.09 §5): people you invited once for one
      weekend are still in it
- [ ] Cert reissue **drill** on one test Certificate (ch.04 Act 3.4)
- [ ] Bao: keys still readable offline (paper doesn't fade, but drawers
      get moved); snapshot restore half of the ch.10 drill
- [ ] Version hygiene (deliberate, never auto): k3s channel, helm charts,
      Argo, ESO, cert-manager — bump one at a time in PRs a human merges

## Yearly / evergreen

- [ ] DR: walk the full rebuild on the rehearsal VM once a year (ch.10 §5)
- [ ] Domain + registrar renewal dates; Cloudflare billing contact correct
- [ ] `gofar.id` still says `alternateName Gofar`… the *legal* identity
      anchors (root AGENTS brand notes) survive you

## Incident cards (the five that already happened once)

**1. Everything red, "could not get secret data from provider"**
→ Bao sealed (host reboot? someone's fault?). Do ch.05 §6's ritual
(2 offline keys as ARGUMENTS, non-tty), bounce ESO. Symptom-check:
`kubectl -n secrets exec openbao-0 -- bao status` — `sealed: true`.
Trust `describe`'s Last Transition Time, not `get`'s "last sync", to date it.

**2. New pods ImagePullBackOff: `unauthorized`**
→ GHCR package inherited private repo visibility (ch.08 §5.4). Flip package
public (or wire pull secrets — B-pattern). Old pods keep serving: the blog
is fine until you roll.

**3. Release approved but nothing deployed, jobs all "green"**
→ The cascade's classic corpse: tag pushed with a token that can't cascade
(missing Workflow permission — ch.08 §1). Check events API: a tag with
ReleaseEvent but NO PushEvent. Fix PAT permission, dispatch release.yml
with the tag typed in (the redeploy door exists precisely for this).

**4. Bump PR never auto-merges though validate is green**
→ Guard's fault-silence, always logged: check the auto-merge run for
`NOT eligible:` — top causes: DEPLOY_AUTOMERGE missing/blanket (env door,
ch.08 §4), check still `IN_PROGRESS` when polled (guard waits 15 min now),
or the changed file isn't `applications/*/kustomization.yaml` (by design:
human PRs are never auto-merged). Merge by hand; the PR tells you which.

**5. Search empty after engine bump / site 500s "503 from /api"**
→ Meilisearch refused the old data volume (ch.03 §3 + A11): wipe the
**host directory** (PVC delete alone remounts the same old dir — Retain
is deliberate), let the engine boot empty, run `cmd/seed` reconcile
(port-forwards to DB+engine; it indexes only PUBLISHED posts and leaves
rows alone). Verify with the engine's `/indexes/posts/stats`
`numberOfDocuments` == published count.

## The one meta-line

Every incident above is *already* in this calendar as a prevention line —
when a new surprise happens, it earns a card here the same week, or the
rehearsal paid for nothing.

Next → [13 References](13-references.md)
