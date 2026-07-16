# shellcheck disable=SC2034  # versions here are consumed by the scripts sourced after this file
# Renovate-tracked pins for common/frequent/040-affinity.sh. Keep each
# annotation comment directly above its version line.
#
# None of these upstreams publish official checksums, so each pin carries a
# trust-on-first-use SHA256; .github/workflows/checksums.yml recomputes the
# _SHA256 lines when a PR bumps the version pins.

# ElementalWarrior's Affinity-patched Wine, prebuilt by ryzendew's builder
# (mainline Wine fails in Affinity's installer). Tags are bare Wine versions.
# A CPU-tuned "-v4" (Zen 4/5) asset also exists per release but is skipped
# so one image serves both flavors (the laptop is Intel).
# renovate: datasource=github-releases depName=ryzendew/Affinity-Wine-Builder
AFFINITY_WINE_TAG="11.12"
AFFINITY_WINE_SHA256="44a99f2a90356790936f08620ccca573581c0bb006b9bed6899dd4ed465986aa"

# renovate: datasource=github-releases depName=doitsujin/dxvk extractVersion=^v(?<version>.*)$
DXVK_VERSION="3.0.1"
DXVK_SHA256="bebb6284db590535b7b005c102ebf6850c98842cff0fded9aacb74babae14c49"

# Last version validated against Affinity by ryzendew/Linux-Affinity-Installer
# was 2.14.1; if a bump breaks Affinity's OpenCL compute, pin back to that.
# renovate: datasource=github-releases depName=HansKristian-Work/vkd3d-proton extractVersion=^v(?<version>.*)$
VKD3D_PROTON_VERSION="3.0.1"
VKD3D_PROTON_SHA256="3cf2315522af5e43605ef6d3c41dad91387040bf97199934f3f7ab76caaa2f0c"
