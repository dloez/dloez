# CI

Three GitHub Actions workflows live in [`.github/workflows/`](../../../.github/workflows). This page is a lookup for what each does and the gotchas that bite — the exact triggers, job names, action versions, and step details are readable in the YAML itself, so they are not restated here.

## `flux-image-update-pr.yaml` — Flux auto image update

Turns Flux image-automation pushes into reviewable PRs, and cleans up after merge. When an `image-automation-<cluster>-<app>` branch is created it opens a titled PR into `main` (e.g. `(TOM) Upgrade Pihole`) assigned to `dloez`; when such a PR merges it deletes the head branch.

### Gotchas

- **Uses `FLUX_GITHUB_TOKEN` (a PAT), not `GITHUB_TOKEN`.** A PR created with the default `GITHUB_TOKEN` does **not** trigger downstream workflows (GitHub suppresses the events to prevent recursion) — so the `format.yaml` checks would never run on the auto-PR. The PAT sidesteps that. Branch cleanup still uses the default `GITHUB_TOKEN` (a plain delete needs no downstream events).
- **Bound to the `Tom` environment**, which scopes the `FLUX_GITHUB_TOKEN` secret.

## `format.yaml` — Format files

Enforces the YAML conventions on PRs (see [conventions.md](conventions.md)): a marker job inserts missing `---` markers via `scripts/add-yaml-markers.sh`, then a prettier job reformats. Both push their fixes back to the PR head branch as `github-actions[bot]`.

### Gotchas

- **Ordering:** prettier runs only when the marker job pushed nothing. If markers were added, the marker commit re-triggers the workflow; prettier runs on that next pass. So a PR needing both fixes takes two workflow runs to settle.
- Expect bot commits on your PR — pull before pushing more.

## `test-install.yaml` — Test terminal install

Validates the terminal bootstrap: `shellcheck` lint, an `ubuntu:24.04` container test (`sh terminal/test.sh`), and a macOS run of `install.sh` + `verify.sh`. See [layout and testing](../../terminal/reference/layout-and-testing.md) for the per-job breakdown.

### Gotchas

- **macOS is gated off `push`** — it runs only on schedule and manual dispatch, because macOS can't run the container test and the runners are slow/scarce.

See also: [conventions.md](conventions.md), [docs index](../../index.md).
