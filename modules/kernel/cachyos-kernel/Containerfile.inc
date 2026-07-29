# Declares the cachyos kernel variant, overriding Containerfile.template's
# default ARG KERNEL=stock. This line is the target of the kernel-freshness
# workflow fallback/restore seds (stock <-> cachyos).
ARG KERNEL=cachyos
# Extra needs over the standard module block: the optional MOK signing
# secret. The Secure Boot cert ships in this module's files/ overlay,
# reachable via the module dir bind below.
RUN --mount=type=bind,from=ctx,source=/modules/kernel/cachyos-kernel,target=/ctx/modules/kernel/cachyos-kernel \
    --mount=type=bind,from=ctx,source=/lib,target=/ctx/lib \
    --mount=type=cache,target=/var/cache \
    --mount=type=cache,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    --mount=type=secret,id=mok_privkey,target=/run/secrets/mok_privkey,required=false \
    KERNEL=${KERNEL} bash /ctx/lib/run-module.sh /ctx/modules/kernel/cachyos-kernel
