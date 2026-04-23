resource "proxmox_virtual_environment_container" "invoiceninja" {
  node_name     = "node1"
  vm_id         = 112
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "invoiceninja"

    ip_config {
      ipv4 {
        address = "192.168.0.214/24"
        gateway = "192.168.0.1"
      }
    }
    user_account {
      keys = var.authorized_ssh_keys
    }
  }

  operating_system {
    type             = "debian"
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  }

  lifecycle {
    ignore_changes = all
  }
}
