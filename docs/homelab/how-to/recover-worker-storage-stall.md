# Recover worker1 from a storage stall

Bring the `gnosis` validator (and every other Longhorn-backed workload) back after worker1's NVMe stops completing I/O. Why this happens and how to tell it apart from a Longhorn-only fault is in [architecture → storage](../explanation/architecture.md#storage). The short version: the node still reports `Ready` and every pod still shows `Running`, but nothing that touches a volume makes progress, and the kubelet cannot kill the stuck containers.

## Prerequisites

- `kubectl` access to `tom`.
- The cluster's `talosconfig` at `homelab/infrastructure/talos/tom/talosconfig` (gitignored, generated at bootstrap) — `export TALOSCONFIG=homelab/infrastructure/talos/tom/talosconfig`.
- The validator has been silent long enough that a reboot costs less than waiting — on Gnosis every missed epoch is ~80 s of penalties, so this is almost immediately true.

## Steps

1. Confirm it is the node and not the app. All of these together mean a storage stall; any one alone does not:

   ```sh
   kubectl get events -n gnosis --sort-by=.lastTimestamp | tail   # "failed liveness probe, will be restarted" repeating, RESTARTS stays 0
   kubectl logs -n gnosis deploy/lighthouse-beacon --tail=20        # hangs and times out; so do exec and port-forward
   kubectl get volumes.longhorn.io -n longhorn-system              # one or more volumes detaching/faulted
   talosctl -n 192.168.1.11 dmesg | grep -E 'medium error|EXT4-fs error|Remounting filesystem read-only' | tail
   talosctl -n 192.168.1.11 processes | awk '$3 ~ /D/'             # csi-resizer and the like stuck in D state
   ```

2. Save the kernel log before rebooting — it does not survive the power-cycle, and it is the only record of what the drive did:

   ```sh
   talosctl -n 192.168.1.11 dmesg > worker1-dmesg-$(date -u +%Y%m%dT%H%M).log
   ```

   Do not spend time fetching pod logs: `kubectl logs`, `talosctl logs -k` and `talosctl read /var/log/pods/...` all hang on the stuck filesystem, and the `instance-manager` pod's log directory is deleted when the pod is recreated after the reboot anyway.

3. Power-cycle the node. A graceful reboot cannot unmount the wedged filesystems, so go straight to `--mode powercycle`:

   ```sh
   talosctl -n 192.168.1.11 reboot --mode powercycle --wait=false
   ```

4. Watch it come back. The node re-registers within a minute; Longhorn then marks all three volumes `faulted`, auto-salvages them (`attached/unknown` → `attached/healthy`), and the kubelet recreates the pods, about four minutes after boot:

   ```sh
   watch -n 10 'kubectl get pods -n gnosis; kubectl get volumes.longhorn.io -n longhorn-system'
   ```

5. Let the clients catch up. Nethermind re-runs the last few hundred blocks in under a minute; the beacon head-syncs most of the gap at ~5 slots/s, then the validator client sits out its doppelganger-protection epochs before attesting again.

6. If the beacon's `distance` stops shrinking and sits at a constant ~250 slots with `speed: 0.20 slots/sec` (or `est_time: "--"`) for more than a few minutes, the two clients are in the lock-step loop described in [architecture → gnosis](../explanation/architecture.md#the-gnosis-staking-app) and will never converge; restarting either client does not help. Break it by checkpoint-syncing the beacon again. `--purge-db` alone is refused non-interactively — Lighthouse v8 needs `--purge-db-force` as well — and Flux reverts a patched Deployment within its 10-minute interval, so suspend it first:

   ```sh
   flux suspend kustomization apps
   kubectl patch deploy -n gnosis lighthouse-beacon --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--purge-db"},{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--purge-db-force"}]'
   kubectl logs -n gnosis deploy/lighthouse-beacon -f   # "Starting checkpoint sync" → "Loaded checkpoint block and state" → "Synced" in ~5 minutes
   flux resume kustomization apps                        # restores the git args; the beacon restarts once more without the purge flags
   ```

   Do not leave the purge flags in place: while they are set, every beacon restart wipes the database again. The wipe costs nothing the validator needs (keys live in the validator client's volume), but the beacon backfills history in the background for hours afterwards.

## Verification

- `talosctl -n 192.168.1.11 dmesg | grep 'EXT4-fs (sd'` — all three volumes `mounted filesystem ... r/w`.
- `kubectl get volumes.longhorn.io -n longhorn-system` — all `attached` / `healthy`.
- `kubectl logs -n gnosis deploy/lighthouse-beacon --tail=5` — `Synced`, not `Syncing`.
- `kubectl logs -n gnosis deploy/lighthouse-validator --tail=20` — `All validators active` and `synced: 1`, then attestations after the doppelganger wait; no `No synced beacon nodes`.
- `kubectl get deploy -n gnosis lighthouse-beacon -o jsonpath='{.spec.template.spec.containers[0].args}'` — no `--purge-db`, and `flux get kustomizations` shows `apps` not suspended.
- `kubectl get nodes.longhorn.io -n longhorn-system worker1 -o json | jq '.status.diskStatus[].healthData[].attributes[] | select(.name=="NumErrLogEntries")'` — note the value in the incident write-up; it increments once per stall.
