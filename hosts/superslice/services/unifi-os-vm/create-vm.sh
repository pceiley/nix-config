#!/usr/bin/env bash
#
# Provisions the "halloumi" guest VM for UniFi OS Server on superslice.
#
# Run this on superslice itself, as pceiley (a member of the libvirtd group),
# after `rebuild-host` has applied hosts/superslice/services/virtualisation.nix.
#
# Usage:
#   ./create-vm.sh
#
# Re-run is safe-ish: it will refuse to overwrite an existing disk/VM of the
# same name. Tear down first with:
#   sudo virsh destroy halloumi; sudo virsh undefine halloumi --remove-all-storage --nvram

set -euo pipefail

VM_NAME="halloumi"
VM_DIR="/var/lib/libvirt/images"
VM_DISK="${VM_DIR}/${VM_NAME}.qcow2"
SEED_ISO="${VM_DIR}/${VM_NAME}-seed.iso"

VCPUS=4
RAM_MB=8192
DISK_GB=60

# Base cloud image. Ubuntu 26.04 LTS ("Resolute Raccoon", released Apr 2026)
# meets the Ubuntu 23.04+ / podman 4.3.1+ requirement comfortably.
IMG_URL="https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
BASE_IMG="${VM_DIR}/ubuntu-26.04-server-cloudimg-amd64.img"

# --- Alternatives -----------------------------------------------------
# Debian 13 ("Trixie") - smallest option, ships podman 5.4 with no extra
# repo needed (Debian 12's repo podman is too old for UniFi OS Server):
# IMG_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
# BASE_IMG="${VM_DIR}/debian-13-genericcloud-amd64.qcow2"
#
# Ubuntu 24.04 LTS ("Noble") - matches most published install guides
# step-by-step:
# IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
# BASE_IMG="${VM_DIR}/ubuntu-24.04-server-cloudimg-amd64.img"
# -----------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -e "${VM_DISK}" ]]; then
  echo "Refusing to continue: ${VM_DISK} already exists." >&2
  exit 1
fi

echo "==> Ensuring image directory exists"
sudo mkdir -p "${VM_DIR}"

echo "==> Downloading base cloud image (if needed)"
if [[ ! -e "${BASE_IMG}" ]]; then
  sudo curl -fL "${IMG_URL}" -o "${BASE_IMG}"
fi

echo "==> Creating ${DISK_GB}G disk from base cloud image"
# Make a full, standalone copy of the base image rather than a qcow2 overlay
# with a backing file. An overlay would leave the VM permanently dependent on
# ${BASE_IMG} - deleting or replacing that image later would corrupt the VM.
sudo qemu-img convert -f qcow2 -O qcow2 "${BASE_IMG}" "${VM_DISK}"
sudo qemu-img resize "${VM_DISK}" "${DISK_GB}G"

echo "==> Building cloud-init seed ISO"
SEED_DIR=$(mktemp -d)
cp "${SCRIPT_DIR}/user-data.yaml" "${SEED_DIR}/user-data"
cp "${SCRIPT_DIR}/meta-data.yaml" "${SEED_DIR}/meta-data"
cp "${SCRIPT_DIR}/network-config.yaml" "${SEED_DIR}/network-config"
sudo xorriso -as mkisofs \
  -o "${SEED_ISO}" \
  -V cidata \
  -J -r \
  "${SEED_DIR}"
rm -rf "${SEED_DIR}"

echo "==> Defining and starting VM '${VM_NAME}'"
sudo virt-install \
  --name "${VM_NAME}" \
  --vcpus "${VCPUS}" \
  --memory "${RAM_MB}" \
  --cpu host-passthrough \
  --osinfo detect=on,require=off \
  --disk path="${VM_DISK}",format=qcow2,bus=virtio \
  --disk path="${SEED_ISO}",device=cdrom,bus=sata \
  --network bridge=br0,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --boot uefi \
  --import \
  --noautoconsole

echo
echo "==> Done. VM '${VM_NAME}' is starting up on br0 with static IP 192.168.5.6."
echo "    (cloud-init runs apt update/upgrade on first boot - give it a few minutes)"
echo
echo "    ssh pceiley@192.168.5.6"
echo "    and follow the UniFi OS Server install steps in /etc/motd"
