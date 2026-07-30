#!/bin/bash
# Kernel-agnostic helper, sourced wherever the running kernel version is
# needed. The kernel variant, its COPR and its package names live in the
# kernel module, at /usr/lib/falcos/kernel-devel-helpers.sh.

# Prints the running kernel version by asking rpm about the package
# recorded in the contract file the kernel module writes. Falls back to
# kernel-core when no kernel module has run yet.
kver() {
    local pkg
    pkg="$(cat /usr/lib/falcos/kernel-package 2>/dev/null || echo 'kernel-core')"
    rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$pkg"
}
