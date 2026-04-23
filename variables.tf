variable "authorized_ssh_keys" {
  description = "SSH public keys injected into container root accounts during initialization."
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "proxmox_root_username" {
  description = "Root Proxmox username for operations restricted to root@pam."
  type        = string
  default     = "root@pam"
}

variable "proxmox_root_api_token" {
  description = "API token for proxmox_root_username (pass via TF_VAR_proxmox_root_api_token)."
  type        = string
  default     = null
  sensitive   = true
}

variable "node1_ip" {
  description = "Management IP used for SSH provisioning and NFS storage registration on node1."
  type        = string
  default     = "192.168.0.201"
}

variable "node1_ssh_user" {
  description = "SSH user on node1 for host-level provisioning commands."
  type        = string
  default     = "root"
}

variable "provisioning_private_key_file" {
  description = "Private key file path inside the tf-ansible container used by remote-exec SSH connections."
  type        = string
  default     = "/root/.ssh/id_ed25519"
}

variable "backup_pool_mirror_device_a" {
  description = "First disk device used for the backup_pool ZFS mirror on node1."
  type        = string
  default     = "/dev/sda"
}

variable "backup_pool_mirror_device_b" {
  description = "Second disk device used for the backup_pool ZFS mirror on node1."
  type        = string
  default     = "/dev/sdb"
}

variable "backup_exports_cidr" {
  description = "Client CIDR allowed to mount backup_pool NFS exports."
  type        = string
  default     = "192.168.0.0/24"
}

variable "samba_container_vm_id" {
  description = "VMID assigned to the Samba LXC."
  type        = number
  default     = 114
}

variable "samba_container_ipv4_cidr" {
  description = "IPv4 address with CIDR prefix for the Samba LXC."
  type        = string
  default     = "192.168.0.210/24"
}

variable "samba_root_password" {
  description = "Password set for Samba user root inside the Samba LXC."
  type        = string
  sensitive   = true
}
