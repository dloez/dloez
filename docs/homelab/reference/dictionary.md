# Homelab dictionary

Austere lookup for terms, hostnames, and conventions used across `homelab/`.

| Term | Definition |
|------|------------|
| **tom** | The single Kubernetes cluster in this repo (named after the owner's cat). One control plane + one worker. Flux entrypoint: `homelab/clusters/tom/`. |
| **Talos** | Talos Linux — the immutable, API-managed OS the nodes run (v1.10, community CM5 build). No SSH or shell; configured entirely via `talosctl` and machine-config YAML. |
| **Flux** | Flux CD — the GitOps controller set. Watches this repo and reconciles the cluster to match `homelab/`. |
| **Kustomization (Flux)** | A `kustomize.toolkit.fluxcd.io` resource telling Flux to apply a repo path, with `dependsOn`, `wait`, `interval`, and `prune`. The four in `clusters/tom` drive the reconcile chain. |
| **`kustomization.yaml`** | The upstream Kustomize file (`kustomize.config.k8s.io`) listing the `resources:` in a directory. Plain manifest bundling — not a Flux resource. |
| **HelmRelease** | A `helm.toolkit.fluxcd.io` resource; Flux's declarative `helm install/upgrade`. Every controller (external-secrets, cert-manager, MetalLB, Traefik, Longhorn) is one. |
| **ClusterSecretStore** | ESO resource defining where secrets come from — here the `Homelab - Tom` 1Password vault, authenticated by the `1password-service-token-tom` secret. |
| **ExternalSecret** | ESO resource that reads keys from a store and creates a native Kubernetes `Secret`. Keeps plaintext out of git. |
| **ClusterIssuer** | cert-manager resource that issues certificates cluster-wide. `cloudflare-issuer` uses Let's Encrypt ACME with a Cloudflare DNS-01 solver. |
| **MetalLB pool** | An `IPAddressPool` (+ `L2Advertisement`) of LAN IPs MetalLB assigns to `LoadBalancer` services — bare metal's stand-in for a cloud LB. Pool `basic` = `192.168.1.18`, `192.168.1.19`. |
| **Gateway / HTTPRoute** | Gateway API resources. A `Gateway` binds listeners (`web`/HTTP, `websecure`/HTTPS+TLS) to the `traefik` class; `HTTPRoute`s attach hostnames and routing/redirect rules to it. |
| **Longhorn** | Distributed block storage providing dynamic PVs. Default class `longhorn-single-replica` keeps one replica (single worker). |
| **ImagePolicy** | Flux rule selecting the wanted image tag from a scanned `ImageRepository` — pihole uses CalVer `YYYY.MM.RELEASE`, newest wins. |
| **ImageUpdateAutomation** | Flux resource that rewrites the `# {"$imagepolicy": ...}`-marked tag in the repo and pushes the change to an image-automation branch. |
| **`image-automation-<cluster>-<app>`** | Branch naming for Flux image bumps (e.g. `image-automation-tom-pihole`). CI parses it into a PR title and deletes the branch on merge. |
| **`controlplane1.tom` / `worker1.tom`** | The two node hostnames, set by the Talos patches. Static IPs `192.168.1.10` (control plane) and `192.168.1.11` (worker). |
| **`<app>.dloez.dev`** | Public hostname pattern for each web app (`pihole.dloez.dev`, `actualbudget.dloez.dev`, `longhorn.dloez.dev`), served over HTTPS via Traefik with a cert-manager certificate. |

---

Up: [Homelab index](../index.md)
