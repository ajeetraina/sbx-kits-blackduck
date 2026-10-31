# syntax=docker/dockerfile:1
# Minimal shell workload: the public sbx shell template, kept alive so you can
# `sbx exec` the composed mixin's tooling. Not meant to ship anything itself.
ARG BASE_IMAGE=docker/sandbox-templates:shell-docker
FROM ${BASE_IMAGE}
ENV IS_SANDBOX=1
USER agent
WORKDIR /home/agent/workspace
ENTRYPOINT ["sleep", "infinity"]
