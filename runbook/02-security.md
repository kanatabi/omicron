---
tags: [runbook, security]
updated: 2026-11-13
status: commands rehearsed on VM; VPS walk = proof
---

# 02 · VPS Hardening — locks before furniture

> **🟦 VPS-ONLY.** The local rehearsal track (k3d — [00a
> Run Order](00a-run-order.md), Track A) **deliberately skips this
> chapter**: the laptop cluster has no SSH door facing the internet and
> nobody logs into your k3d containers; these are the VPS's door locks.
> Its VPS-parity note is in 00a: everything else on both tracks runs the
> same shape, so ch.02 is exactly one of the two host-level deltas that
> Track B walks for the first time.

> **Why this chapter is FIRST:** a fresh Linux box with root+password SSH
> open to the internet starts being scanned (and sometimes breached) within
> **hours**. Every later chapter assumes these locks are already on.

All commands run **on the server** as root (or prefix `sudo`), unless said.

## 1. Create your admin user (stop using root)

```bash
adduser ops && usermod -aG sudo ops
# copy YOUR laptop public key in (from laptop: cat ~/.ssh/id_ed25519.pub)
mkdir -p /home/ops/.ssh && echo "ssh-ed25519 AAAA... you@laptop" > /home/ops/.ssh/authorized_keys
chown -R ops:ops /home/ops/.ssh && chmod 700 /home/ops/.ssh && chmod 600 /home/ops/.ssh/authorized_keys
```

> **Why keys, not passwords:** a password can be guessed by a robot running
> a million tries a night; a key cannot. Also: with a named user, every
> action is logged against *someone*.

✅ check from your laptop: `ssh ops@<ip>` works **without** a password.

## 2. SSH config — close the guesses

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat > /etc/ssh/sshd_config.d/20-homelab.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
LoginGraceTime 20
EOF
sshd -t && systemctl reload ssh    # `sshd -t` BEFORE reload = syntax-check first
```

> **Why each line:** root-login/passwords are the two doors brute-forcers
> know; `MaxAuthTries/LimitGraceTime` tire out scanners.
> **Never lock yourself out:** keep this first session open while you test
> a *second* `ssh ops@` from another terminal. Recovery = provider's web
> console.

## 3. Firewall — only Cloudflare and SSH

We will NOT leave the server answering anyone directly: HTTPs doors accept
*only Cloudflare's addresses* (Cloudflare proxy must be ON — ch.04), SSH
stays open to the world (that's normal; it's key-only now), Kubernetes
ports are never public.

```bash
apt install -y ufw
# update this list monthly — Cloudflare publishes it:
curl -sL https://api.cloudflare.com/client/v4/ips | python3 -c "import sys,json;[print(p['cidr']) for p in json.load(sys.stdin)['result'] if ':' not in p['cidr']]" > /etc/cloudflare-v4.txt
for c in $(cat /etc/cloudflare-v4.txt); do ufw allow from "$c" to any port 80,443 proto tcp; done
ufw allow 22/tcp
ufw deny 6443  # k8s API: tunnels/Tailscale only, never the internet
ufw default deny incoming && ufw default allow outgoing
ufw enable && ufw status numbered
```

> **Why deny 6443:** the Kubernetes control plane on a public IP is the most
> scanned port in k3s tutorials' blind spot. It stays reachable *through*
> the admin roads (ch.11); the internet never needs it.
> **Why Cloudflare-only 80/443:** if origin answered everyone, a scan could
> find the real IP and bypass *all* Cloudflare protection. This rule keeps
> the promise honest. (Gotcha noted for ch.04: if you ever grey-cloud a
> record, that visitor traffic arrives from non-CF IPs and gets blocked —
> that's the system *working*, not a firewall bug.)

## 4. Auto-security-updates + intrusion tiredness

```bash
apt install -y unattended-upgrades fail2ban
dpkg-reconfigure --priority=low unattended-upgrades   # say yes
systemctl enable --now unattended-upgrades fail2ban
```

> **Why:** the boring 90% of breaches are unpatched known holes; `fail2ban`
> temporarily bans the persistent SSH guessers so logs stay readable.

## 5. Swap + kernel knobs (the box has one disk and one job)

```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
cat > /etc/sysctl.d/90-omicron.conf <<'EOF'
vm.swappiness=1          # RAM first; swap is the safety net, not the habit
fs.inotify.max_user_instances=812   # k3s + collectors eat inotify
EOF
sysctl --system
```

> **Why swap:** without it, one memory spike OOM-kills the vault or the DB
> (both hate it). **Why inotify:** k3s + Alloy hit the default (128) silently.

## 6. Clock (certificates and backups both depend on it)

```bash
timedatectl set-ntp true && timedatectl status | grep "synchronized: yes"
```

✅ End state: passwordless key-SSH as `ops` · no root/password logins ·
80/443 from Cloudflare only · 6443 dark · updates automatic · swap on ·
clock synced. Next → [03 K3s](03-k3s.md)
