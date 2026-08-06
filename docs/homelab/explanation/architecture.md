# Homelab architecture

Why the `tom` cluster is shaped the way it is. For what each file declares, read the manifests; this page covers the decisions between them.

## The reconcile chain

Flux applies four `Kustomization`s in a fixed order via `dependsOn`, defined in `clusters/tom/platform.yaml` (platform) and `clusters/tom/apps.yaml` (apps):

`infra-platform-crds` → `infra-platform-controllers` → `infra-platform-configs` → `apps`

Each stage produces the API types or running controllers the next one needs, so the order is a hard dependency, not a preference:

| Stage | Path | Produces | Next stage needs it because |
|-------|------|----------|-----------------------------|
| crds | `infrastructure/platform/crds` | Gateway API CRDs + Traefik gateway RBAC | controllers install resources of these kinds. |
| controllers | `infrastructure/platform/controllers` | external-secrets, cert-manager, MetalLB, Traefik, Longhorn (Helm) | configs are custom resources those controllers own. |
| configs | `infrastructure/platform/config` | `ClusterSecretStore`, `ClusterIssuer`, MetalLB pools, Traefik service, Longhorn `StorageClass` + gateway | apps consume all of these. |
| apps | `apps/tom` | pihole, gnosis | — |

- The first three stages set `wait: true`, so Flux blocks until each is *Ready* — CRDs established, HelmReleases healthy — before starting the next. This trades a slower first bootstrap for a deterministic one: a config CR applied before its controller exists would only error and retry-loop.
- Ordering is enforced by `dependsOn`, not filesystem layout — the split into `crds` / `controllers` / `config` directories mirrors the three phases so the boundary is obvious.
- cert-manager's own CRDs ship with its Helm chart (`crds.enabled: true`), so only Gateway API CRDs need the dedicated first stage.
- **The Gateway API bundle version is coupled to Traefik's minor version.** Traefik pins the spec version it supports (v3.7 → Gateway API v1.5, standard channel — check the shipped Traefik image version, not the chart docs, which can lag) and its provider silently stops programming Gateways when a CRD it watches is missing — the symptom is every `Gateway` stuck at `Waiting for controller` and Traefik serving its default self-signed certificate. Bump the `standard-install.yaml` URL in `crds/gateway-api/` in the same change as any Traefik chart major.

## Secret flow

No plaintext secret lives in git. Secrets are pulled from 1Password at runtime by the External Secrets Operator (ESO):

1. One bootstrap secret is seeded by hand: `1password-service-token-tom` (a 1Password service-account token) in the `external-secrets` namespace. This is the single trust root.
2. `ClusterSecretStore/1password` (`config/1password-cluster-secret-store.yaml`) uses that token via the 1Password SDK to read the `Homelab - Tom` vault.
3. `ExternalSecret`s reference the store and materialize native Kubernetes `Secret`s (`creationPolicy: Owner`) — e.g. `pihole-web-password`, the Cloudflare API token for cert-manager, and the Discord webhook for Flux alerts.

Decisions:

- **One human-provided secret.** Everything else derives from the vault, so rotating a credential happens in 1Password and propagates on the next sync — nothing to re-commit.
- **ESO must be up before any `ExternalSecret`**, which is why external-secrets is a controller (stage 2) and the store is a config (stage 3).
- **No `ExternalSecret` may live in `clusters/tom/`.** The flux-system Kustomization dry-runs everything it applies, so on a fresh cluster an `ExternalSecret` there fails validation before ESO's CRDs exist and deadlocks the entire chain at bootstrap. The Discord-webhook `ExternalSecret` therefore lives in the config stage (`config/flux-discord-webhook.yaml`); `alerts.yaml` keeps only the `Provider`/`Alert`, whose CRDs ship with Flux itself.

## Ingress and TLS

Every web app is reached over HTTPS at `<app>.dloez.dev` through the same four pieces:

