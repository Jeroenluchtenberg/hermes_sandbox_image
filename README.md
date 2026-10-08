# hermes_sandbox_image

Sandbox image for Hermes' Docker terminal backend (where the agent's shell
commands run). Migrated from `homelab/containers/hermes-sandbox`.

- Tag comes from `VERSION`; bump it when changing the image.
- `.github/workflows/build.yml` builds on PRs and publishes
  `ghcr.io/jeroenluchtenberg/hermes-sandbox:<VERSION>` and `:latest` on push to `main`.
