# test/shell-workload

A throwaway v3 **workload** kit whose only job is to anchor a mixin so you can
smoke-test it.

A v3 mixin cannot run alone: the composed set needs exactly one kit with
`kind: workload` to "define the sandbox." The built-in `sbx` agents (`shell`,
`claude`, …) are not v3 kits, so composing a v3 mixin onto them fails with:

```
400 Bad Request: kit_artifacts: no kit in the set defines the sandbox itself
```

This minimal workload fills that role - the public `shell-docker` template kept
alive with `sleep infinity` - so `blackduck-detect` can be composed and
`sbx exec`'d. See the repo [README](../README.md#testing) for the smoke-test
commands.
