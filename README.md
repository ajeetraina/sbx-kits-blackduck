# sbx-kits-blackduck

[Black Duck](https://www.blackduck.com/) AppSec kits for
[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) - authored against the
v3 kit descriptor (`schemaVersion: "3"`).

These kits bring Black Duck's Application Security portfolio into sandboxed AI
coding agents: an agent running in an isolated microVM can scan the project it
is working on and surface open-source, license, and vulnerability risk without
leaving the sandbox.

## Kits

| Kit | Kind | What it adds |
|---|---|---|
| [`blackduck-detect`](./blackduck-detect) | mixin | Black Duck **Detect** SCA scanner (`detect` on PATH), with a bundled JRE and pinned jar |

## Why a mixin

A mixin overlays onto *any* agent workload - Claude Code, Codex, Copilot,
Gemini, or your own - so the same AppSec tooling drops into whatever agent the
team already runs. The `blackduck-detect` overlay is fully self-contained
(bundles its own Temurin JRE and the Detect jar), so it composes even onto a
base that ships no Java, and its only runtime network reach is your Black Duck
server.

## Quick start

```sh
# 1. store your Black Duck API token in the host credential store as `blackduck`
# 2. compose the scanner onto an agent workload
sbx run ./<workload> \
  --kit ./blackduck-detect \
  --kit-arg blackduck-detect.blackduckHost=bd.acme.com \
  .
# 3. inside the sandbox
detect --detect.source.path=.
```

See [`blackduck-detect/README.md`](./blackduck-detect/README.md) for full build,
run, and publish instructions.

## Requirements

- [`docker buildx`](https://docs.docker.com/engine/reference/commandline/buildx/) - builds the kit (BuildKit pulls the v3 frontend from the `# syntax=` line).
- [`sbx`](https://docs.docker.com/ai/sandboxes/install/) - runs and composes kits.
- [`kit-tck`](https://github.com/docker/sandbox-kit-spec) - conformance checking: `go install github.com/docker/sandbox-kit-spec/v3/cmd/kit-tck@latest`.
- A valid Black Duck SCA entitlement and server.

## License

The kit sources in this repository are MIT-licensed. Black Duck Detect itself is
distributed under Black Duck's commercial EULA and is not relicensed here.
