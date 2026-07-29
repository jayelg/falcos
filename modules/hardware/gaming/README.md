# gaming:latest

Gaming performance: gamemode + xone Xbox Wireless Adapter driver.

**Version pins** in `versions.sh`:
- xone: XONE_COMMIT (commit pin from medusalix/xone)

**Requires:** `--mount=type=secret,id=mok_privkey` for DKMS module signing. Must run after `cachyos-kernel` so the DKMS build targets the correct kernel.
