resource "terraform_data" "node1_backup_host_setup" {
  triggers_replace = [
    var.node1_ip,
    var.node1_ssh_user,
    var.backup_exports_cidr,
  ]

  connection {
    type        = "ssh"
    host        = var.node1_ip
    user        = var.node1_ssh_user
    private_key = file(var.provisioning_private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "zpool list -H backup_pool >/dev/null 2>&1 || zpool create -f backup_pool mirror ${var.backup_pool_mirror_device_a} ${var.backup_pool_mirror_device_b}",
      "zfs list -H backup_pool/proxmox_backups >/dev/null 2>&1 || zfs create backup_pool/proxmox_backups",
      "zfs list -H backup_pool/documents >/dev/null 2>&1 || zfs create backup_pool/documents",
      "zfs list -H backup_pool/media >/dev/null 2>&1 || zfs create backup_pool/media",
      "chown -R root:root /backup_pool",
      "chmod -R 775 /backup_pool",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server",
      "mkdir -p /etc/exports.d",
      "cat <<'EOF' >/etc/exports.d/backup_pool.exports",
      "/backup_pool/proxmox_backups ${var.backup_exports_cidr}(rw,sync,no_subtree_check,no_root_squash)",
      "/backup_pool/documents ${var.backup_exports_cidr}(rw,sync,no_subtree_check,no_root_squash)",
      "/backup_pool/media ${var.backup_exports_cidr}(rw,sync,no_subtree_check,no_root_squash)",
      "EOF",
      "exportfs -ra",
    ]
  }
}

resource "proxmox_storage_nfs" "backups" {
  id      = "Backups"
  server  = var.node1_ip
  export  = "/backup_pool/proxmox_backups"
  content = ["backup"]

  depends_on = [
    terraform_data.node1_backup_host_setup,
    proxmox_acl.terraform_root,
  ]
}

resource "proxmox_virtual_environment_container" "samba" {
  node_name     = "node1"
  vm_id         = var.samba_container_vm_id
  unprivileged  = false
  start_on_boot = true

  initialization {
    hostname = "samba"

    ip_config {
      ipv4 {
        address = var.samba_container_ipv4_cidr
        gateway = "192.168.0.1"
      }
    }

    user_account {
      keys = var.authorized_ssh_keys
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  operating_system {
    type             = "debian"
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  network_interface {
    name = "eth0"
  }

  wait_for_ip {
    ipv4 = true
  }

  depends_on = [terraform_data.node1_backup_host_setup]
}

resource "terraform_data" "samba_bind_mounts" {
  triggers_replace = [
    proxmox_virtual_environment_container.samba.id,
    "/backup_pool/documents:/mnt/documents",
    "/backup_pool/media:/mnt/media",
  ]

  connection {
    type        = "ssh"
    host        = var.node1_ip
    user        = var.node1_ssh_user
    private_key = file(var.provisioning_private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "pct stop ${var.samba_container_vm_id} >/dev/null 2>&1 || true",
      "pct set ${var.samba_container_vm_id} -mp0 /backup_pool/documents,mp=/mnt/documents",
      "pct set ${var.samba_container_vm_id} -mp1 /backup_pool/media,mp=/mnt/media",
      "pct start ${var.samba_container_vm_id}",
    ]
  }

  depends_on = [proxmox_virtual_environment_container.samba]
}

resource "terraform_data" "samba_container_provisioning" {
  triggers_replace = [
    proxmox_virtual_environment_container.samba.id,
    var.samba_root_password,
  ]

  connection {
    type        = "ssh"
    host        = split("/", var.samba_container_ipv4_cidr)[0]
    user        = "root"
    private_key = file(var.provisioning_private_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y samba",
      "grep -q 'BEGIN TERRAFORM SHARES' /etc/samba/smb.conf || cat <<'EOF' >> /etc/samba/smb.conf",
      "# BEGIN TERRAFORM SHARES",
      "[Documents]",
      "  path = /mnt/documents",
      "  browseable = yes",
      "  read only = no",
      "  guest ok = no",
      "  create mask = 0775",
      "  directory mask = 0775",
      "[Media]",
      "  path = /mnt/media",
      "  browseable = yes",
      "  read only = no",
      "  guest ok = no",
      "  create mask = 0775",
      "  directory mask = 0775",
      "# END TERRAFORM SHARES",
      "EOF",
      "SMB_PASS=$(printf '%s' '${base64encode(var.samba_root_password)}' | base64 -d)",
      "printf '%s\\n%s\\n' \"$SMB_PASS\" \"$SMB_PASS\" | smbpasswd -s -a root",
      "unset SMB_PASS",
      "systemctl restart smbd nmbd",
    ]
  }

  depends_on = [terraform_data.samba_bind_mounts]
}