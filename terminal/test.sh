#!/usr/bin/env sh

set -eu

IMAGE="${1:-ubuntu:24.04}"
REPO=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to run this test" >&2
  exit 1
fi

echo "==> Testing terminal/install.sh in a clean $IMAGE container"

docker run --rm -i -v "$REPO":/repo:ro "$IMAGE" sh -s <<'INNER'
set -eu
echo "-- first install --"
sh /repo/terminal/install.sh
echo "-- verify --"
sh /repo/terminal/verify.sh /repo
echo "-- install with claude setup --"
INSTALL_CLAUDE=1 sh /repo/terminal/install.sh
echo "-- verify claude setup --"
INSTALL_CLAUDE=1 sh /repo/terminal/verify.sh /repo
INNER
