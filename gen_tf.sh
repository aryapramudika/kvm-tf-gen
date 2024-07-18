#!/bin/bash

# Default values
VM_COUNT=3
VM_BASE_NAME="vm"
CLOUD_IMAGE="/var/lib/libvirt/images/ubuntu-22.04-minimal-cloudimg-amd64.img"
STORAGE_POOL_NAME="data"
DISK_SIZE=20
STATIC_IPS=("192.168.122.101" "192.168.122.102" "192.168.122.103")
NETWORK_NAME="default"
CPU_COUNT=1
MEMORY_SIZE=1024  # in MB
SSH_KEY=""
SSH_CONFIG_PATH="./ssh-config"

# Function to display help
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -c COUNT       Number of VMs to create (default: 3)"
    echo "  -b BASE_NAME   Base name for VMs (default: testvm)"
    echo "  -i IMAGE       Path to the cloud image (default: /var/lib/libvirt/images/ubuntu-22.04-minimal-cloudimg-amd64.img)"
    echo "  -p POOL        Storage pool name (default: data)"
    echo "  -d SIZE        Disk size in gigabytes (default: 20)"
    echo "  -s IPS         Comma-separated list of static IP addresses (default: 192.168.122.101,192.168.122.102,192.168.122.103)"
    echo "  -n NETWORK     Network name (default: default)"
    echo "  -u CPU_COUNT   Number of CPUs (default: 1)"
    echo "  -m MEMORY      Memory size in MB (default: 1024)"
    echo "  -k SSH_KEY     SSH public key"
    echo "  -h, --help     Display this help message"
    echo
    exit 0
}

# Customizable input parameters
while getopts c:b:i:p:d:s:n:u:m:k:f:h-: flag
do
    case "${flag}" in
        c) VM_COUNT=${OPTARG};;
        b) VM_BASE_NAME=${OPTARG};;
        i) CLOUD_IMAGE=${OPTARG};;
        p) STORAGE_POOL_NAME=${OPTARG};;
        d) DISK_SIZE=${OPTARG};;
        s) IFS=',' read -r -a STATIC_IPS <<< "${OPTARG}";;
        n) NETWORK_NAME=${OPTARG};;
        u) CPU_COUNT=${OPTARG};;
        m) MEMORY_SIZE=${OPTARG};;
        k) SSH_KEY=${OPTARG};;
        f) SSH_CONFIG_PATH=${OPTARG};;
        h) display_help;;
        -)
            case "${OPTARG}" in
                help) display_help;;
                *) echo "Invalid option --${OPTARG}" >&2; exit 1;;
            esac;;
        *) display_help;;
    esac
done

# Validate SSH key
if [ -z "$SSH_KEY" ]; then
    echo "Error: SSH key must be provided with the -k option."
    exit 1
fi

# Generate main.tf
cat <<EOF > main.tf
terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "vm_count" {
  description = "Number of VMs to create"
  default     = ${VM_COUNT}
}

variable "vm_base_name" {
  description = "Base name for VMs"
  default     = "${VM_BASE_NAME}"
}

variable "cloud_image" {
  description = "Path to the cloud image"
  default     = "${CLOUD_IMAGE}"
}

variable "storage_pool_name" {
  description = "Storage pool name"
  default     = "${STORAGE_POOL_NAME}"
}

variable "static_ips" {
  description = "List of static IP addresses"
  type        = list(string)
  default     = [$(printf '"%s",' "${STATIC_IPS[@]}")]
}

variable "disk_size" {
  description = "Size of the VM disk in gigabytes"
  default     = ${DISK_SIZE}
}

variable "network_name" {
  description = "Name of the network"
  default     = "${NETWORK_NAME}"
}

variable "cpu_count" {
  description = "Number of CPUs for the VM"
  default     = ${CPU_COUNT}
}

variable "memory_size" {
  description = "Memory size for the VM in MB"
  default     = ${MEMORY_SIZE}
}

resource "libvirt_volume" "cloud_image" {
  name   = "cloud-image"
  pool   = var.storage_pool_name
  source = var.cloud_image
  format = "raw"
}

resource "libvirt_volume" "vm_disk" {
  count  = var.vm_count
  name   = "\${var.vm_base_name}-\${count.index}.qcow2"
  base_volume_id = libvirt_volume.cloud_image.id
  pool   = var.storage_pool_name
  format = "qcow2"
  size   = var.disk_size * 1024 * 1024 * 1024  # Size in bytes
}

resource "libvirt_cloudinit_disk" "commoninit" {
  count   = var.vm_count
  name    = "\${var.vm_base_name}-\${count.index}-cloudinit.iso"
  pool    = var.storage_pool_name
  user_data      = data.template_file.user_data[count.index].rendered
  network_config = data.template_file.network_config[count.index].rendered
}

data "template_file" "user_data" {
  count    = var.vm_count
  template = file("\${path.module}/cloud-init/user_data.yaml")
  vars = {
    hostname = "\${var.vm_base_name}-\${count.index}"
  }
}

data "template_file" "network_config" {
  count    = var.vm_count
  template = file("\${path.module}/cloud-init/network_config.yaml")
  vars = {
    ip_address = var.static_ips[count.index]
  }
}

resource "libvirt_domain" "vm" {
  count = var.vm_count
  name  = "\${var.vm_base_name}-\${count.index}"
  memory = var.memory_size
  vcpu   = var.cpu_count

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  network_interface {
    network_name = var.network_name
  }

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
EOF

# Generate cloud-init user_data.yaml
mkdir -p cloud-init

cat <<EOF > cloud-init/user_data.yaml
#cloud-config
hostname: \${hostname}
users:
  - default
  - name: user
    ssh-authorized-keys:
      - ${SSH_KEY}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
chpasswd:
  list: |
    user:$(openssl rand -base64 12)
  expire: false
ssh_pwauth: true
EOF

# Generate cloud-init network_config.yaml
cat <<EOF > cloud-init/network_config.yaml
version: 2
ethernets:
  ens3:
    addresses:
      - \${ip_address}/24
    gateway4: 192.168.122.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
EOF

# Generate SSH config file
cat <<EOF > ${SSH_CONFIG_PATH}
Host ${VM_BASE_NAME}-*
  User user
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
EOF

for i in $(seq 0 $((${VM_COUNT}-1)))
do
    echo "Host ${VM_BASE_NAME}-${i}" >> ${SSH_CONFIG_PATH}
    echo "  HostName ${STATIC_IPS[$i]}" >> ${SSH_CONFIG_PATH}
done

echo "Terraform, cloud-init files, and SSH config have been generated."
echo "Use the SSH config file with: ssh -F ${SSH_CONFIG_PATH} <hostname>"
