FROM docker.io/library/python:3.12-slim-bookworm@sha256:392307d22300de8b5986851a12d9176dfc0fc073e65bf6523ebd7dcbeb23564e
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep procps && rm -rf /var/lib/apt/lists/*
COPY julia/ /opt/julia/
COPY codex-package/ /opt/codex/
RUN ln -s /opt/codex/bin/codex /usr/local/bin/codex && ln -s /opt/codex/bin/codex-code-mode-host /usr/local/bin/codex-code-mode-host
RUN ln -s /opt/julia/bin/julia /usr/local/bin/julia && mkdir -p /home/lab/.juliaup/bin && ln -s /opt/julia/bin/julia /home/lab/.juliaup/bin/julia
ENV PATH=/opt/julia/bin:/usr/local/bin:/usr/bin:/bin HOME=/home/lab JULIA_DEPOT_PATH=/workspace/.sandbox-home/julia CODEX_HOME=/workspace/.sandbox-home/codex PYTHONUSERBASE=/workspace/.sandbox-home/python
WORKDIR /workspace
