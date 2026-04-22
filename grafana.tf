resource "proxmox_virtual_environment_container" "ct105" {
  node_name    = "node1"
  vm_id        = 105
  description  = <<-EOT
          <div align='center'>
            <a href='https://Helper-Scripts.com' target='_blank' rel='noopener noreferrer'>
              <img src='https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/images/logo-81x112.png' alt='Logo' style='width:81px;height:112px;'/>
            </a>

            <h2 style='font-size: 24px; margin: 20px 0;'>Grafana LXC</h2>

            <p style='margin: 16px 0;'>
              <a href='https://ko-fi.com/community_scripts' target='_blank' rel='noopener noreferrer'>
                <img src='https://img.shields.io/badge/&#x2615;-Buy us a coffee-blue' alt='spend Coffee' />
              </a>
            </p>

            <span style='margin: 0 10px;'>
              <i class="fa fa-github fa-fw" style="color: #f5f5f5;"></i>
              <a href='https://github.com/community-scripts/ProxmoxVE' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>GitHub</a>
            </span>
            <span style='margin: 0 10px;'>
              <i class="fa fa-comments fa-fw" style="color: #f5f5f5;"></i>
              <a href='https://github.com/community-scripts/ProxmoxVE/discussions' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Discussions</a>
            </span>
            <span style='margin: 0 10px;'>
              <i class="fa fa-exclamation-circle fa-fw" style="color: #f5f5f5;"></i>
              <a href='https://github.com/community-scripts/ProxmoxVE/issues' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Issues</a>
            </span>
          </div>
        EOT
  tags         = ["community-script", "monitoring", "visualization"]
  unprivileged = true

  initialization {
    hostname = "grafana"

    ip_config {
      ipv4 {
        address = "192.168.0.226/24"
        gateway = "192.168.0.1"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 512
  }

  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }

  disk {
    mount_options = []
    datastore_id  = "local-lvm"
    size          = 2
  }

  start_on_boot = true

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:47:59:55"
  }

  operating_system {
    type             = "debian"
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id
    ]
  }

  timeout_clone  = 1800
  timeout_create = 1800
  timeout_delete = 60
  timeout_update = 1800
}
