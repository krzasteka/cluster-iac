#!/usr/bin/env bash
# =============================================================================
# backup.sh — Pull application-level backups from all managed LXC containers
#
# Usage:
#   ./backup.sh              # run backup now
#   ./backup.sh --prune 7   # run backup, then delete archives older than 7 days
# =============================================================================

set -euo pipefail

PRUNE_DAYS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prune) PRUNE_DAYS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="backups/${BACKUP_TS}"

log()  { echo "[backup] $*"; }

echo ""
echo "════════════════════════════════════════════════════"
echo "  Proxmox Homelab — Application Backup"
echo "  $(date)"
echo "════════════════════════════════════════════════════"
echo ""

[[ -f docker-compose.yaml ]] || { echo "Run from repo root."; exit 1; }
[[ -f .env ]] || { echo ".env missing — needed for docker-compose."; exit 1; }

log "Backup timestamp: ${BACKUP_TS}"
log "Destination:      ./${BACKUP_DIR}/"

mkdir -p "${BACKUP_DIR}"

docker compose run --rm tf-ansible \
  ansible-playbook backup.yaml \
  -e "backup_ts=${BACKUP_TS}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Backup complete — $(date)"
echo ""

# List what was produced
echo "  Archives:"
for f in "${BACKUP_DIR}"/*.tar.gz; do
  SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
  echo "    ${SIZE}  $(basename "$f")"
done

# Prune old backups if requested
if [[ -n "${PRUNE_DAYS}" ]]; then
  echo ""
  log "Pruning backups older than ${PRUNE_DAYS} days..."
  find backups/ -maxdepth 1 -type d -mtime "+${PRUNE_DAYS}" -exec rm -rf {} + 2>/dev/null || true
  log "Prune complete."
fi

echo ""
echo "  Restore any archive with:"
echo "    tar xzf backups/<timestamp>/<hostname>.tar.gz -C /"
echo "════════════════════════════════════════════════════"
