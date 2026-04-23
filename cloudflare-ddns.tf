resource "proxmox_virtual_environment_container" "cloudflare_ddns" {
  node_name     = "node2"
  vm_id         = 108
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "cloudflare-ddns"

    ip_config {
      ipv4 {
        address = "192.168.0.173/24"
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
