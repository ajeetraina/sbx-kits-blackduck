#!/usr/bin/env bash
# Build and push this v3 kit to Docker Hub as a multi-platform OCI artifact.
#
# A v3 kit is an OCI image and publishing IS the build: `docker buildx build`
# writes the kit annotations, stages the sources and pushes. There is no
# `sbx kit push` for v3 (that is the v2 flow).
#
#   ./scripts/push-kit.sh                              # pushes amd64+arm64, defaults
#   DETECT_VERSION=12.1.0 ./scripts/push-kit.sh        # pin the Detect version
#   BLACKDUCK_HOST=bd.acme.com ./scripts/push-kit.sh   # bake your BD host
#   DOCKERHUB_NAMESPACE=me ./scripts/push-kit.sh       # override the namespace
#
# Several kits can share this repo, so the version lives in the tag: the image
# is named after the repo and each kit is distinguished by a <kit>-<version>
# tag plus a moving <kit> tag. `latest` tracks the repo's primary kit.
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-ajeetraina777}}"
repo_name="${REPO_NAME:-sbx-kits-blackduck}"   # also the Docker Hub image name
kit_name="${KIT_NAME:-blackduck-detect}"       # the kit subdir / descriptor stem
version="${DETECT_VERSION:-12.1.0}"
blackduck_host="${BLACKDUCK_HOST:-blackduck.example.com}"
platforms="${PLATFORMS:-linux/amd64,linux/arm64}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/$repo_name"

# One invocation writes the index both architectures resolve through; two
# single-platform pushes to the same tag would replace each other.
docker buildx build "$repo_root/$kit_name" \
  -f "$repo_root/$kit_name/$kit_name.yaml" \
  --platform "$platforms" \
  --build-arg DETECT_VERSION="$version" \
  --build-arg BLACKDUCK_HOST="$blackduck_host" \
  --push \
  -t "$image:$kit_name-$version" \
  -t "$image:$kit_name" \
  -t "$image:latest" \
  --metadata-file "/tmp/$kit_name-push.json"

echo "Pushed $image:$kit_name-$version (+ $kit_name, latest)"
