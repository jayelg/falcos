# shellcheck disable=SC2034  # versions here are consumed by component.sh
# Renovate-tracked pin for the Bitwarden CLI binary.

# No official checksum is published (trust-on-first-use). When a PR bumps
# BW_VERSION, .github/workflows/checksums.yml recomputes BW_SHA256 from the
# release asset and pushes the fix to the PR branch.
# renovate: datasource=github-releases depName=bitwarden/clients extractVersion=^cli-v(?<version>.*)$
BW_VERSION="2026.6.0"
BW_SHA256="392549496c712ab86bfbd6c27302df9fd2c431cfc7a47e26941ac3e3893f4d27"
