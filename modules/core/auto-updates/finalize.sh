# Finalize-stage hook (sourced by 99-finalize.sh after systemctl is
# restored). Needs the real systemctl, so it can't run in this module's
# own build layer.

# Fedora countme telemetry, off for this image. Only the timer is masked so
# `rpm-ostree countme` still works manually. The timer elapses during sleep
# and fires on resume before the network is up, leaving a failed unit; if
# unmasked, the rpm-ostree-countme.service.d drop-in (this module's
# files/ overlay) adds retries for that.
systemctl mask rpm-ostree-countme.timer
