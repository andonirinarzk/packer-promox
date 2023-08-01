# Ubuntu Server
# ---
# Packer Template to create an Ubuntu Server on Proxmox

# Variable Definitions
variable "proxmox_api_url" {
    type = string
    default = env("PROXMOX_API_URL")
}

variable "proxmox_api_token_id" {
    type = string
    default = env("PROXMOX_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
    type = string
    default = env("PROXMOX_API_TOKEN_SECRET")
    sensitive = true
}

variable "runner_ip_address" {
    type = string
    default = env("RUNNER_IP_ADDRESS")
}

# Resource Definiation for the VM Template
source "proxmox-iso" "ubuntu-server-jammy" {
 
    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    # insecure_skip_tls_verify = true
    
    # VM General Settings
    node = "pve2"
    vm_name = "ubuntu-server-jammy"
    template_description = "Ubuntu Server Image"

    # VM OS Settings
    # (Option 1) Local ISO File
    iso_file = "local:iso/ubuntu-22.04.1-live-server-amd64.iso"
    # - or -
    # (Option 2) Download ISO
    # iso_url = "https://old-releases.ubuntu.com/releases/22.04/ubuntu-22.04.1-live-server-amd64.iso"
    # iso_checksum = "10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
    iso_storage_pool = "local"
    unmount_iso = true
    os = "l26"

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "qcow2"
        storage_pool = "local-lvm"
        storage_pool_type = "lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "1"
    
    # VM Memory Settings
    memory = "2048" 

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"

    # PACKER Boot Commands 
    boot_command = [
        "<esc><wait>",
        "e<wait>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><wait>",
        "autoinstall ds=nocloud-net\\;s=http://${var.runner_ip_address}:{{ .HTTPPort }}/ ---<wait>",
        "<f10><wait>"
    ]
    boot = "c"
    boot_wait = "5s"

    # PACKER Autoinstall Settings
    http_directory = "ubuntu-server-jammy" 
    # (Optional) Bind IP Address and Port
    // http_bind_address = "0.0.0.0"
    http_port_min = 8800
    http_port_max = 8810

    ssh_username = "ubuntu"

    # (Option 1) Add your Password here
    ssh_password = "PLAINTEXT_PASSWORD"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    # ssh_private_key_file = "~/.ssh/id_rsa"

    # Raise the timeout, when installation takes longer
    ssh_timeout = "20m"
}

# Build Definition to create the VM Template
build {

    name = "ubuntu-server-jammy"
    sources = ["source.proxmox-iso.ubuntu-server-jammy"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo rm -f /etc/netplan/00-installer-config.yaml",
            "sudo sync",
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "cloud-init-config/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ 
            "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"
            ]
    }

    # Add additional provisioning scripts here
    # ...
}
