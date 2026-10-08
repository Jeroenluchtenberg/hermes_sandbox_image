# Sandbox image for Hermes' Docker terminal backend — this is where the
# agent's shell commands actually run. Hermes itself runs on the host as a
# systemd service and never uses this image for its own process.
#
# Base is upstream's documented example (Python + Node), which Hermes' own
# container initialisation assumes is present. Everything below it is the
# point of having a custom image at all: dependencies the agent needs are
# baked in, rather than installed at runtime into a container the idle reaper
# deletes 300 seconds later.
FROM nikolaik/python-nodejs:python3.11-nodejs20

# Pinned, like every other image reference in this repo. Bump deliberately:
#   gh api repos/cooklang/cookcli/releases --jq '.[0].tag_name'
ARG COOKCLI_VERSION=v0.32.1

# musl build rather than gnu: statically linked, so it does not care what
# libc the base image ships and survives a base-image bump.
ADD https://github.com/cooklang/cookcli/releases/download/${COOKCLI_VERSION}/cook-x86_64-unknown-linux-musl.tar.gz /tmp/cook.tar.gz
RUN tar -xzf /tmp/cook.tar.gz -C /usr/local/bin cook \
    && chmod 0755 /usr/local/bin/cook \
    && rm /tmp/cook.tar.gz \
    && cook --version

# GitHub CLI. Bump deliberately:
#   gh api repos/cli/cli/releases/latest --jq .tag_name  (without the leading v)
ARG GH_VERSION=2.102.0

# Upstream's release tarball is a statically linked Go binary, so like cook it
# does not depend on the base image's libc. The `gh --version` check fails the
# build if the download or extraction ever goes wrong.
ADD https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz /tmp/gh.tar.gz
RUN tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install -m 0755 /tmp/gh_*_linux_amd64/bin/gh /usr/local/bin/gh \
    && rm -rf /tmp/gh.tar.gz /tmp/gh_*_linux_amd64 \
    && gh --version

# Ordinary CLI tooling an agent reaches for constantly. Kept deliberately
# short: every addition is weight on a pull that happens on each host, and
# the agent can install throwaway things itself at runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        jq \
        ripgrep \
        less \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python libraries the agent's scripts commonly need (YAML config, reading
# PDFs). Pinned for reproducible builds; bump deliberately:
#   curl -s https://pypi.org/pypi/<name>/json | jq -r .info.version
RUN pip install --no-cache-dir \
        pyyaml==6.0.3 \
        pypdf==6.19.0 \
    && python -c "import yaml, pypdf"

# Hermes bind-mounts its own state over /workspace and /root at container
# creation, so nothing here should expect to own those paths.
WORKDIR /workspace
