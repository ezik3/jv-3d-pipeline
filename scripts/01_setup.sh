#!/usr/bin/env bash
# =============================================================================
# STEP 1: CLEAN SETUP
# Removes stale artifacts and recreates clean working directories.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SETUP] $*" | tee -a "$LOG_FILE"; }

log "=========================================="
log "STEP 1: Clean Setup"
log "=========================================="

# Ensure log directory exists first
mkdir -p "$ROOT_DIR/logs"

# Remove stale artifacts
if [ -f "$ROOT_DIR/database.db" ]; then
    log "Removing existing database.db ..."
    rm -f "$ROOT_DIR/database.db"
fi

if [ -d "$ROOT_DIR/sparse" ]; then
    log "Removing existing sparse/ directory ..."
    rm -rf "$ROOT_DIR/sparse"
fi

if [ -d "$ROOT_DIR/frames" ] && [ "$(ls -A "$ROOT_DIR/frames" 2>/dev/null)" ]; then
    log "Removing existing frames/ contents ..."
    rm -f "$ROOT_DIR/frames/"*.jpg "$ROOT_DIR/frames/"*.png 2>/dev/null || true
fi

# Recreate directories
mkdir -p "$ROOT_DIR/frames"
mkdir -p "$ROOT_DIR/sparse"
mkdir -p "$ROOT_DIR/uploads"

log "Clean setup complete."
log "  Working directory : $ROOT_DIR"
log "  frames/           : $(ls "$ROOT_DIR/frames" | wc -l) files"
log "  sparse/           : ready"
