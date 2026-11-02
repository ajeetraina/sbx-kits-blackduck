#!/usr/bin/env bash
# Build and push a v3 kit from this repo to Docker Hub as a multi-platform OCI
# artifact.
#
# A v3 kit is an OCI image and publishing IS the build: `docker buildx build`
# writes the kit annotations, stages the sources and pushes. There is no
# `sbx kit push` for v3 (that is the v2 flow).
#
#   ./scripts/push-kit.sh                                  # primary kit, defaults
#   KIT_NAME=blackduck-bridge ./scripts/push-kit.sh        # push the Bridge kit
#   KIT_VERSION=12.1.0 ./scripts/push-kit.sh               # pin the version
#   BLACKDUCK_HOST=bd.acme.com ./scripts/push-kit.sh       # bake your BD host
#   DOCKERHUB_NAMESPACE=me ./scripts/push-kit.sh           # override the namespace
#
# Several kits share this repo, so the version lives in the tag: the image is
# named after the repo and each kit is distinguished by a <kit>-<version> tag
# plus a moving <kit> tag. `latest` tracks the repo's primary kit only, so two
# kits pushed to the same repo never clobber each other's `latest`.
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-ajeetraina777}}"
repo_name="${REPO_NAME:-sbx-kits-blackduck}"   # also the Docker Hub image name
kit_name="${KIT_NAME:-blackduck-detect}"       # the kit subdir / descriptor stem
primary_kit="${PRIMARY_KIT:-blackduck-detect}" # the kit that `latest` tracks
blackduck_host="${BLACKDUCK_HOST:-blackduck.example.com}"
platforms="${PLATFORMS:-linux/amd64,linux/arm64}"

# Each kit pins its own tool version through a differently named build arg.
case "$kit_name" in
  blackduck-detect) version_arg="DETECT_VERSION"; default_version="12.1.0" ;;
  blackduck-bridge) version_arg="BRIDGE_VERSION"; default_version="4.6.0" ;;
  *) echo "unknown KIT_NAME=$kit_name" >&2; exit 1 ;;
esac
# KIT_VERSION is the generic override; fall back to the legacy DETECT_VERSION
# env (kept for the existing workflow) and then the kit's default.
version="${KIT_VERSION:-${DETECT_VERSION:-$default_version}}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/$repo_name"

tags=( -t "$image:$kit_name-$version" -t "$image:$kit_name" )
if [ "$kit_name" = "$primary_kit" ]; then
  tags+=( -t "$image:latest" )
fi

# One invocation writes the index both architectures resolve through; two
# single-platform pushes to the same tag would replace each other.
docker buildx build "$repo_root/$kit_name" \
  -f "$repo_root/$kit_name/$kit_name.yaml" \
  --platform "$platforms" \
  --build-arg "$version_arg=$version" \
  --build-arg BLACKDUCK_HOST="$blackduck_host" \
  --push \
  "${tags[@]}" \
  --metadata-file "/tmp/$kit_name-push.json"

echo "Pushed $image:$kit_name-$version (+ $kit_name$([ "$kit_name" = "$primary_kit" ] && echo ', latest'))"
