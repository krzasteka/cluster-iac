resource "proxmox_virtual_environment_container" "ops_controller" {
  node_name     = "node1"
  vm_id         = 900
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "ops-controller"

    ip_config {
      ipv4 {
        address = "192.168.0.230/24"
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
