#!/usr/bin/env bash
# =============================================================================
# dr-rebuild.sh — Full Disaster Recovery for Proxmox IaC homelab
#
# Usage:
#   ./dr-rebuild.sh          # interactive (one confirmation prompt before apply)
#   ./dr-rebuild.sh --yes    # fully unattended (no prompts)
#
# Prerequisites:
#   - Docker + Compose running on this machine
#   - .env file present in repo root
#   - SSH agent running with Proxmox key loaded (ssh-add ~/.ssh/<key>)
# =============================================================================

set -euo pipefail

PLAN_FILE="tfplan-dr-$(date +%Y%m%d-%H%M%S)"
UNATTENDED=false

for arg in "$@"; do
  [[ "$arg" == "--yes" ]] && UNATTENDED=true
done

log()  { echo "[DR] $*"; }
warn() { echo "[DR][WARN] $*" >&2; }
fail() { echo "[DR][FAIL] $*" >&2; exit 1; }

echo ""
echo "════════════════════════════════════════════════════"
echo "  Proxmox Homelab — Disaster Recovery"
echo "  $(date)"
echo "════════════════════════════════════════════════════"
echo ""

# ── Pre-flight checks ─────────────────────────────────────────────────────────
[[ -f .env ]] || fail ".env file not found. Restore it before running DR."
[[ -f docker-compose.yaml ]] || fail "Not in repo root. cd to /path/to/proxmox-iac first."

if ! ssh-add -l &>/dev/null; then
  warn "No SSH keys loaded in agent."
  warn "Proxmox SSH operations may fail — run: ssh-add ~/.ssh/<your-key>"
  if [[ "$UNATTENDED" == false ]]; then
    read -rp "[DR] Continue anyway? (yes/no): " CONFIRM_SSH
    [[ "$CONFIRM_SSH" == "yes" ]] || fail "Aborted."
  fi
fi

# ── Step 1: Build toolchain image ─────────────────────────────────────────────
log "Step 1/6 — Building tf-ansible toolchain image..."
docker compose build

# ── Step 2: Terraform init ────────────────────────────────────────────────────
log "Step 2/6 — Initialising Terraform..."
docker compose run --rm tf-ansible terraform init

# ── Step 3: Validate configuration ───────────────────────────────────────────
log "Step 3/6 — Validating Terraform configuration..."
docker compose run --rm tf-ansible terraform fmt -check
docker compose run --rm tf-ansible terraform validate

# ── Step 4: Generate plan ─────────────────────────────────────────────────────
log "Step 4/6 — Generating Terraform plan → ${PLAN_FILE}..."
docker compose run --rm tf-ansible terraform plan -lock=false -out="${PLAN_FILE}"

# ── Step 5: Confirm before apply ──────────────────────────────────────────────
if [[ "$UNATTENDED" == false ]]; then
  echo ""
  echo "────────────────────────────────────────────────────"
  echo "  Review the plan above."
  echo "  This will CREATE/UPDATE containers on Proxmox."
  echo "  Type 'yes' to apply, anything else to abort."
  echo "────────────────────────────────────────────────────"
  read -rp "  Apply? " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || fail "Aborted by user."
fi

# ── Step 6: Apply ─────────────────────────────────────────────────────────────
log "Step 5/6 — Applying Terraform plan (creating containers)..."
docker compose run --rm tf-ansible terraform apply "${PLAN_FILE}"

# ── Wait for containers to boot ───────────────────────────────────────────────
log "Waiting 45s for containers to boot and open SSH..."
sleep 45

# ── Step 7: Run Ansible ───────────────────────────────────────────────────────
log "Step 6/6 — Running Ansible playbook to install all services..."
docker compose run --rm tf-ansible ansible-playbook -i inventory.ini playbook.yaml

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
echo "  DR complete — $(date)"
echo ""
echo "  Automated installs completed for:"
echo "    ✓  Redis                (ct103 @ 192.168.0.231)"
echo "    ✓  Grafana              (ct105 @ 192.168.0.226)"
echo "    ✓  Pi-hole              (ct100 @ 192.168.0.202)"
echo "    ✓  Nginx Proxy Manager  (ct101 @ 192.168.0.203)"
echo "    ✓  Docker Engine        (ct102 @ 192.168.0.213)"
echo "    ✓  Prometheus           (ct104 @ 192.168.0.225)"
echo "    ✓  Uptime Kuma          (ct106 @ 192.168.0.227)"
echo "    ✓  n8n                  (ct109 @ 192.168.0.211)"
echo "    ✓  Invoice Ninja        (ct112 @ 192.168.0.214)"
echo "    ✓  Prometheus PVE Exp.  (ct111 @ 192.168.0.232)"
echo "    ✓  Cloudflare DDNS      (ct108 @ 192.168.0.173)"
echo ""
echo "  Remaining manual steps:"
echo "    ⚠  ops-controller  (ct900) — clone app repo + start service"
echo ""
echo "  Data that must be restored from backups:"
echo "    ⚠  Pi-hole    — custom DNS blocklists and local DNS records"
echo "    ⚠  n8n        — workflows (export JSON from UI before disaster)"
echo "    ⚠  Invoice Ninja — database dump"
echo "    ⚠  Grafana    — dashboards (export JSON from UI, or use provisioning)"
echo "    ⚠  Cloudflare DDNS — API token (stored in /etc/cloudflare-ddns/config on the container; back up that file)"
echo "════════════════════════════════════════════════════"
