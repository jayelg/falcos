#!/bin/bash
# Helpers for module `repo` files. Standalone so RUN layers can mount just
# this file.

# <repofile-url> — install a third-party .repo but leave it DISABLED, so
# nothing in the image resolves packages from it unless a module opts in
# per-install with `dnf5 install --enablerepo='<id>' ...`. Uses $REPO_ID (the
# id run-module.sh keys its idempotency check on, == the repo's section id)
# as the repo to disable.
add_disabled_repo() {
    dnf5 config-manager addrepo --from-repofile="$1"
    dnf5 config-manager setopt "${REPO_ID:?add_disabled_repo needs REPO_ID set}.enabled=0"
}
