# shellcheck disable=SC2034  # versions here are consumed by component.sh
# Renovate-tracked pin for the falcos-bootc-updates RPM. The asset filename
# derives from the version, relying on releases keeping tag = v<rpm version>
# and release -1. .github/workflows/checksums.yml recomputes the SHA256 on bumps.
# renovate: datasource=github-releases depName=jayelg/falcos-bootc-updates extractVersion=^v(?<version>.*)$
FALCOS_BOOTC_UPDATES_VERSION="0.1.1"
FALCOS_BOOTC_UPDATES_SHA256="2272f4682aff39bd0bff7b2b13db71854da971eda99b6e84653ba1da32d94b7a"
