talosctl gen secrets --talos-version=1.10
talosctl gen config tom https://192.168.1.10:6443 --talos-version 1.10 --with-secrets secrets.yaml --config-patch-control-plane @controlplane1.patch.yaml --config-patch-worker @worker1.patch.yaml --config-patch @base.patch.yaml
talosctl apply-config --insecure --nodes 192.168.1.132 --file controlplane.yaml
talosctl apply-config --insecure --nodes 192.168.1.131 --file worker.yaml
talosctl --talosconfig ./talosconfig config endpoints 192.168.1.10
talosctl --nodes 192.168.1.10 --talosconfig=./talosconfig bootstrap
talosctl kubeconfig --nodes 192.168.1.10 --talosconfig=./talosconfig
