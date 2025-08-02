# Tom

Main K8s cluster running in my home, it's name is a tribute to my cat Tom.

## Hardware
- 2x CM5116000
- 2x [compute blades](https://computeblade.com/) with TPM for secure boot and RTC

## Setup the cluster

### Prerequisites
- Nodes must be running Ubuntu (24.04) and SSH must be configured to be able to connect using `rpi` user and the SSH public key located at `infra/certs/id_rsa.pub`.
- Private SSH key under `infra/certs/id_rsa` used by ansible to connect to the nodes.
- Ansible and the collection k3s-io/k3s-ansible installed.
- GitHub PAT for Flux. Token must have admin rights as we are going to use an existing repository.
- 1Password Service Account token with read and write permissions for the `K8s - Tom` vault.
- `kubectl` cli.
- `flux` cli.


### Steps
1. Nodes for K3s need to have different hostnames. A playbook has been created to modify the hostname and setup a static IP. To run this playbook, navigate `infra/ansible` and modify the `setup_nodes` info with the different current IPs of the nodes that will be used for the K8s cluster. Make sure to specify to configure a unique static IP and hostname for the nodes and then run `ansible-playbook setup_nodes.yaml`.

ℹ️ **Info:** This playbook configures Google DNS servers for the nodes. This if modified in other playbooks to use the internally hosted Pi-hole.

ℹ️ **Info:** Run `ansible setup_nodes.yaml -m ping` to check if ansible can reach and configure the nodes.

2. Create the K3s cluster by running `ansible-playbook k3s.orchestration.site -i inventory.yaml`.

ℹ️ **Info:** The fist time the cluster is initialized ansible automatically copies the kubeconfig to the ansible control node if the node has `kubectl` installed. To use the configuration run `kubectl config use-context tom`.

3. Navigate to `tom/k8s-cluster`, define `GITHUB_TOKEN=<GitHub PAT token>` and run:
```
flux bootstrap github \
  --owner=dloez \
  --repository=dloez \
  --branch=main \
  --path=./homelab/tom/k8s-cluster \
  --personal
```

4. Create the `external-secrets` namespace by running `kubectl apply -f external-secrets/namespace.yaml`. Then create the flux Helm repo and release for fluxcd by running:
```
kubectl apply -f external-secrets/helm-repo.yaml
kubectl apply -f external-secrets/helm-release.yaml
```

5. Create a Kubernetes secret to store the 1Password service account token by running `kubectl create secret generic onepassword-connect-token-tom --from-literal=token=<1Password Service Account token>` and run `kubectl apply -f external-secrets/1password-clustersecretstore.yaml`.
