# Black Duck Detect (SCA) is available

This sandbox has **Black Duck Detect** installed for software composition
analysis (SCA). Use it to scan the current project for open-source components,
license risk, and known vulnerabilities (BDSA / CVE), uploading results to the
configured Black Duck server.

## Running a scan

`detect` is on `PATH` at `/usr/local/bin/detect`. It runs a bundled Temurin JRE
and the pinned Detect jar — no download happens at scan time.

Connection details are already set, so a scan of the current directory is just:

```sh
detect --detect.source.path=.
```

- `BLACKDUCK_URL` is preset to the configured server.
- `BLACKDUCK_API_TOKEN` is injected from the host credential store.

**Never pass the API token on the command line** (e.g. `--blackduck.api.token=...`)
— it would leak into process listings and logs. Rely on the environment.

## Useful options

- `--detect.project.name=<name>` / `--detect.project.version.name=<ver>` — name the project/version in Black Duck.
- `--detect.tools=DETECTOR,SIGNATURE_SCAN` — choose scan types (dependency detectors, signature scan, etc.).
- `--detect.blackduck.signature.scanner.disabled=true` — dependency-only scan, skip the signature scanner.
- `--blackduck.trust.cert=true` — accept the server's TLS cert if it is self-signed (on-prem).
- `--detect.wait.for.results=true` — block until the server finishes processing, so results are queryable when the command returns.
- `detect --help` — full option reference (runs offline).

## Notes

- Egress is restricted to the Black Duck server host only; the scanner cannot
  reach arbitrary network endpoints.
- Scan output is written under `~/blackduck/` by default.
- If a scan fails to authenticate, the `blackduck` credential has not been set
  on the host — it is required, not optional.
