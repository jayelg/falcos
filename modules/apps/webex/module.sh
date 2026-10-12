# Cisco's signed RPM is fetched through the manifest asset pin so the moving
# upstream URL cannot silently change what the image contains. dnf resolves
# the RPM's Fedora-compatible runtime dependencies while installing it.
source /ctx/lib/fetch-helpers.sh

fetch_verified "$ASSET_WEBEX_URL" "$ASSET_WEBEX_SHA256" /tmp/Webex.rpm
dnf5 install -y /tmp/Webex.rpm
rm -f /tmp/Webex.rpm
