resource "proxmox_virtual_environment_container" "browser_use" {
  node_name     = "node1"
  vm_id         = 115
  unprivileged  = true
  start_on_boot = true

  initialization {
    hostname = "browser-use"

    ip_config {
      ipv4 {
        address = "192.168.0.233/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      keys = var.authorized_ssh_keys
    }
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 1024
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.browser_use_template_file_id
  }

  disk {
    datastore_id = "local-lvm"
    size         = 16
  }

  network_interface {
    name = "eth0"
  }

  timeout_clone  = 1800
  timeout_create = 1800
  timeout_delete = 600
  timeout_update = 1800

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
      initialization[0].user_account
    ]
  }
}

resource "terraform_data" "browser_use_passthrough" {
  triggers_replace = [
    proxmox_virtual_environment_container.browser_use.id,
    var.browser_use_host_uid,
    var.browser_use_host_user,
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
      "pct stop 115 >/dev/null 2>&1 || true",
      "grep -q '^root:${var.browser_use_host_uid}:1$' /etc/subuid || echo 'root:${var.browser_use_host_uid}:1' >> /etc/subuid",
      "grep -q '^root:${var.browser_use_host_uid}:1$' /etc/subgid || echo 'root:${var.browser_use_host_uid}:1' >> /etc/subgid",
      "CONFIG_FILE=/etc/pve/lxc/115.conf",
      "awk 'BEGIN{skip=0} /# BEGIN TERRAFORM BROWSER_USE/{skip=1; next} /# END TERRAFORM BROWSER_USE/{skip=0; next} !skip {print}' \"$CONFIG_FILE\" > \"$CONFIG_FILE.tmp\"",
      "mv \"$CONFIG_FILE.tmp\" \"$CONFIG_FILE\"",
      "cat <<'EOF' >> \"$CONFIG_FILE\"",
      "# BEGIN TERRAFORM BROWSER_USE",
      "# profile: default",
      "lxc.idmap: u 0 100000 1000",
      "lxc.idmap: g 0 100000 1000",
      "lxc.idmap: u 1000 ${var.browser_use_host_uid} 1",
      "lxc.idmap: g 1000 ${var.browser_use_host_uid} 1",
      "lxc.idmap: u 1001 101001 64535",
      "lxc.idmap: g 1001 101001 64535",
      "lxc.mount.entry: /tmp/.X11-unix/X0 tmp/.X11-unix/X0 none bind,optional,create=file",
      "lxc.mount.entry: /home/${var.browser_use_host_user}/.Xauthority home/ubuntu/.Xauthority none bind,optional,create=file",
      "lxc.cgroup2.devices.allow: c 226:* rwm",
      "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir",
      "EOF",
      "if [ -d /var/cache/apt/archives ]; then",
      "  echo '# profile: aptcache' >> \"$CONFIG_FILE\"",
      "  echo 'lxc.mount.entry: /var/cache/apt/archives var/cache/apt/archives none bind,optional,create=dir' >> \"$CONFIG_FILE\"",
      "fi",
      "echo '# END TERRAFORM BROWSER_USE' >> \"$CONFIG_FILE\"",
      "pct start 115",
    ]
  }

  depends_on = [proxmox_virtual_environment_container.browser_use]
}