- **MetalLB** (L2) hands out LAN IPs from a pool (`config/ip-pools.yaml`). Bare metal has no cloud load balancer, so MetalLB fills that role. `traefik-custom` pins `192.168.1.19` as the single ingress entrypoint; pihole's DNS service pins `192.168.1.18`.
- **Traefik** is the `GatewayClass` (`gatewayClassName: traefik`). It runs with the Kubernetes Gateway provider **on** and the legacy Ingress provider **off** — the cluster is Gateway-API-only. Traefik's built-in service is disabled in favor of the explicit `traefik-custom` service so the MetalLB IP is declared, not guessed.
- **cert-manager** issues a per-host certificate through `ClusterIssuer/cloudflare-issuer` (Let's Encrypt ACME, **DNS-01** via Cloudflare). DNS-01 was chosen over HTTP-01 so certificates issue without exposing an inbound HTTP challenge endpoint.
- Each app declares a `Gateway` (a `web`/HTTP + `websecure`/HTTPS listener) and `HTTPRoute`s. HTTP→HTTPS is redirected twice over: a Traefik entrypoint redirect (`web`→`websecure`) and a per-route `RequestRedirect` (301). The Gateway terminates TLS with the secret cert-manager wrote.

Why Gateway API over Ingress: it is the successor API, keeps routing — redirects, path rewrites like pihole's `/`→`/admin` — declarative and portable, and avoids Traefik-proprietary CRDs.

## Image automation

pihole's container tag is updated by Flux, but changes land through a reviewed PR, never a direct push to `main`:

1. `ImageRepository/pihole` scans `docker.io/pihole/pihole` every 5m.
2. `ImagePolicy/pihole` picks the newest CalVer tag (`YYYY.MM.RELEASE`, alphabetical ascending).
3. `ImageUpdateAutomation` rewrites the tag on the line marked `# {"$imagepolicy": "flux-system:pihole"}` in `apps/tom/pihole.yaml` (Setters strategy) and pushes it to the branch **`image-automation-tom-pihole`** — not `main`.
4. CI turns that branch into a titled, `dloez`-assigned PR; on merge Flux reconciles `main` and rolls pihole forward, and CI deletes the branch. Branch naming is `image-automation-<cluster>-<app>` — see the [general CI reference](../../general/reference/ci.md).

Decisions:

- **PR-gated, not auto-merged.** A homelab still wants a human glance at an image bump before it hits the only DNS server on the network.
- The `image-automation-<cluster>-<app>` convention encodes enough for CI to generate the PR title and to scope branch cleanup.

## The gnosis staking app

`apps/tom/gnosis.yaml` runs a Gnosis Chain validator: Nethermind (execution) + Lighthouse beacon (consensus) + Lighthouse validator client, deposit flow in the [how-to](../how-to/deploy-gnosis-validator.md). Its shape breaks a few repo habits on purpose:

- **Pinned to `worker1` with `nodeSelector`.** Longhorn attaches volumes over iSCSI from any node; a chain database doing constant random I/O must sit on the node that physically holds the replica, or sync falls behind.
- **`replicas: 1` + `strategy: Recreate` + doppelganger protection on the validator client.** Two live signers with the same key is the one slashable offence. This workload must never be made "highly available" — the rolling-update overlap of a default Deployment is exactly the failure mode.
- **p2p over `hostPort`** (30303 execution, 9000/9001 beacon) instead of a MetalLB service: peers need the node's real address, and one worker means no scheduling constraint cost. Inbound peering also works without router port-forwards (outbound dialing suffices), just with fewer peers.
- **No Gateway/HTTPRoute.** Nothing here is a web app; the engine and beacon APIs stay cluster-internal.
- **Key material follows the standard ESO flow** — keystores, password, JWT, and fee recipient live in the 1Password vault and materialize as Secrets. The mnemonic that generated the keys never touches the cluster or 1Password; it exists only on paper.

## Storage

Longhorn provides dynamic block storage. The default `StorageClass`, `longhorn-single-replica`, sets `numberOfReplicas: 1`.

- With a **single worker**, cross-node replication is impossible — extra replicas would only duplicate data on the same disk. One replica is the honest setting and saves space.
- Trade-off: no in-cluster redundancy; losing the worker's disk loses volume data. Acceptable for a homelab, and the worker reserves an 895 GB Talos user volume (`persistent-cluster-data`) for it.

---

Up: [Homelab index](../index.md) · Related: [Bootstrap](../how-to/bootstrap-cluster.md), [Dictionary](../reference/dictionary.md)
