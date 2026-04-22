---
name: proxmox-import-existing
description: "Import existing Proxmox workloads into Terraform state in this homelab repo. Use when: adding brownfield VMs/LXCs already running on Proxmox, adopting existing node resources, running terraform import, preventing recreate-on-adoption, aligning .tf config with live infra, and validating no-op plans after import. All commands run through the Docker tf-ansible service."
argument-hint: "Node name and VM/CT IDs (or list of existing resources) to import"
---

# Proxmox Brownfield Import Skill

Use this skill to adopt already-existing Proxmox resources into Terraform without recreating them.

All commands must run through the `tf-ansible` Docker service.

## Scope

Primary targets in this repo:

- Existing LXC containers (`proxmox_virtual_environment_container`)
- Existing VMs (`proxmox_virtual_environment_vm`)

Provider import IDs use this format:

- Container: `<node_name>/<vm_id>`
- VM: `<node_name>/<vm_id>`

## Non-Negotiable Rules

1. Never run `terraform apply` while importing brownfield resources.
2. Define Terraform resource blocks before import, then import, then converge fields.
3. Always generate and review a plan after import; target is a no-op or intentional minimal changes.
4. Run `terraform fmt` and `terraform validate` before planning.
5. Keep import operations one resource at a time unless explicitly asked to batch.

## Safe Import Workflow

### 1) Inventory what exists in Proxmox

Collect the exact `node_name` and `vm_id` for each existing VM/LXC to adopt.

Example inventory table to build first:

| Kind | Proxmox Name | node_name | vm_id | Terraform address |
|------|--------------|-----------|-------|-------------------|
| LXC  | redis        | node1     | 231   | proxmox_virtual_environment_container.redis |
| VM   | app-vm       | node1     | 4321  | proxmox_virtual_environment_vm.app_vm |

### 2) Create Terraform resource stubs

Create or update `.tf` files with the resource blocks and stable names first.

Important:

- Use an explicit resource name that will not change.
- Set `node_name` and `vm_id` to the existing object values.
- Include only essential fields initially if full config is unknown.

Minimal LXC stub:

```hcl
resource "proxmox_virtual_environment_container" "redis" {
  node_name = "node1"
  vm_id     = 231

  initialization {
    hostname = "redis"
  }

  operating_system {
    type             = "debian"
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  }
}
```

Minimal VM stub:

```hcl
resource "proxmox_virtual_environment_vm" "app_vm" {
  node_name = "node1"
  vm_id     = 4321
  name      = "app-vm"
}
```

### 3) Initialize/validate before import

```bash
docker compose run --rm tf-ansible terraform init
docker compose run --rm tf-ansible terraform fmt
docker compose run --rm tf-ansible terraform validate
```

### 4) Import one resource

LXC import:

```bash
docker compose run --rm tf-ansible terraform import \
  proxmox_virtual_environment_container.redis \
  node1/231
```

VM import:

```bash
docker compose run --rm tf-ansible terraform import \
  proxmox_virtual_environment_vm.app_vm \
  node1/4321
```

### 5) Inspect imported state

```bash
docker compose run --rm tf-ansible terraform state list
docker compose run --rm tf-ansible terraform state show proxmox_virtual_environment_container.redis
```

### 6) Converge config to reduce drift

Add/update arguments in `.tf` so plan output is stable and intentional:

- network interfaces
- cpu/memory
- disk settings
- startup/start_on_boot
- tags
- lifecycle ignore rules only when justified

### 7) Plan-only verification

```bash
docker compose run --rm tf-ansible terraform plan -out=tfplan
```

Expected result after adoption:

- Either `No changes` or only explicitly intended updates.
- If unexpected replacement appears, stop and adjust `.tf` to match reality.

Do not apply unless the user explicitly asks.

## Troubleshooting

### Error: resource already managed

State already has that Terraform address.

Use:

```bash
docker compose run --rm tf-ansible terraform state list
```

Then either choose a different Terraform address or remove old state mapping only if user approved:

```bash
docker compose run --rm tf-ansible terraform state rm <address>
```

### Error: cannot find resource during import

Check for wrong `node_name` or `vm_id`, or wrong kind (VM vs LXC).

### Plan wants to recreate imported resource

Usually caused by mismatched required fields.

Fix by making configuration match live object (especially `node_name`, `vm_id`, network/disk/OS fields), then re-run plan.

## Guardrails for AI Agents

1. Prefer one import per commit-sized change.
2. Keep commit messages explicit, e.g. `import existing redis LXC (node1/231) into Terraform state`.
3. Never destroy/recreate as a shortcut for adoption.
4. If drift is large, import first, then perform a separate, reviewed reconciliation PR/change.

## References

- `provider.tf` for provider version and auth pattern
- `redis.tf` as existing LXC style reference
- Terraform Registry: bpg/proxmox `virtual_environment_container` and `virtual_environment_vm` import docs