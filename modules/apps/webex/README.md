# Webex

Cisco Webex collaboration client for messaging, meetings and calls.

## Build

Downloads Cisco's official RPM through a version and SHA-256 pin, then
installs it with `dnf5`, which resolves its runtime dependencies. Cisco only
offers a moving latest-package URL, so updating Webex requires deliberately
updating the pinned version and checksum in `module.kdl`.

## Runtime

Launch Webex from the application menu and sign in with the appropriate
account.
