### wolf: the streaming server quadlet and its host udev rules.
#
# The quadlet is files/ content and the driver tree is the nvidia
# module's job; the one install here is the pinned udev rules, without
# which Wolf cannot open /dev/uinput and /dev/uhid to create the virtual
# gamepads, and its virtual controllers leak onto the host's active seat.

source /ctx/lib/fetch-helpers.sh

fetch_verified "$ASSET_UDEV_RULES_URL" "$ASSET_UDEV_RULES_SHA256" /tmp/85-wolf.rules
install -Dm644 /tmp/85-wolf.rules /etc/udev/rules.d/85-wolf.rules
rm -f /tmp/85-wolf.rules
