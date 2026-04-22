---
name: proxmox-iac
description: "Provision and manage Proxmox LXC containers using Terraform and Ansible in this homelab IaC repo. Use when: adding a new LXC, deploying a new app container, applying infrastructure changes, decommissioning or deleting an LXC, running Terraform plan/apply, running Ansible playbook, cloning CT113 for a React/Vite/Tailwind app, modifying .tf files, or performing day-2 infra maintenance. All commands run through the Docker tf-ansible service."
argument-hint: "Name of new LXC/app or describe the infra change"
---

# Proxmox IaC — Homelab Infrastructure Skill

All commands run through the `tf-ansible` Docker service — never call `terraform` or `ansible` directly on the host.

## Core Rules

1. Never run `terraform apply` without a saved plan file.
2. Always run `terraform fmt` and `terraform validate` before planning.
3. Do not commit `.env`, `terraform.tfstate*`, or plan files (`tfplan`, `tfdestroy`).
4. State files are local — do not push them to Git.
5. Prefer repeatable scripts over manual steps.

## Naming Convention

| Item | Pattern | Example |
|------|---------|---------|
| Project slug | `my-app` | `spelling-game` |
| Container name / hostname | same as slug | `spelling-game` |
| Public domain | `<slug>.krzastek.work` | `spelling-game.krzastek.work` |

## Network / IP Schema

- Subnet: `192.168.0.0/24` — gateway `192.168.0.1`, broadcast `.255`
- **Static container range: `192.168.0.200–192.168.0.254`** (high-end reserved for Proxmox LXCs)
- Always set `gateway = "192.168.0.1"` and use `/24` prefix.
- **Before assigning an IP:** consult [ip-map.md](./ip-map.md) — the next free IP is noted at the top of that file.
- **After applying:** update `ip-map.md` with the new row and advance the "Next free IP" pointer. Treat this like updating a lock file — mandatory, not optional.

## Execution Model

```bash
# Build image (once or after Dockerfile changes)
docker compose build

# Open an interactive shell
docker compose run --rm tf-ansible sh

# One-shot command
docker compose run --rm tf-ansible terraform version
```

---

## Workflow: Add a New LXC

### Step 0 — Decide: clone from CT113 or fresh LXC?

| Condition | Action |
|-----------|--------|
| New app container (React/Vite/Tailwind) | Clone from CT113 → skip bootstrap script |
| Generic or non-app container (databases, services) | Fresh LXC from OS template |

If the user hasn't specified, ask: *"Should this be a React/Vite/Tailwind app? If so, I'll clone from CT113."*

1. **Create a new `.tf` file** named `app-<slug>.tf`.
   - Use `redis.tf` as the reference pattern for `proxmox_virtual_environment_container`.
   - Assign static IP, hostname, and tags.

2. **Format and validate:**
   ```bash
   docker compose run --rm tf-ansible terraform fmt
   docker compose run --rm tf-ansible terraform validate
   ```

3. **Generate a plan (mandatory):**
   ```bash
   docker compose run --rm tf-ansible terraform plan -out=tfplan
   ```

4. **Review the plan** — verify only the expected resource(s) appear.

5. **Apply the reviewed plan:**
   ```bash
   docker compose run --rm tf-ansible terraform apply tfplan
   ```

6. **Run Ansible if post-provision config is needed:**
   ```bash
   docker compose run --rm tf-ansible ansible-playbook playbook.yaml
   ```

7. **Commit with a descriptive message** explaining what changed and why.

8. **Verify** in Proxmox UI and with:
   ```bash
   docker compose run --rm tf-ansible terraform state list
   docker compose run --rm tf-ansible terraform state show proxmox_virtual_environment_container.<slug>
   ```

---

## Workflow: App Container from CT113 Clone (React/Vite/Tailwind)

CT113 is the baseline clone source for app containers. When cloning from CT113:
- **Do NOT run the bootstrap install script** — Node + Vite + Tailwind are already present.
- Only scaffold a new project when intentionally starting fresh.

**CT113 clone Terraform pattern:** model the new resource after CT113's definition with clone source ID set.

