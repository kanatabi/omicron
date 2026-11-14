---
tags: [archive, earendil, infrastructure]
updated: 2026-11-15
---

> **Archived 2026-11-15** — removed from the
> [earendil](https://github.com/kanatabi/earendil) repo during the docs-consolidation
> round (last tracked at [earendil `8a56b1c`](https://github.com/kanatabi/earendil/blob/8a56b1c/ARCHITECTURE.md)).
> This single-node K3s draft predates the production blueprint; the authoritative
> infrastructure document is [omicron `INFRA_ARCHITECTURE.md`](../../INFRA_ARCHITECTURE.md)
> — the same-day-retired `vortex/` copy of it was a stale fork. Content below is
> verbatim; its repo-relative links are historical and no longer resolve.

# K3s Single-Node Cluster Blueprint & Resource Allocation Plan

## 1. Final VPS Hardware Specification Blueprint

- **vCPU**: 2 Cores (Minimum) / 4 Cores (Recommended)
- **RAM**: 8 GB RAM (Absolute Non-Negotiable baseline)
- **Storage**: 50 GB - 60 GB NVMe SSD (Mandatory for high IOPS PVCs)
- **OS**: Ubuntu 24.04 LTS / Debian 12

## 2. Cluster Resource Allocation Plan

- **Elasticsearch Pod**: Request: 1536 MiB | Limit: 2548 MiB (JVM Heap restricted to 1GB)
- **Patroni PG Cluster**: Request: 1024 MiB | Limit: 2048 MiB (1 Primary + 1 Replica)
- **Backend Server**: Request: 256 MiB | Limit: 512 MiB
- **Ingress & System Routing**: Request: 128 MiB | Limit: 256 MiB
- **K3s Control Plane & Host OS**: ~1500 MiB system headroom reserved

## 3. Patroni PostgreSQL Manifest Template

```yaml
apiVersion: 'acid.zalan.do/v1'
kind: postgresql
metadata:
  name: blog-patroni-db
spec:
  teamId: 'blog'
  volume:
    size: 10Gi
    storageClass: 'local-path'
  numberOfInstances: 2
  patroni:
    initdb:
      encoding: 'UTF8'
      data-checksums: 'true'
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    synchronous_mode: false
  resources:
    requests:
      cpu: '250m'
      memory: '512Mi'
    limits:
      cpu: '1000m'
      memory: '1Gi'
  databases:
    blog_prod: db_user
```

## 4. Mandatory Host OS Setup Commands

```bash
# Expand virtual memory for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Add a 2GB Emergency Swap file
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Install K3s
curl -sfL https://get.k3s.io | sh -
```
