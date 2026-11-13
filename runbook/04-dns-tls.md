---
tags: [runbook, network, tls]
updated: 2026-11-13
---

# 04 · DNS, TLS & Cloudflare — the front of the house

Three layers people constantly mix up. Keep them separate:

| Layer | What the visitor sees | Question it answers |
|---|---|---|
| **Proxy (orange cloud)** | nothing | "is my server hidden from floods and scanners?" |
| **Managed challenge** | *"checking your browser…"* | "are you a real browser, not a bot?" |
| **Access** | your email + one-time code | "you're human… but are you *allowed in here*?" |

---

## Act 1 — DNS (move the zone to Cloudflare)

### 1.1 Hand the zone to Cloudflare (once)

1. Cloudflare dashboard → **Add a site** → `gofar.id` → **Free plan**.
2. Cloudflare shows two nameservers (e.g. `ana.ns.cloudflare.com`).
3. At your **registrar**, replace the current nameservers with those two.
4. Wait (minutes to hours). ✅ check:
   `dig +short NS gofar.id` → answers show Cloudflare servers.

> **Why:** the proxy, challenges, Access, and R2 custom-domains all hang off
   Cloudflare's DNS. Records on another DNS provider get **none** of it.

### 1.2 The record table (Dashboard → DNS → Records)

| Type | Name | Target | Proxy | Why |
|---|---|---|---|---|
| A | `@` | server IPv4 | 🟠 Proxied | the blog; CF hides the IP and absorbs floods |
| CNAME | `www` | `gofar.id` | 🟠 Proxied | second spelling of the same door |
| A | `console` | server IPv4 | 🟠 Proxied | the portal — the door to your vault wants the guard most |
| A | `anor` | server IPv4 | 🟠 Proxied | Grafana; Access (Act 4) holds the guest list |
| CNAME | `img` | *created with the R2 custom domain in [06](06-media-r2.md)* | 🟠 | photos served by the CDN; bucket itself stays private |
| — | *(nothing for kubectl/Argo/SSH/API)* | — | — | admin roads never get public records (ch. 02 firewall + ch. 11 tunnels) |

**The proxied law:** every record that *serves humans* is 🟠 Proxied. Grey
cloud ("DNS only") means: no DDoS, no caching, and — worse — **your real
server IP becomes public**, which quietly breaks ch.02's "Cloudflare-only"
firewall for everyone on that hostname. If a site suddenly 502s/connections
refused and you "just changed a setting," that's almost always it. ✅ undo:
back to 🟠, wait a minute, `dig +short console.gofar.id` must show CF IPs,
**never** your server's.

### 1.3 DNSSEC (10 minutes, prevents an entire class of lies)

1. Cloudflare → DNS → DNSSEC → **Enable** → it gives a DS record.
2. Paste that DS record at the registrar's DNSSEC form. ✅ check:
   `dig +short DNSKEY gofar.id` non-empty and registrar shows "delegated".

> **Why:** DNSSEC stops a rogue network from inventing fake answers about
> `gofar.id` between the world and Cloudflare. Cheap once, boring forever.

---

## Act 2 — "verify you are human" (the managed challenges)

Settings live in Cloudflare → **Security**. Three knobs, use them honestly:

| Knob | What it does | Our stance |
|---|---|---|
| **WAF custom rules** (5 per zone on Free) | challenge *exactly* what you name | the workhorse — plan them like budget: |
| **Security level** (slider) | broadly suspicious-traffic checks | leave on the default; it's heuristic |
| **"I'm Under Attack" mode** | challenges EVERY visitor, big hammer | 🔴 **panic button only.** Toggle during a flood; turn off after. It also blocks RSS readers, uptime monitors and any `curl` client — living with it ON as "extra safety" makes your blog quietly unreachable to non-browsers |

Spend the rule budget (one-time in dashboard, all **Action = Managed
challenge**):

1. `console.gofar.id` paths `/login`, `/setup`, `/admin*` → challenge
   *(login-form brute force never reaches the portal)*
