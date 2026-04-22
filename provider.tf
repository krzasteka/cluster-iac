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
