# Declares the cachyos kernel variant. This is the only declaration of the
# KERNEL arg: the skeleton no longer carries a default, so the kernel
# module owns it entirely. This line is the target of the kernel-freshness
# workflow fallback/restore seds (cachyos <-> stock).
#
# An ARG with a default is graph shape rather than a parameter, which is
# the one thing the declared fields cannot express. Everything else this
# module needs is declared in module.kdl and lands on the generated block
# below this fragment.
ARG KERNEL=cachyos