**Bootstrap script** (only for fresh, non-cloned containers):

```bash
#!/bin/bash
set -e

PROJECT_NAME="${1:-my-app}"
APP_DOMAIN="${PROJECT_NAME}.krzastek.work"

apt-get update -y && apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs

npm create vite@latest "$PROJECT_NAME" -- --template react
cd "$PROJECT_NAME"
npm install
npm install lucide-react tailwindcss postcss autoprefixer @tailwindcss/vite

npx tailwindcss init -p

cat <<EOF > tailwind.config.js
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: {} },
  plugins: [],
}
EOF

cat <<EOF > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat <<EOF > vite.config.js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: { allowedHosts: ['${APP_DOMAIN}'] }
})
EOF

echo "Done. Replace src/, then: npm run dev -- --host 0.0.0.0"
```

---

## Workflow: Day-2 Maintenance

```bash
# List managed resources
docker compose run --rm tf-ansible terraform state list

# Inspect a resource
docker compose run --rm tf-ansible terraform state show proxmox_virtual_environment_container.redis

# Preview changes
docker compose run --rm tf-ansible terraform plan -out=tfplan

# Apply
docker compose run --rm tf-ansible terraform apply tfplan

# Re-run Ansible
docker compose run --rm tf-ansible ansible-playbook playbook.yaml
```

**Destroy (dangerous — requires explicit plan):**
```bash
docker compose run --rm tf-ansible terraform plan -destroy -out=tfdestroy
docker compose run --rm tf-ansible terraform apply tfdestroy
```

### Decommissioning an LXC Safely

Use this workflow when removing a container from Terraform, especially if a direct destroy times out while the container is running.

1. Remove the final `.tf` definition only after the container has actually been destroyed.
2. If the container is healthy, a normal reviewed destroy plan is fine.
3. If `terraform apply` fails during delete with a Proxmox `status/current` timeout, temporarily reintroduce the resource definition and manage the container explicitly.
4. Set `started = false` on the resource and use a generous `timeout_delete` such as `600`.
5. Avoid `lifecycle { ignore_changes = all }` during this recovery step because it suppresses the `started = false` diff.
6. Import the live container back into state:
   ```bash
   docker compose run --rm tf-ansible terraform import proxmox_virtual_environment_container.<slug> <node>/<vmid>
   ```
7. Generate and apply a reviewed plan that only stops the container:
   ```bash
   docker compose run --rm tf-ansible terraform plan -out=tfplan-stop -target=proxmox_virtual_environment_container.<slug>
   docker compose run --rm tf-ansible terraform apply tfplan-stop
   ```
8. Confirm Terraform now sees `started = false` in state.
9. Generate and apply a reviewed destroy plan for that stopped container:
   ```bash
   docker compose run --rm tf-ansible terraform plan -destroy -out=tfdestroy -target=proxmox_virtual_environment_container.<slug>
   docker compose run --rm tf-ansible terraform apply tfdestroy
   ```
10. After successful destroy, remove the temporary `.tf` file and verify a clean plan.

Observed repo-specific lesson:

- `gemini-bridge` deleted successfully only after a Terraform-managed stop (`started = false`) followed by a Terraform destroy.
- `optmovementpt` remained stuck at the Proxmox side even after retrying deletes; in that state, Terraform cleanup may require a Proxmox-side remediation before destroy can succeed.

---

## Pre-Merge Checklist

Before committing any infra change:

- [ ] `terraform fmt` passes
- [ ] `terraform validate` passes
- [ ] Plan reviewed — no unexpected resource churn
- [ ] Apply completed cleanly
- [ ] Ansible run succeeded (if applicable)
- [ ] Proxmox UI reflects expected container state
- [ ] Git commit message explains what changed and why

---

## Reference Files

- [redis.tf](../../../redis.tf) — Reference LXC Terraform pattern
- [playbook.yaml](../../../playbook.yaml) — Ansible configuration playbook
- [docker-compose.yaml](../../../docker-compose.yaml) — tf-ansible service definition
- [Dockerfile](../../../Dockerfile) — Toolchain image
