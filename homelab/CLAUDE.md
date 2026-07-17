# homelab/

**MANDATORY** rules when working in `homelab/`.

## Shared rules (deferred up)

- YAML markers + prettier — see root CLAUDE.md → "YAML & Formatting".
- Secrets — see root CLAUDE.md → "Secrets".
- Commits & PRs — see root CLAUDE.md → "Commit & PR Conventions".
- Checks & verification — see root CLAUDE.md → "Checks & Verification".

## Homelab-specific rules

- New apps go under `apps/tom/` and must be wired in via `apps/tom/kustomization.yaml` — an unlisted manifest is never applied.
- Respect the reconcile ordering **crds → controllers → configs → apps**. A resource that needs a CRD, controller, or config CR must land in a later stage than what it depends on; add `dependsOn` if you introduce a new stage.
- Cluster secrets come from 1Password via the External Secrets Operator — add an `ExternalSecret`, never a literal `Secret` in git.
- There is **no test suite**. Verify against the live cluster:

  ```sh
  flux get kustomizations
  flux reconcile kustomization <name> --with-source
  ```

## Documentation → see docs/homelab/

- [Overview](../docs/homelab/index.md)
- [Architecture](../docs/homelab/explanation/architecture.md)
- [Bootstrap the cluster](../docs/homelab/how-to/bootstrap-cluster.md)
- [Dictionary](../docs/homelab/reference/dictionary.md)
