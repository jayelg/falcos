#!/bin/bash
# Required greenboot check: fails the boot if KDE's display manager isn't
# running. Retries for a few seconds — greenboot-healthcheck.service has no
# ordering dependency against plasmalogin.service and can otherwise check
# it mid-transition, right as it's becoming active, and fail a genuinely
# healthy boot (observed in practice: consistent false-positive failures
# with plasmalogin.service starting and stopping within the same second
# greenboot's check ran).
for _ in $(seq 1 10); do
    systemctl is-active --quiet plasmalogin.service && exit 0
    sleep 1
done
exit 1
