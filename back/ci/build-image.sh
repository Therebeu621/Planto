#!/bin/sh
set -eu

variant="${1:?usage: build-image.sh <jvm|native> <git_sha>}"
git_sha="${2:?usage: build-image.sh <jvm|native> <git_sha>}"
context="${CI_PROJECT_DIR:-.}"

case "$variant" in
  jvm)
    dockerfile="src/main/docker/Dockerfile.jvm"
    destination="backend:${git_sha}-jvm"
    tar_path="plant-backend-${git_sha}-jvm.tar"
    ;;
  native)
    dockerfile="src/main/docker/Dockerfile.native"
    destination="backend:${git_sha}-native"
    tar_path="plant-backend-${git_sha}-native.tar"
    ;;
  *)
    echo "Unknown image variant: $variant" >&2
    exit 1
    ;;
esac

/kaniko/executor \
  --context "${context}" \
  --dockerfile "${dockerfile}" \
  --no-push \
  --destination "${destination}" \
  --tar-path "${tar_path}"
