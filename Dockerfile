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

# Forgejo CLI. Bump deliberately:
#   curl -s "https://codeberg.org/api/v1/repos/forgejo-contrib/forgejo-cli/releases?limit=1" | jq -r '.[0].tag_name'
ARG FJ_VERSION=v0.6.0

# Upstream only ships a glibc build (no musl), dynamically linked against
# OpenSSL 3 and needing glibc >= 2.39. The Debian trixie base satisfies both;
# the `fj version` check fails the build if a base-image bump ever stops
# doing so, rather than shipping a binary that dies at runtime.
ADD https://codeberg.org/forgejo-contrib/forgejo-cli/releases/download/${FJ_VERSION}/forgejo-cli-x86_64-linux.tar.gz /tmp/fj.tar.gz
RUN tar -xzf /tmp/fj.tar.gz -C /usr/local/bin fj \
    && chmod 0755 /usr/local/bin/fj \
    && rm /tmp/fj.tar.gz \
    && fj version

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

# Hermes bind-mounts its own state over /workspace and /root at container
# creation, so nothing here should expect to own those paths.
WORKDIR /workspace