2. `console.gofar.id` all paths where method ≠ GET → challenge
3. `anor.gofar.id` **entire hostname** → challenge *(in front of Access:
   bots don't even get to the email step)*
4. *(spare)* uptime monitor bypass if/when you add one
5. *(spare)*

> **Why the blog gets none:** a first-visit reader challenged on every page
> is a lost reader; the blog's real protection is Act 1 (proxied) + ch. 02
> (origin answers only Cloudflare). Managed challenges stay *invisible* for
> real browsers when they do fire — the animation is what suspicious clients
> get.

---

## Act 3 — TLS certificates (set up once, maintain themselves)

### 3.1 cert-manager (pinned)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl -n cert-manager wait --for=condition=Available deploy/cert-manager --timeout=180s
```

### 3.2 A *scoped* Cloudflare API token (not the global one!)

Cloudflare → My Profile → API Tokens → Create:
- Permissions: **Zone · DNS · Edit**, scoped to zone `gofar.id` **only**
- TTL: set one (a year), calendar it (ch. 12 rotation line)

> **Why scoped:** this token can change your DNS records — nothing else. The
> global "Global API Key" can reset your password. One leaked token should
> cost you a domain afternoon, not the account.

Store it in Bao, not Git (ch.05 seeds `kv/cert-manager/production` with
`CF_API_TOKEN`); render it via an ExternalSecret (or a small manual Secret
at bootstrap — same rule: values live in the vault).

### 3.3 The issuer + certificates

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: letsencrypt-prod }
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <you-real-email>              # Let's Encrypt notices land here
    privateKeySecretRef: { name: cert-manager-account-key }
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef: { name: cf-token, key: api-token }
```

then one `Certificate` per door (`gofar.id`+`www`, `console.gofar.id`,
`anor.gofar.id`), each with `secretName` and `dnsNames` — manifests live in
`vortex` so they ride GitOps like everything else. ✅ check:
`kubectl get certificates -A` → Ready=True.

> **Why DNS-01 and not HTTP-01:** behind a proxied zone + Cloudflare-only
> firewall, HTTP-01 validation fights your own defenses; DNS-01 asks
> Cloudflare's directory instead — no ports involved, works even while
> everything else is closed, and renews invisibly forever.

### 3.4 Maintenance (the actual "keeping TLS" part)

- **Renewal is automatic:** cert-manager re-issues at 2/3 of lifetime
  (~60 days before a 90-day cert dies). You should never *do* this — only
  notice if it stopped happening.
- **The alert that replaces vigilance:** Grafana alert "certificate expires
  in < 21 days" (exporter metric `certmanager_certificate_expiration_timestamp_seconds`
  — ch. 09 wires it). One line beats a calendar.
- **The drill (quarterly, ch. 12):** delete one test `Certificate` →
  re-apply → Ready again in minutes. This proves issuer+token+permissions
  without waiting for a real expiry to discover them broken.
- **What dying looks like:** browsers show a privacy error on one hostname;
  `kubectl get certificate` shows `False` with a `failed to...` reason —
  90% of causes are the scoped token expired or was edited. The fix is a
  new token in Bao + `kubectl -n cert-manager rollout restart`.

---

## Act 4 — Access: the dashboard's guest list (one login, not two)

Cloudflare dashboard → **Zero Trust → Access → Applications → Add → the
Grafana SaaS template** (it knows the OAuth plumbing) → domain
`anor.gofar.id` → policy **Allow · Login with email · dev@gofar.id**
(session 7 days). Then configure Grafana with the client-id/secret it
hands you (ch. 09) — Grafana stops showing its own login page: Access
answers "who," Grafana answers "what may you touch."

> **Why this beats two logins:** a password in front of an email-code is
> one more secret to lose and zero more real security; the unintegrated
> two-gate shape is the mistake the first draft of this doc would have
> shipped. The **break-glass** local Grafana admin stays (ch. 09/11) — but
> it lives on the tunnel path, for the day Cloudflare itself is down.
> To invite family/friends later: add their emails to this one policy —
> that's the whole of "user management" (ch. 09 lab section).

**If you choose `beacon.gofar.id` instead of `anor`:** exactly four places
hold the name — (1) the DNS record above, (2) the `Certificate` dnsNames in
`vortex`, (3) the Access application domain, (4) Grafana's `root_url`.
Rename all four in one sitting; the doc's examples use `anor`.

Next → [05 Secrets Vault](05-secrets-vault.md)
