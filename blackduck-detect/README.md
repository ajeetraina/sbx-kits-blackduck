# blackduck-detect

A Docker Sandbox **mixin** (kit descriptor v3) that adds [Black Duck
Detect](https://github.com/blackducksoftware/detect) — the Black Duck SCA
scanner — to any agent workload.

The overlay is self-contained: it bundles a relocatable Temurin JRE, the pinned
Detect jar, and a `detect` launcher on `PATH`. It composes onto any workload,
including one with no Java, and needs network egress at runtime only to your
Black Duck server.

## What it provides

| | |
|---|---|
| **Kind** | `mixin` |
| **Provides** | `blackduck-detect@<version>` |
| **Binary** | `/usr/local/bin/detect` |
| **Detect version** | `12.1.0` (default, pinned) |
| **Bundled JRE** | Eclipse Temurin 17 (LTS) |

### Capabilities

- **network-policy@1** — `install` reaches `repo.blackduck.com` (the jar) and
  the Adoptium JRE mirror; `runtime` reaches only your Black Duck host.
- **credential@1** — injects the host `blackduck` credential as
  `BLACKDUCK_API_TOKEN`. Required: Detect cannot run unauthenticated.
- **agent-context@1** — tells the agent how to run a scan safely.

## Configuration

| Arg | Default | Purpose |
|---|---|---|
| `version` | `12.1.0` | Detect release to bundle |
| `javaVersion` | `17` | Temurin JRE LTS feature version (`11`, `17`, `21`) |
| `blackduckHost` | `blackduck.example.com` | Your Black Duck server host — **override this** |

> The server host is baked into the egress policy and `BLACKDUCK_URL`, so it
> must be set at build/compose time. The default is a placeholder.

### Set the credential

Before composing, store your Black Duck API token in the host credential store
under the service name `blackduck`, so sbx can inject it as
`BLACKDUCK_API_TOKEN`.

## Build

```sh
cd blackduck-detect

# validate the descriptor (fast — fails before any content is built)
docker buildx build . -f blackduck-detect.yaml --output type=cacheonly

# build an OCI layout for conformance checking
docker buildx build . -f blackduck-detect.yaml -t blackduck-detect:12.1.0 \
  --build-arg BLACKDUCK_HOST=bd.acme.com \
  --output type=oci,dest=/tmp/blackduck-detect-layout,tar=false

# conformance (tag only, not name:version)
kit-tck validate --layout /tmp/blackduck-detect-layout 12.1.0
```

## Run

Compose the mixin onto any workload (e.g. a Claude Code sandbox):

```sh
sbx run ./<workload> \
  --kit ./blackduck-detect \
  --kit-arg blackduck-detect.blackduckHost=bd.acme.com \
  .
```

Then, inside the sandbox:

```sh
detect --detect.source.path=.
```

Inspect resolved declarations without a sandbox:

```sh
sbx kit inspect ./blackduck-detect
```

## Publish

Build both platforms in one push so the index serves each architecture:

```sh
docker buildx build . -f blackduck-detect.yaml \
  --platform linux/amd64,linux/arm64 --push \
  --build-arg BLACKDUCK_HOST=bd.acme.com \
  -t <registry>/blackduck-detect:12.1.0 \
  -t <registry>/blackduck-detect:latest
```

## Licensing

Black Duck Detect is distributed under Black Duck's commercial EULA, not an OSI
license. This kit packages and runs it; it does not relicense it. You need a
valid Black Duck SCA entitlement and server to use it.
