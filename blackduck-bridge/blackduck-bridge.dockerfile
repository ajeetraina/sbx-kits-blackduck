# syntax=docker/dockerfile:1
#
# Black Duck Bridge CLI mixin overlay.
#
# Everything is staged under /out in a build stage and copied into scratch, so
# the layer lands on a filesystem we have never seen. We stage only under /opt
# and /usr/local/bin - never /home - so the overlay stays out of the agent's
# home and passes overlay-home-ownership without shipping either /home level.
#
# The build stage runs AS the target platform (no BUILDPLATFORM pin) so buildx
# emulates per-arch and the bundled JRE smoke test below executes natively
# under qemu.

FROM debian:trixie-slim AS build

ARG BRIDGE_VERSION
# Provided by buildx: amd64 | arm64
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates unzip \
 && rm -rf /var/lib/apt/lists/*

# --- Bridge CLI bundle (pinned, self-contained) ---
# The "bundle" flavour ships its own JRE and the stage adapters, so the overlay
# needs no Java on the base and performs no tool download at scan time. The
# versioned URL IS the pin: repo.blackduck.com 404s on a nonexistent version,
# so `curl -f` fails the build if BRIDGE_VERSION is wrong - the provide can
# never claim a version the content does not have.
#
# arm64's artifact is named `linux_arm`, not `linuxarm64`; amd64 is `linux64`.
# The zip's single top-level directory is version-suffixed, so we extract to a
# temp dir and move whatever one directory results - the name never leaks into
# our paths.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) BRIDGE_ARCH=linux64 ;; \
      arm64) BRIDGE_ARCH=linux_arm ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    base="https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/bridge/binaries/bridge-cli-bundle"; \
    curl -fsSL \
      "${base}/${BRIDGE_VERSION}/bridge-cli-bundle-${BRIDGE_VERSION}-${BRIDGE_ARCH}.zip" \
      -o /tmp/bridge.zip; \
    test -s /tmp/bridge.zip; \
    # A zip starts with PK - confirm we got an archive, not an HTML error page.
    head -c2 /tmp/bridge.zip | grep -q 'PK'; \
    mkdir -p /tmp/bridgex /out/opt/blackduck; \
    unzip -q /tmp/bridge.zip -d /tmp/bridgex; \
    rm -f /tmp/bridge.zip; \
    dir="$(ls -d /tmp/bridgex/*/)"; \
    mv "${dir}" /out/opt/blackduck/bridge; \
    test -x /out/opt/blackduck/bridge/bridge-cli

# --- Prove the bundle is the pinned version and the binary runs offline ---
# `versions.txt` carries the *bundle* version (BRIDGE_VERSION), which is the
# provide; `bridge-cli --version` prints the CLI's own internal version, so we
# assert the pin against versions.txt and use --version only to prove the binary
# executes under the target arch. bridge-cli is a static Go ELF (no JRE needed
# to launch), so this runs on any base. HOME is pointed at a temp dir so
# bridge-cli's working state never touches a path we do not ship.
RUN set -eux; \
    grep -q "${BRIDGE_VERSION}" /out/opt/blackduck/bridge/versions.txt; \
    HOME=/tmp/bridge-home /out/opt/blackduck/bridge/bridge-cli --version; \
    rm -rf /tmp/bridge-home

# --- bridge-cli launcher ---
# The wrapper execs the bundle's own launcher by absolute path, so bridge-cli
# resolves its install dir (and bundled JRE) relative to itself regardless of
# the base's PATH or Java.
RUN set -eux; \
    mkdir -p /out/usr/local/bin; \
    printf '%s\n' \
      '#!/bin/sh' \
      '# Black Duck Bridge CLI launcher - runs the bundled, self-contained CLI.' \
      'exec /opt/blackduck/bridge/bridge-cli "$@"' \
      > /out/usr/local/bin/bridge-cli; \
    chmod 0755 /out/usr/local/bin/bridge-cli

# Vendor archives preserve the publisher's uid/gid; normalize to root so no
# foreign owner rides along into an unknown base. The agent needs none of this
# tree to be writable - it only runs the launcher.
RUN chown -R 0:0 /out

# --- The overlay: lands on any workload ---
FROM scratch
ARG BLACKDUCK_HOST
COPY --from=build /out /

# BRIDGE_BLACKDUCKSCA_URL is baked from the host arg so a Black Duck SCA scan
# needs no blackducksca.url argument. Rebuild/recompose with blackduckHost set
# to your instance. The API token is injected at runtime from the host
# credential store (see the kit descriptor), never baked here.
ENV BRIDGE_BLACKDUCKSCA_URL=https://${BLACKDUCK_HOST}
