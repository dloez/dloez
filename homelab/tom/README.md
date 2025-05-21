# Tom

Main K8s cluster running in my home, it's name is a tribute to my cat Tom.

## Hardware
- 2x CM5116000
- 2x [compute blades](https://computeblade.com/) with TPM for secure boot and RTC

## Setup the cluster

### Prerequisites
- Nodes must be running Ubuntu (24.04).
- 1Password Connect Server `1password-credentials.json` placed at the tom cluster root dir and a token stored in 1Password. [Follow these steps to generate the credentials file and the token if you lost access to the items](https://developer.1password.com/docs/connect/get-started/).
- GitHub PAT for Flux stored in 1Password. Token must have admin rights as we are going to use an existing repository.

### Steps
