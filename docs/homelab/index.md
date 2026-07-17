# Homelab

GitOps Kubernetes homelab: bare Talos nodes reconciled to a git-declared desired state by Flux CD. One cluster today — **tom** — named after the owner's cat.

## The tom cluster

- **Topology:** one control plane + one worker.
  - `controlplane1.tom` — `192.168.1.10`
  - `worker1.tom` — `192.168.1.11`
- **OS:** Talos Linux 1.10 (immutable, API-driven). Talos ships no CM5 image, so a [community build](https://github.com/talos-rpi5/talos-builder/releases) is used.
- **Hardware:** 2× Raspberry Pi CM5 on 2× [Compute Blades](https://computeblade.com/) with TPM (secure boot) and RTC.
- **Stack:** Talos + Flux CD + Kustomize + Helm.

## GitOps model

- Flux watches this repo and reconciles the cluster to match `homelab/`; nothing is applied by hand after bootstrap.
- Cluster entrypoint: `homelab/clusters/tom/` — the `--path` given to `flux bootstrap`.
- Reconciliation is ordered by Flux `Kustomization` `dependsOn`: `infra-platform-crds` → `infra-platform-controllers` → `infra-platform-configs` → `apps`. See [architecture](explanation/architecture.md) for why.
- Container image bumps arrive as CI-opened PRs, not hand edits — see the image-automation lifecycle in [architecture](explanation/architecture.md).

## Directory layout

| Path | Holds |
|------|-------|
| `clusters/tom/` | Flux entrypoint: the `Kustomization` chain (`platform.yaml`, `apps.yaml`), image automation, alerts, and the `flux-system/` bootstrap output. |
| `infrastructure/platform/crds/` | Cluster CRDs applied first: Gateway API + Traefik gateway RBAC. |
| `infrastructure/platform/controllers/` | Helm-installed operators: external-secrets, cert-manager, MetalLB, Traefik, Longhorn. |
| `infrastructure/platform/config/` | Cluster-scoped config the controllers consume: 1Password store, Cloudflare issuer, MetalLB pools, Traefik service, Longhorn storage + gateway. |
| `infrastructure/talos/tom/` | Talos machine config — only `*.patch.yaml` inputs are committed; secrets and generated node configs are gitignored. |
| `apps/tom/` | Workloads: `pihole`, `actualbudget`. |

## Documents

| Document | Type | Covers |
|----------|------|--------|
| [Architecture](explanation/architecture.md) | Explanation | The reconcile ordering, secret flow, ingress/cert model, image automation, and storage — and why each is shaped that way. |
| [Bootstrap the cluster](how-to/bootstrap-cluster.md) | How-to | Bring `tom` up from bare Talos nodes to a reconciling Flux install. |
| [Dictionary](reference/dictionary.md) | Reference | Terms, hostnames, IPs, and naming conventions used across the homelab. |

---

Up: [Documentation index](../index.md)
