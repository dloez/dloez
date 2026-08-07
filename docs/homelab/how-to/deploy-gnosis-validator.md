# Deploy the Gnosis validator

Bring the `gnosis` app (Nethermind execution client + Lighthouse beacon + Lighthouse validator client, declared in `homelab/apps/tom/gnosis.yaml`) from manifests to an attesting validator. The manifests deploy without any validator keys present, but the validator client stays in a crash loop until the 1Password items below exist and a deposit is made.

## Prerequisites

- The `tom` cluster reconciling normally (`flux get kustomizations` all `Ready`).
- ~510 Gi free on the worker's `persistent-cluster-data` Longhorn disk (400 Gi execution + 100 Gi beacon + slack). Check in the Longhorn UI or `kubectl get nodes.longhorn.io -n longhorn-system worker1 -o yaml`. The 400 Gi execution volume only holds because the ancient barriers in `gnosis.yaml` suppress the historical backfill — see the [architecture](../explanation/architecture.md) note before changing or removing them.
- Write access to the `Homelab - Tom` 1Password vault.
- ≥ 1 GNO plus a few xDAI for gas, in a wallet you control on Gnosis Chain.
- An **offline** machine (or at minimum a trusted, malware-free one) for key generation.

## Steps

1. Generate the JWT secret that authenticates the execution↔consensus connection, and store it in 1Password: create an item named `gnosis` in the `Homelab - Tom` vault with a field `jwt` containing the output of `openssl rand -hex 32`.
2. Generate the validator keys **offline**, following the [official Gnosis key-generation guide](https://docs.gnosischain.com/node/manual/validator/generate-keys/). You get a mnemonic (write it on paper, never digitally — it is the root of the stake), one or more `keystore-*.json` files, and a `deposit_data-*.json` file. Use one key to start.
3. Add the validator secrets to the same `gnosis` 1Password item as three more fields: `keystore-0` (the full JSON content of the keystore file), `keystore-password` (the password chosen during generation), and `fee-recipient` (a `0x…` Gnosis Chain address you control — execution-layer rewards land there).
4. Commit and push `homelab/apps/tom/gnosis.yaml` + the `apps/tom/kustomization.yaml` entry to `main` (via the usual draft PR), then let Flux reconcile: `flux reconcile kustomization apps --with-source`.
5. Wait for sync. Lighthouse checkpoint-syncs in minutes; Nethermind snap-syncs the Gnosis chain in hours to ~a day on the CM5. Watch progress: `kubectl logs -n gnosis deploy/nethermind -f` (look for decreasing block distance) and `kubectl logs -n gnosis deploy/lighthouse-beacon -f` (look for `Synced`). Nethermind reaching `Synced Chain Head to <block>` is the signal that matters; `Old Bodies`/`Old Receipts` progress lines are the historical backfill, which the ancient barriers keep short and which does not gate validation. `Old Headers` is **not** covered by the barriers and backfills all ~47.6 M headers to genesis regardless — expect it to run for hours alongside the snap sync. Until the execution client is done the beacon reports `is_optimistic: true` and logs `Head is optimistic — block and attestation production disabled`, so a beacon that says `Synced` is still not earning; Nethermind is the gate.
6. Only after both are synced, make the deposit: go to the [official Gnosis deposit portal](https://deposit.gnosischain.com), upload `deposit_data-*.json`, and send 1 GNO per validator from your wallet. Triple-check the URL — deposit-site phishing is the main way home stakers lose funds.
7. Activation takes a few hours. The validator client logs will show the doppelganger-protection wait (2–3 epochs of intentional silence) and then the first attestations.

## Verification

- `flux get kustomizations` — `apps` is `Ready`.
- `kubectl get pods -n gnosis` — all three pods `Running`, restarts stable.
- `kubectl exec -n gnosis deploy/lighthouse-beacon -- curl -s http://localhost:5052/eth/v1/node/syncing` — `"is_syncing":false`.
- `kubectl logs -n gnosis deploy/lighthouse-validator | grep -i attest` — successful attestations after activation.
- Public dashboard: look up your validator's public key on [beaconchain.gnosischain.com](https://beaconchain.gnosischain.com) — the Gnosis fork of beaconcha.in — where the balance should tick upward every epoch. No wallet connection is needed or wanted: the pubkey is the lookup key, so monitoring is read-only from any device. Alternatives are [dora.gnosischain.com](https://dora.gnosischain.com) and [beacon.gnosisscan.io](https://beacon.gnosisscan.io). For phone alerts on missed duties, the beaconcha.in **Beaconchain Dashboard** app supports Gnosis validators and pushes notifications when one goes offline.

## Operational rules

- **Never run a second instance of the validator client with the same keys — anywhere.** Not on a laptop "to test", not as a second replica, not on a backup node. Two signers with one key is the only realistic way to get slashed. The Deployment is intentionally `replicas: 1`, `strategy: Recreate`, and doppelganger protection stays on.
- To add validators later: generate more keys from the same mnemonic (offline), add `keystore-1`, `keystore-2`, … fields to the 1Password item, extend the `gnosis-validator-keys` `ExternalSecret` and the keystores volume in `gnosis.yaml`, and deposit 1 GNO each.
- To exit: `lighthouse account validator exit` from within the validator pod — see the Lighthouse book. Exited stake returns to the withdrawal address set at key generation.
- Client version bumps arrive as normal image-tag edits in `gnosis.yaml` (no image automation wired for now); check client release notes for breaking flags before merging.
- The beacon is the exception: it is pinned to an `unstable` image *digest* rather than a release tag while it carries an unreleased memory-leak fix. Do not "tidy" it back to a tag until v8.3.0 ships — see the [architecture](../explanation/architecture.md) note for why, and what must be restored if it is reverted.

---

Up: [Homelab index](../index.md)
