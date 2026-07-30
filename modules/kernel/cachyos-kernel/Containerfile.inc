# Declares the cachyos kernel variant, overriding Containerfile.template's
# default ARG KERNEL=stock. This line is the target of the kernel-freshness
# workflow fallback/restore seds (stock <-> cachyos).
#
# An ARG with a default is graph shape rather than a parameter, which is
# the one thing the declared fields cannot express. Everything else this
# module needs is declared in module.kdl and lands on the generated block
# below this fragment.
ARG KERNEL=cachyos
