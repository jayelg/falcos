# gaming:latest

Gaming performance: gamemode + xone Xbox Wireless Adapter driver.

**Asset pins** in `module.kdl`:
- `xone`: a commit on medusalix/xone, which has no releases. Cloned and checked out, so the commit is its own integrity.

**Requires:** `--mount=type=secret,id=mok_privkey` for DKMS module signing. Must run after `cachyos-kernel` so the DKMS build targets the correct kernel.
