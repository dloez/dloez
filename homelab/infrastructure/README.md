# Dloez homelab
My homelab is composed on different sites (different locations like hardware at my home, at a cloud provider, etc) that hosts different services depending on their privacy and availability requirements.


## Tom
Main K8s cluster running in my home, it's name is a tribute to my cat Tom. This cluster contains a single controlplane and a single worker.

### Hardware
- 2x CM5116000
- 2x [compute blades](https://computeblade.com/) with TPM for secure boot and RTC

### Setup the cluster

#### Prerequisites
- Nodes must be running Talos 1.10. Talos does not support CM5, a [community image](https://github.com/talos-rpi5/talos-builder/releases) is used for the nodes.
- Talos `secrets.yaml` file generated running `talosctl gen secrets --talos-version=1.10` available under `homelab/infrastructure/talos/tom`.
- GitHub PAT for Flux. Token must have admin rights as we are going to use an existing repository.
- 1Password Service Account token with read and write permissions for the `K8s - Tom` vault.
- `kubectl` cli.
- `flux` cli.
- `talosctl` cli.


#### Steps
1. Write the community talos image to all the NVME drives and boot up the nodes.
2. Find the IPs for the controlplane and worker nodes and define the following env variables:
```sh
export CONTROLPLANE_IP=<IP>
export WORKER_IP=<IP>
```
3. Within `homelab/infrastructure/talos/tom` run:
```sh
talosctl gen config tom https://192.168.1.10:6443 --talos-version 1.10 --with-secrets secrets.yaml --config-patch-control-plane @controlplane1.patch.yaml --config-patch-worker @worker1.patch.yaml --config-patch @base.patch.yaml
talosctl apply-config --insecure --nodes $CONTROLPLANE_IP --file controlplane.yaml
talosctl apply-config --insecure --nodes $WORKER_IP --file worker.yaml
talosctl --talosconfig ./talosconfig config endpoints 192.168.1.10
talosctl --nodes 192.168.1.10 --talosconfig=./talosconfig bootstrap
talosctl kubeconfig --nodes 192.168.1.10 --talosconfig=./talosconfig
```
This will generate the different talos config files for the controlplane and worker nodes, apply the configuratin which sets the hostnames `controlplane1.tom` and `worker1.tom` and the static IPs `192.168.1.10` and `192.168.1.11` respectively. Then it bootstrap the k8s cluster and merges the kubeconfig into the local kube config. You can check the cluster health by running `talosctl --nodes 192.168.1.10 --talosconfig ./talosconfig health` and if succeded the two nodes should appear on `kubectl get nodes`.

3. Setup the kubernets secret used for the external secrets controller conection with 1Password by running:
```sh
kubectl create namespace external-secrets
kubectl create secret generic 1password-service-token-tom -n external-secrets --from-literal=token=<1Password service account token>
```

4. Navigate to `homelab`, define `GITHUB_TOKEN=<GitHub PAT token>` and run:
```sh
flux bootstrap github \
    --context tom \
    --owner dloez \
    --repository https://gihub.com/dloez/dloez \
    --branch main \
    --personal \
    --path homelab/clusters/tom \
```

5. Monitor kustomizations reconciliations by running:
```sh
flux get kustomizations --watch
```
