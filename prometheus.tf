resource "proxmox_virtual_environment_container" "prometheus" {
  node_name     = "node1"
  vm_id         = 104
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "prometheus"

    ip_config {
      ipv4 {
        address = "192.168.0.225/24"
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
