# Extra needs over the standard module block: desktop-flavor gating
# (run-module.sh skips it elsewhere), the optional MOK secret and the
# KERNEL arg for the kvmfr DKMS build.
RUN --mount=type=bind,from=ctx,source=/modules/virtualization/looking-glass,target=/ctx/modules/virtualization/looking-glass \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    FLAVOR_GATE=desktop FLAVOR=${FLAVOR} KERNEL=${KERNEL} bash /ctx/lib/run-module.sh /ctx/modules/virtualization/looking-glass
