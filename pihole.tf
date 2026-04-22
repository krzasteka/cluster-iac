resource "proxmox_virtual_environment_container" "pihole" {
  node_name     = "node2"
  vm_id         = 100
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "pihole"

    ip_config {
      ipv4 {
        address = "192.168.0.202/24"
        gateway = "192.168.0.1"
      }
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
