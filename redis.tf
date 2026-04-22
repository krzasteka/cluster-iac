resource "proxmox_virtual_environment_container" "redis" {
  node_name    = "node1"
  vm_id        = 103
  hostname     = "redis"
  description  = "Managed by Terraform"
  tags         = ["community-script", "database"]

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.0.231/24"
        gateway = "192.168.0.1"      
      }
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
  }

  network_interface {
    name = "eth0"
  }
}
