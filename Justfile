export image_name := env("IMAGE_NAME", "falcos") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    just --unstable --fmt -f Justfile

# Generate Containerfile.generated from the Containerfile skeleton +
# components.list. Runs automatically as a dependency of `build`.
[group('Utility')]
generate:
    ./scripts/gen-containerfile.sh

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    rm -rf _build* output/ Containerfile.generated

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Build the image using Podman, e.g. `just build falcos latest desktop stock`.
# Depends on `generate` so the Containerfile always matches components.list.
build $target_image=image_name $tag=default_tag $flavor=`grep -oP '^ARG FLAVORS="\K[^,"]+' Containerfile.base | head -1` $kernel="cachyos": generate
    #!/usr/bin/env bash
    set -euo pipefail

    # Local buildah keys the RUN cache on the whole ctx stage, so any
    # change to build-phases/, lib/, or components/ rebuilds every layer.
    # Correct, just coarser than CI's BuildKit which scopes invalidation
    # to the mounted files.

    # Optional Secure Boot signing key; see `just generate-mok-key`.
    SECRET_ARGS=()
    if [[ -n "${MOK_KEY_PATH:-}" && -f "${MOK_KEY_PATH}" ]]; then
        SECRET_ARGS+=("--secret" "id=mok_privkey,src=${MOK_KEY_PATH}")
    fi

    podman build \
        "${SECRET_ARGS[@]}" \
        --build-arg "FLAVOR=${flavor}" \
        --build-arg "KERNEL=${kernel}" \
        --build-arg "IMAGE_VERSION=$(date -u +%Y%m%d)" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        -f Containerfile.generated \
        .

# Generate a one-time Secure Boot (MOK) module-signing key pair. Keep the
# private key out of the repo; commit the public cert.
[group('Secure Boot')]
generate-mok-key dir=(env("HOME") + "/.local/share/falcos"):
    #!/usr/bin/env bash
    set -euo pipefail

    mkdir -p "{{ dir }}"
    KEY="{{ dir }}/MOK.priv"
    CERT="{{ dir }}/sb_cert.der"

    if [[ -f "$KEY" ]]; then
        echo "A MOK key already exists at $KEY — refusing to overwrite it."
        echo "Delete it first if you really want to generate a new one (you'll need to re-enroll the new cert on every machine)."
        exit 1
    fi

    openssl req -x509 -newkey rsa:2048 \
        -keyout "$KEY" -nodes -days 36500 \
        -outform DER -out "$CERT" \
        -subj "/CN=falcos Secure Boot Module Signing/"
    chmod 600 "$KEY"

    echo
    echo "Private key: $KEY"
    echo "  export MOK_KEY_PATH=$KEY   # before 'just build', keep this out of git"
    echo "Public cert: $CERT"
    echo
    echo "Next steps:"
    echo "  1. cp $CERT components/kernel/cachyos-kernel/files/usr/share/falcos/sb_cert.der"
    echo "  2. Commit that cert, and add MOK_PRIVATE_KEY as a GitHub Actions secret (contents of $KEY)."
    echo "  3. After deploying a signed image, on the target machine run:"
    echo "       sudo mokutil --import /usr/share/falcos/sb_cert.der"
    echo "     then reboot and follow the MokManager enrollment prompt."

# Copy the image from user podman storage into rootful podman (which BIB
# needs), pulling it instead if not present locally
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Convert a container image to a bootable disk image (qcow2/raw/iso) using
# Bootc Image Builder
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Build the container image, then convert it to a bootable disk image
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtual Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtual Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtual Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtual Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtual Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtual Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtual Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtual Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtual Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtual Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the {{ type }} image" && just rebuild-{{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shellcheck on all Bash scripts, same file set as the Lint workflow
lint:
    #!/usr/bin/env bash
    set -eou pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # -s bash because the component scripts and versions files are sourced
    # fragments without shebangs
    mapfile -t scripts < <(
        find build-phases scripts lib -name '*.sh' -type f
        find components -path '*/files/*' -type f \
            \( -path '*/libexec/*' -o -path '*/system-generators/*' \)
    )
    shellcheck -s bash "${scripts[@]}"
    # Validate components.list resolves (bad names, missing dirs, markers)
    ./scripts/gen-containerfile.sh >/dev/null

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
