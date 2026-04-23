#!/usr/bin/env bash
# =============================================================================
# provision-ssh-keys.sh — Inject the local SSH public key into every managed
# LXC container via the Proxmox host using `pct exec`.
#
# Usage:
#   ./provision-ssh-keys.sh                      # uses root@192.168.0.201
#   ./provision-ssh-keys.sh -u admin             # custom Proxmox host user
#   ./provision-ssh-keys.sh -u root -h 10.0.0.1 # custom host and user
#
# Requirements:
#   - SSH access to the Proxmox node as a user with `pct exec` permission
#   - ~/.ssh/id_ed25519.pub present locally
# =============================================================================

set -euo pipefail

PROXMOX_HOST="192.168.0.201"
PROXMOX_USER="root"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--host) PROXMOX_HOST="$2"; shift 2 ;;
    -u|--user) PROXMOX_USER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"

# All managed LXC container IDs
CONTAINERS=(100 101 102 103 104 105 106 108 109 111 112 900)

INJECT_CMD="mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
grep -qxF '${PUBKEY}' /root/.ssh/authorized_keys 2>/dev/null || \
echo '${PUBKEY}' >> /root/.ssh/authorized_keys && \
chmod 600 /root/.ssh/authorized_keys && \
echo ok"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Proxmox SSH Key Provisioning"
echo "  Target: ${PROXMOX_USER}@${PROXMOX_HOST}"
echo "════════════════════════════════════════════════════"
echo ""

for CTID in "${CONTAINERS[@]}"; do
  printf "  CT%s  " "${CTID}"
  RESULT=$(ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes \
    "${PROXMOX_USER}@${PROXMOX_HOST}" \
    "pct exec ${CTID} -- bash -c \"${INJECT_CMD}\"" 2>&1) && \
    echo "✓ key injected" || \
    echo "✗ FAILED: ${RESULT}"
done

echo ""
echo "Done. Verify with:  ./backup.sh"
