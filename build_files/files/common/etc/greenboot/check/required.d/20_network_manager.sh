#!/bin/bash
# Required greenboot check: fails the boot if NetworkManager isn't running.
# Retries for a few seconds for the same reason as 10_display_manager.sh —
# no ordering dependency guarantees the unit is done transitioning by the
# time greenboot's check runs.
for _ in $(seq 1 10); do
    systemctl is-active --quiet NetworkManager.service && exit 0
    sleep 1
done
exit 1
