# Bootstrap the tom cluster

Bring `tom` up from bare Talos nodes to a Flux install reconciling this repo. Run once per cluster rebuild.

## Prerequisites

- Both nodes booted on **Talos 1.10**. Talos ships no CM5 image, so flash the [community build](https://github.com/talos-rpi5/talos-builder/releases) to each node's NVMe.
- A Talos `secrets.yaml` in `homelab/infrastructure/talos/tom/`, generated with:

  ```sh
  talosctl gen secrets --talos-version=1.10
  ```

  It is gitignored — keep it out of commits.
- A **GitHub PAT** for Flux with admin rights on `dloez/dloez` (bootstrap writes a deploy key to the existing repo).
- A **1Password service-account token** with read/write on the `Homelab - Tom` vault (the vault behind `ClusterSecretStore/1password`).
- CLIs installed: `kubectl`, `flux`, `talosctl`.

## Steps

1. Flash the community Talos image to every NVMe drive and boot the nodes.
2. Find the DHCP addresses of the two nodes and export them:

   ```sh
   export CONTROLPLANE_IP=<IP>
   export WORKER_IP=<IP>
   ```

3. From `homelab/infrastructure/talos/tom/`, generate the configs, apply them, and bootstrap etcd:

   ```sh
   talosctl gen config tom https://192.168.1.10:6443 --talos-version 1.10 --with-secrets secrets.yaml --config-patch-control-plane @controlplane1.patch.yaml --config-patch-worker @worker1.patch.yaml --config-patch @base.patch.yaml
   talosctl apply-config --insecure --nodes $CONTROLPLANE_IP --file controlplane.yaml
   talosctl apply-config --insecure --nodes $WORKER_IP --file worker.yaml
   talosctl --talosconfig ./talosconfig config endpoints 192.168.1.10
   talosctl --nodes 192.168.1.10 --talosconfig=./talosconfig bootstrap
   talosctl kubeconfig --nodes 192.168.1.10 --talosconfig=./talosconfig
   ```

   This writes the node configs, applies the patches — setting hostnames `controlplane1.tom` / `worker1.tom` and static IPs `192.168.1.10` / `192.168.1.11` — bootstraps Kubernetes, and merges the kubeconfig into your local config.

4. Seed the 1Password token secret that ESO authenticates with:

   ```sh
   kubectl create namespace external-secrets
   kubectl create secret generic 1password-service-token-tom -n external-secrets --from-literal=token=<1Password service account token>
   ```

5. From `homelab/`, set `GITHUB_TOKEN=<GitHub PAT>` and bootstrap Flux with the image controllers enabled:

   ```sh
   flux bootstrap github \
       --context tom \
       --owner dloez \
       --repository https://github.com/dloez/dloez \
       --branch main \
       --personal \
       --path homelab/clusters/tom \
       --components-extra image-reflector-controller,image-automation-controller \
       --read-write-key
   ```

6. Watch the reconciliation settle:

   ```sh
   flux get kustomizations --watch
   ```

## Verification

- Talos reports healthy:

  ```sh
  talosctl --nodes 192.168.1.10 --talosconfig ./talosconfig health
  ```

- Both nodes are `Ready`:

  ```sh
  kubectl get nodes
  ```

- Every Flux `Kustomization` is `Ready`, in order — `infra-platform-crds`, `infra-platform-controllers`, `infra-platform-configs`, then `apps`:

  ```sh
  flux get kustomizations
  ```

- The seeded token flows through ESO — `ExternalSecret`s report `SecretSynced`:

  ```sh
  kubectl get externalsecrets -A
  ```

For why the stages reconcile in that order, see [architecture](../explanation/architecture.md).

---

Up: [Homelab index](../index.md)
