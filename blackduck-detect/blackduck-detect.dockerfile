# syntax=docker/dockerfile:1
#
# Black Duck Detect mixin overlay.
#
# Everything is staged under /out in a build stage and copied into scratch, so
# the layer lands on a filesystem we have never seen. We stage only under /opt
# and /usr/local/bin — never /home — so the overlay stays out of the agent's
# home and passes overlay-home-ownership without shipping either /home level.
#
# The build stage runs AS the target platform (no BUILDPLATFORM pin) so buildx
# emulates per-arch and the JRE smoke test below executes natively under qemu.

FROM debian:trixie-slim AS build

ARG DETECT_VERSION
ARG JAVA_FEATURE_VERSION
# Provided by buildx: amd64 | arm64
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# --- Temurin JRE (relocatable; bundled so the overlay needs no Java on base) ---
# A JRE tarball is self-contained — it carries no absolute-path assumptions, so
# copying it onto any base and pointing JAVA_HOME at it resolves inside the tree
# it ships with. Verify by composing onto a base with no Java at all.
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) TEMURIN_ARCH=x64 ;; \
      arm64) TEMURIN_ARCH=aarch64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /out/opt/blackduck/jre; \
    curl -fsSL \
      "https://api.adoptium.net/v3/binary/latest/${JAVA_FEATURE_VERSION}/ga/linux/${TEMURIN_ARCH}/jre/hotspot/normal/eclipse" \
      -o /tmp/jre.tar.gz; \
    tar -xzf /tmp/jre.tar.gz -C /out/opt/blackduck/jre --strip-components=1; \
    rm -f /tmp/jre.tar.gz; \
    # Prove the bundled JRE runs and is the pinned feature version.
    /out/opt/blackduck/jre/bin/java -version 2>&1 | grep -q "\"${JAVA_FEATURE_VERSION}"

# --- Black Duck Detect jar (pinned) ---
# The versioned URL IS the pin: repo.blackduck.com 404s on a nonexistent
# version, so `curl -f` fails the build if DETECT_VERSION is wrong — the
# provide can never claim a version the content does not have.
RUN set -eux; \
    mkdir -p /out/opt/blackduck; \
    curl -fsSL \
      "https://repo.blackduck.com/bds-integrations-release/com/blackduck/integration/detect/${DETECT_VERSION}/detect-${DETECT_VERSION}.jar" \
      -o /out/opt/blackduck/detect.jar; \
    test -s /out/opt/blackduck/detect.jar; \
    # A jar is a zip — confirm we got an archive, not an HTML error page.
    head -c2 /out/opt/blackduck/detect.jar | grep -q 'PK'

# --- detect launcher ---
# The wrapper calls the bundled java explicitly via JAVA_HOME, so it does not
# depend on anything being on PATH.
RUN set -eux; \
    mkdir -p /out/usr/local/bin; \
    printf '%s\n' \
      '#!/bin/sh' \
      '# Black Duck Detect launcher — runs the bundled jar with the bundled JRE.' \
      'exec "${JAVA_HOME:-/opt/blackduck/jre}/bin/java" -jar /opt/blackduck/detect.jar "$@"' \
      > /out/usr/local/bin/detect; \
    chmod 0755 /out/usr/local/bin/detect

# Vendor tarballs preserve the publisher's uid/gid; normalize to root so no
# foreign owner rides along into an unknown base. The agent needs none of this
# tree to be writable — it only runs the launcher.
RUN chown -R 0:0 /out

# --- The overlay: lands on any workload ---
FROM scratch
ARG BLACKDUCK_HOST
COPY --from=build /out /

# Static env belongs on the final stage; a build stage's config is discarded.
# These merge into the composed image and reach the agent process. PATH is
# appended, so we add only the JRE bin we ship.
ENV JAVA_HOME=/opt/blackduck/jre \
    DETECT_JAVA_PATH=/opt/blackduck/jre/bin/java \
    PATH=/opt/blackduck/jre/bin

# BLACKDUCK_URL is baked from the host arg so Detect needs no --blackduck.url
# flag. Rebuild/recompose with blackduckHost set to your instance.
ENV BLACKDUCK_URL=https://${BLACKDUCK_HOST}
