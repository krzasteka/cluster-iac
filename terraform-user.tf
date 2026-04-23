# =============================================================================
# terraform-user.tf — Proxmox role, ACL, and API token for Terraform
#
# The terraform@pve user was created manually and cannot be managed by the
# token itself (bootstrapping constraint). The role, ACL, and token are
# managed here.
#
# One-time imports to adopt existing resources into state:
#
#   docker compose run --rm tf-ansible terraform import \
#     proxmox_virtual_environment_role.terraform_role "TerraformRole"
#
#   docker compose run --rm tf-ansible terraform import \
#     proxmox_acl.terraform_root "terraform@pve!//"
#
#   docker compose run --rm tf-ansible terraform import \
#     proxmox_user_token.terraform_provider "terraform@pve!provider"
# =============================================================================

resource "proxmox_virtual_environment_role" "terraform_role" {
  role_id = "TerraformRole"

  privileges = [
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Audit",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Cloudinit",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.PowerMgmt",
    "SDN.Use",
  ]
}

# Grant TerraformRole at root path with propagation so it covers all nodes,
# storage, and containers without needing per-CT ACL entries.
resource "proxmox_acl" "terraform_root" {
  path      = "/"
  propagate = true
  role_id   = proxmox_virtual_environment_role.terraform_role.role_id
  user_id   = "terraform@pve"
}

# The API token (terraform@pve!provider) was generated manually in the
# Proxmox UI and its secret is stored in .env as PROXMOX_VE_API_TOKEN.
# The token cannot be managed here because the token itself lacks permission
# to read its own metadata (Proxmox bootstrapping constraint).
