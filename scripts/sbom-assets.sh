#!/usr/bin/env bash
# The pinned payloads a target's image carries, as SPDX packages ready to
# merge into the SBOM syft produces.
#
# syft catalogues the RPM database, which is the bulk of the image but not
# all of it: a Wine build, a DXVK tarball, a prebuilt binary and a .NET
# installer are fetched from upstream and unpacked, so no package manager
# knows they are there. They are declared, though, and every `asset` block
# already carries what an SBOM entry needs — a name, a version, a download
# location and a SHA256 — so the supplement is generated from the same
# blocks the build fetches from rather than maintained beside them.
#
# Only assets with a URL. A pin with none is a git ref the module clones,
# which has no download location to record and is not a payload this
# document could point at.
set -euo pipefail
cd "$(dirname "$0")/.."

target="${1:?usage: sbom-assets.sh <target>}"

# No purl. It would make these matchable by a vulnerability scanner, but
# the pinned value is not always the upstream tag (extractVersion strips a
# prefix from several), so the identifier would be subtly wrong for some
# assets and nothing here could tell which. A name, a version and a
# verified hash are facts; a purl would be a guess.
./scripts/manifest.sh assets "$target" | jq -Rs '
    [ split("\n")[]
      | select(length > 0)
      | split("\t")
      | { module: .[0], name: .[1], version: .[3], sha256: .[4], url: .[6] }
      | select(.url != "")
      # SPDX ids allow letters, digits, "." and "-" only, so the module
      # path is flattened. The module is part of the id because two modules
      # may reasonably pin an asset under the same name.
      | . + { id: ("SPDXRef-Package-asset-"
                   + (.module | gsub("/"; "-")) + "-" + .name) }
    ] as $assets
    | {
        packages: [ $assets[]
          | {
              SPDXID: .id,
              name: .name,
              downloadLocation: .url,
              # No file entries of our own: what this records is that the
              # image carries these exact bytes, not what is inside them.
              filesAnalyzed: false,
              checksums: [ { algorithm: "SHA256", checksumValue: .sha256 } ],
              licenseConcluded: "NOASSERTION",
              licenseDeclared: "NOASSERTION",
              copyrightText: "NOASSERTION",
              supplier: "NOASSERTION",
              comment: ("Pinned build input, declared by the " + .module + " module")
            }
            # Left out rather than NOASSERTION for an asset behind a
            # permalink, which has no version to pin.
            + (if .version == "" then {} else { versionInfo: .version } end)
        ],
        relationships: [ $assets[]
          | {
              spdxElementId: "SPDXRef-DOCUMENT",
              relationshipType: "DESCRIBES",
              relatedSpdxElement: .id
            }
        ]
      }
'
