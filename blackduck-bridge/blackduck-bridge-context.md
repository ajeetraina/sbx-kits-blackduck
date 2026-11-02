# Black Duck Bridge CLI is available

This sandbox has **Black Duck Bridge CLI** installed - the unified orchestrator
that runs Black Duck security scans in a pipeline-style, single-command
interface. Use it to scan the current project and upload results to the
configured Black Duck server.

`bridge-cli` is on `PATH` at `/usr/local/bin/bridge-cli`. It is the
self-contained "bundle" build: it ships its own JRE and stage adapters, so no
download happens at scan time.

## Running a Black Duck SCA scan

Bridge invokes scans per **stage**. The default here is Black Duck SCA (the
stage runs Detect under the hood). Connection details are preset, so a scan of
the current directory is just:

```sh
bridge-cli --stage blackducksca
```

- `BRIDGE_BLACKDUCKSCA_URL` is preset to the configured server.
- `BRIDGE_BLACKDUCKSCA_TOKEN` is injected from the host credential store.

> The stage is named `blackducksca`, **not** `blackduck` - Bridge errors on the
> old value.

**Never pass the token on the command line** (e.g. `blackducksca.token=...`);
it would leak into process listings and logs. Rely on the environment.

## Useful arguments

Parameters are passed as `key=value` pairs after the stage (or via a JSON
`--input file.json`, or as `BRIDGE_*` env vars):

- `blackducksca.scan.full=true` - full scan (default) vs. `false` for a rapid scan.
- `blackducksca.scan.failure.severities='BLOCKER,CRITICAL,HIGH'` - fail the run on findings at these severities.
- `detect.args='--detect.cleanup=false'` - pass raw options through to the underlying Detect engine.
- `bridge-cli --version` - print the bundled Bridge version (offline).
- `bridge-cli --help` / `bridge-cli --list` - option reference and available stages/tools (offline).
- `bridge-cli --diagnostics` - emit debug logs and `diagnostics.json` for troubleshooting.

## Other stages

The same binary drives Coverity, Polaris, and SRM. Those stages authenticate to
*different* servers and read *different* env vars, so they need their own URL,
token, and network egress - this kit's egress and injected credential target
the Black Duck SCA server only. To use another stage, allow its host
(`sbx policy allow network <host>`) and export its vars, e.g.:

- **Polaris**: `bridge-cli --stage polaris` with `BRIDGE_POLARIS_SERVERURL`, `BRIDGE_POLARIS_ACCESSTOKEN`.
- **SRM**: `bridge-cli --stage srm` with `BRIDGE_SRM_URL`, `BRIDGE_SRM_APIKEY`, `BRIDGE_SRM_ASSESSMENT_TYPES=SAST,SCA`.
- **Coverity**: `bridge-cli --stage coverity` with `BRIDGE_COVERITY_CONNECT_URL`, `BRIDGE_COVERITY_CONNECT_USER_NAME`, `BRIDGE_COVERITY_CONNECT_USER_PASSWORD`.

## Notes

- Egress is restricted to the Black Duck SCA server host only; the scanner
  cannot reach arbitrary network endpoints.
- A Black Duck SCA (Detect) scan needs the project's package manager (npm,
  Maven, pip, …) present so dependencies can be detected; a compiled-language
  Coverity scan needs the project's build toolchain.
- If a scan fails to authenticate, the `blackduck` credential has not been set
  on the host - it is required, not optional.
