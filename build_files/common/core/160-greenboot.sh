### Greenboot — automatic boot health checks + rollback
# Catches boots that succeed at build time (passes `bootc container lint`)
# but fail at runtime — the class of bug a static package diff can't see.
# greenboot-default-health-checks adds DNS/update-platform/watchdog checks;
# custom required checks live in files/common/etc/greenboot/check/required.d.
dnf5 install -y greenboot greenboot-default-health-checks
