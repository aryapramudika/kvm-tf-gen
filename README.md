#  Bash Script to generate Terraform and Cloud-Init Automation Script

This repository contains a bash script `gen_tf.sh` to automate the generation of Terraform configuration files and cloud-init configuration files for provisioning multiple VMs with customized settings using libvirt.

Terraform provider used:

[Teraform-Provider-Libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)

## Features

- Create multiple VMs with customized configurations.
- Customize VM base name, cloud image path, storage pool, disk size, static IP addresses, network name, CPU count, memory size, and SSH key.
- Automatically generates an SSH configuration file for easy SSH access to the VMs.

## Usage

### Prerequisites

- Ensure you have `Terraform` and `libvirt` installed and configured on your system.
- Ensure you have `bash` and `openssl` installed.

### Running the Script

1. Clone the repository and navigate to the directory:

    ```bash
    git clone https://github.com/aryapramudika/kvm-tf-gen.git
    cd kvm-tf-gen
    ```

2. Make the script executable:

    ```bash
    chmod +x gen_tf.sh
    ```

3. Run the script with customizable parameters:

    ```bash
    ./gen_tf.sh [options]
    ```
    
   or

   You can edit directly on the script or using input arguments

    ```bash
    vim gen_tf.sh
    ./gen_tf.sh -k "SSH public key (required)"
    ```

### Options

- `-c COUNT`: Number of VMs to create (default: 3)
- `-b BASE_NAME`: Base name for VMs (default: `testvm`)
- `-i IMAGE`: Path to the cloud image (default: `/var/lib/libvirt/images/ubuntu-22.04-minimal-cloudimg-amd64.img`)
- `-p POOL`: Storage pool name (default: `data`)
- `-d SIZE`: Disk size in gigabytes (default: 20)
- `-s IPS`: Comma-separated list of static IP addresses (default: `192.168.122.101,192.168.122.102,192.168.122.103`)
- `-n NETWORK`: Network name (default: `default`)
- `-u CPU_COUNT`: Number of CPUs (default: 1)
- `-m MEMORY`: Memory size in MB (default: 1024)
- `-k SSH_KEY`: SSH public key (required)
- `-f SSH_CONFIG_PATH`: Path for the SSH configuration file (default: `./ssh-config`)
- `-h, --help`: Display the help message

### Example

```bash
./gen_tf.sh -c 5 -b myvm -i /path/to/cloud-image.img -p mypool -d 50 -s "192.168.122.201,192.168.122.202,192.168.122.203,192.168.122.204,192.168.122.205" -n custom_network -u 2 -m 2048 -k "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEArF4..." -f /custom/path/ssh-config
```

### Run Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### SSH Access
The script generates an SSH configuration file to simplify SSH access to the VMs. The default path for this file is ./ssh-config, but you can specify a custom path using the -f option.

```bash
ssh -F $(PWD)/ssh-config myvm-0
```

To use the SSH configuration file:

```bash
ssh -F /custom/path/ssh-config myvm-0
```

#### Files Generated
* main.tf: Terraform configuration file.
* cloud-init/user_data.yaml: Cloud-init user data file.
* cloud-init/network_config.yaml: Cloud-init network configuration file.
* ssh-config: SSH configuration file (path can be customized).
