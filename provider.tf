terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.103.0"
    }
  }
}

provider "proxmox" {
  random_vm_ids = true
  insecure      = true
  ssh {
    agent    = true
    username = "terraform"
  }
}

# Use this alias only for operations that Proxmox restricts to root@pam
# (for example, LXC bind mounts).
provider "proxmox" {
  alias         = "root"
  random_vm_ids = true
  insecure      = true
  username      = var.proxmox_root_username
  api_token     = var.proxmox_root_api_token
}
