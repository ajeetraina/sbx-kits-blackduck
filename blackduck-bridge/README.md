# blackduck-bridge

A Docker Sandbox **mixin** (kit descriptor v3) that adds [Black Duck Bridge
CLI](https://documentation.blackduck.com/bundle/bridge/page/documentation/c_overview.html) -
the unified orchestrator for Black Duck security scans - to any agent workload.

Bridge runs Black Duck's scanners (Black Duck SCA, Coverity, Polaris, SRM)
behind one consistent command. This kit bundles the self-contained "bundle"
build, which ships its own JRE and stage adapters, so the overlay composes onto
any workload - including one with no Java - and performs no tool download at
scan time. It needs network egress at runtime only to your Black Duck server.

## What it provides

| | |
|---|---|
| **Kind** | `mixin` |
| **Provides** | `blackduck-bridge@<version>` |
| **Binary** | `/usr/local/bin/bridge-cli` |
| **Bridge version** | `4.6.0` (default, pinned) |
| **Default stage** | `blackducksca` (Black Duck SCA) |

### Capabilities

- **network-policy@1** - `install` reaches `repo.blackduck.com` (the bundle
  zip); `runtime` reaches only your Black Duck host. The bundle needs no tool
  download at scan time, so runtime egress to the repo is not granted.
- **credential@1** - injects the host `blackduck` credential as
  `BRIDGE_BLACKDUCKSCA_TOKEN`. Required: Bridge cannot authenticate unseeded.
- **agent-context@1** - tells the agent how to run a scan safely.

## Configuration

| Arg | Default | Purpose |
|---|---|---|
| `version` | `4.6.0` | Bridge CLI bundle release to bundle |
| `blackduckHost` | `blackduck.example.com` | Your Black Duck SCA server host - **override this** |

> The server host is baked into the egress policy and `BRIDGE_BLACKDUCKSCA_URL`,
> so it must be set at build/compose time. The default is a placeholder.

### Set the credential

Before composing, store your Black Duck API token in the host credential store
under the service name `blackduck`, so sbx can inject it as
`BRIDGE_BLACKDUCKSCA_TOKEN`.

## Build

```sh
cd blackduck-bridge

# validate the descriptor (fast - fails before any content is built)
docker buildx build . -f blackduck-bridge.yaml --output type=cacheonly

# build an OCI layout for conformance checking
docker buildx build . -f blackduck-bridge.yaml -t blackduck-bridge:4.6.0 \
  --build-arg BLACKDUCK_HOST=bd.acme.com \
  --output type=oci,dest=/tmp/blackduck-bridge-layout,tar=false

# conformance (tag only, not name:version)
kit-tck validate --layout /tmp/blackduck-bridge-layout 4.6.0
```

## Run

Compose the mixin onto any workload (e.g. a Claude Code sandbox):

```sh
sbx run ./<workload> \
  --kit ./blackduck-bridge \
  --kit-arg blackduck-bridge.blackduckHost=bd.acme.com \
  .
```

Then, inside the sandbox:

```sh
bridge-cli --stage blackducksca
```

Inspect resolved declarations without a sandbox:

```sh
sbx kit inspect ./blackduck-bridge
```

## Bridge vs. Detect

`blackduck-detect` ships the SCA scanner (Detect) directly; `blackduck-bridge`
ships the orchestrator that *drives* Detect for the SCA stage and additionally
fronts Coverity, Polaris, and SRM. Use `blackduck-detect` for a focused SCA
scan; use `blackduck-bridge` when you want the pipeline-style entry point or
need the other stages. The Bridge bundle is self-contained (its own JRE), so
this kit needs no separate Temurin download.

Other stages authenticate to different servers with different env vars; this
kit's egress and injected credential target the Black Duck SCA server. See
[`blackduck-bridge-context.md`](./blackduck-bridge-context.md) for the per-stage
variables.

## Publish

Build both platforms in one push so the index serves each architecture:

```sh
docker buildx build . -f blackduck-bridge.yaml \
  --platform linux/amd64,linux/arm64 --push \
  --build-arg BLACKDUCK_HOST=bd.acme.com \
  -t <registry>/blackduck-bridge:4.6.0 \
  -t <registry>/blackduck-bridge:latest
```

## Licensing

Black Duck Bridge CLI is distributed under Black Duck's commercial EULA, not an
OSI license. This kit packages and runs it; it does not relicense it. You need a
valid Black Duck entitlement and server to use it.
