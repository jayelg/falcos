### nvidia-container-toolkit: the CDI bridge from the host driver to containers.
#
# Installs the toolkit alone. The CDI spec it generates is NOT built here:
# it names the driver's exact library filenames, so a spec baked into the
# image pins the build host's driver and goes stale on the first driver
# update, breaking every `--device nvidia.com/gpu=all` with a stat of a
# library version that no longer exists. Instead a boot service
# (nvidia-cdi.service, shipped in files/) regenerates it against the live
# driver, which is the only version that is ever correct at runtime.

# dnf5 in a build layer has no one to answer a key prompt. The repo is
# gpgcheck=0 / repo_gpgcheck=1, so the signing key is what the metadata
# check needs; import it directly as the nvidia module does for the CUDA
# repo key.
rpm --import https://nvidia.github.io/libnvidia-container/gpgkey

dnf5 install -y --enablerepo="nvidia-container-toolkit" nvidia-container-toolkit
