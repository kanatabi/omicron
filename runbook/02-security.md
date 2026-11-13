---
tags: [runbook, security]
updated: 2026-11-14
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

> **Posture for this chapter:** run §1 **as root** (your provider gave you
> that session). From §2 on you are **`ops`**, and everything that writes
> system files is prefixed `sudo` (it prompts for *your* password). Never
> log in as root again after §1.

## 1. Create your admin user (stop using root)

```bash
adduser ops && usermod -aG sudo ops   # adduser prompts you to set a password — that's the sudo password from now on
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
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo tee /etc/ssh/sshd_config.d/20-homelab.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
LoginGraceTime 20
EOF
sudo sshd -t && sudo systemctl reload ssh    # `sshd -t` BEFORE reload = syntax-check first
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
sudo apt install -y ufw
# update this list monthly — Cloudflare publishes it (card 9 in ch.12
# automates the refresh; the refresh script re-runs this same loop):
curl -sL https://api.cloudflare.com/client/v4/ips | python3 -c "import sys,json;[print(p['cidr']) for p in json.load(sys.stdin)['result'] if ':' not in p['cidr']]" | sudo tee /etc/cloudflare-v4.txt >/dev/null
for c in $(cat /etc/cloudflare-v4.txt); do sudo ufw allow from "$c" to any port 80,443 proto tcp; done
sudo ufw allow 22/tcp
sudo ufw deny 6443  # k8s API: tunnels/Tailscale only, never the internet
sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw enable && sudo ufw status numbered
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
sudo apt install -y unattended-upgrades fail2ban
sudo dpkg-reconfigure --priority=low unattended-upgrades   # say yes
sudo systemctl enable --now unattended-upgrades fail2ban
```

> **Why:** the boring 90% of breaches are unpatched known holes; `fail2ban`
> temporarily bans the persistent SSH guessers so logs stay readable.

## 5. Swap + kernel knobs (the box has one disk and one job)

```bash
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
sudo tee /etc/sysctl.d/90-omicron.conf >/dev/null <<'EOF'
vm.swappiness=1          # RAM first; swap is the safety net, not the habit
fs.inotify.max_user_instances=812   # k3s + collectors eat inotify
EOF
sudo sysctl --system
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
