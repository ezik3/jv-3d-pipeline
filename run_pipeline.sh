#!/usr/bin/env bash
# =============================================================================
# JV-3D COLMAP RECONSTRUCTION PIPELINE
# Entrypoint: runs all steps end-to-end.
#
# Usage:
#   chmod +x run_pipeline.sh
#   ./run_pipeline.sh
#
# Optional env overrides:
#   FRAME_FPS=4        (default: 3)
#   MIN_FRAMES=200     (default: 200)
#   SKIP_GIT=1         (skip git commit/push; useful for testing)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/pipeline.log"
MAX_RETRIES=2

# Ensure logs dir and start fresh log
mkdir -p "$LOG_DIR"
echo "" >> "$LOG_FILE"  # blank separator between runs

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PIPELINE] $*" | tee -a "$LOG_FILE"; }
die()  { log "FATAL: $*"; exit 1; }

# ---- Preflight: check required tools ----
log "============================================================"
log " JV-3D COLMAP Pipeline  —  $(date '+%Y-%m-%d %H:%M:%S')"
log "============================================================"

for TOOL in ffmpeg ffprobe colmap; do
    if ! command -v "$TOOL" &>/dev/null; then
        die "Required tool not found: $TOOL. Install it before running."
    fi
    log "  $TOOL : $(command -v "$TOOL")"
done

# Print COLMAP version for record
COLMAP_VER=$(colmap --version 2>&1 | head -1 || echo "unknown")
log "  COLMAP version: $COLMAP_VER"

# ---- Helper: run a step script ----
run_step() {
    local STEP_SCRIPT="$1"
    local STEP_NAME="$2"
    log "------------------------------------------------------------"
    log "Running: $STEP_NAME"
    log "------------------------------------------------------------"
    if bash "$SCRIPT_DIR/scripts/$STEP_SCRIPT"; then
        log "$STEP_NAME — OK"
    else
        die "$STEP_NAME failed. Check $LOG_FILE for details."
    fi
}

# ---- Helper: check if sparse/0 is valid ----
sparse_model_valid() {
    local MODEL_DIR="$SCRIPT_DIR/sparse/0"
    [ -f "$MODEL_DIR/cameras.bin" ] && \
    [ -f "$MODEL_DIR/images.bin" ] && \
    [ -f "$MODEL_DIR/points3D.bin" ] && \
    [ "$(stat -c%s "$MODEL_DIR/cameras.bin"  2>/dev/null || stat -f%z "$MODEL_DIR/cameras.bin"  2>/dev/null || echo 0)" -gt 0 ] && \
    [ "$(stat -c%s "$MODEL_DIR/images.bin"   2>/dev/null || stat -f%z "$MODEL_DIR/images.bin"   2>/dev/null || echo 0)" -gt 0 ] && \
    [ "$(stat -c%s "$MODEL_DIR/points3D.bin" 2>/dev/null || stat -f%z "$MODEL_DIR/points3D.bin" 2>/dev/null || echo 0)" -gt 0 ]
}

# ============================================================
# STEP 1 — CLEAN SETUP
# ============================================================
run_step "01_setup.sh" "Step 1: Clean Setup"

# ============================================================
# STEP 2 — FRAME EXTRACTION
# ============================================================
run_step "02_extract_frames.sh" "Step 2: Frame Extraction"

# ============================================================
# STEPS 3-5 — COLMAP (with retry loop)
# ============================================================
ATTEMPT=0
RECONSTRUCTION_OK=0

while [ "$ATTEMPT" -le "$MAX_RETRIES" ]; do
    ATTEMPT=$((ATTEMPT + 1))
    log "============================================================"
    log " Reconstruction attempt $ATTEMPT / $((MAX_RETRIES + 1))"
    log "============================================================"

    if [ "$ATTEMPT" -gt 1 ]; then
        log "Previous attempt failed — running retry script ..."
        export RETRY_FPS=$((3 + ATTEMPT))
        bash "$SCRIPT_DIR/scripts/07_retry_if_failed.sh" || true
    else
        # Normal first attempt
        run_step "03_colmap_features.sh" "Step 3: Feature Extraction"
        run_step "04_colmap_matching.sh"  "Step 4: Feature Matching"
        run_step "05_colmap_mapper.sh"    "Step 5: Sparse Reconstruction"
    fi

    # Check result
    if sparse_model_valid; then
        log "Sparse model is present after attempt $ATTEMPT."
        RECONSTRUCTION_OK=1
        break
    else
        log "WARNING: sparse/0 not valid after attempt $ATTEMPT."
        if [ "$ATTEMPT" -le "$MAX_RETRIES" ]; then
            log "Will retry with relaxed parameters ..."
        fi
    fi
done

if [ "$RECONSTRUCTION_OK" -eq 0 ]; then
    die "Reconstruction FAILED after $((MAX_RETRIES + 1)) attempts. See $LOG_FILE."
fi

# ============================================================
# STEP 6 — VALIDATE
# ============================================================
run_step "06_validate.sh" "Step 6: Validate Reconstruction"

# ============================================================
# STEP 7 — GIT COMMIT & PUSH (only if SKIP_GIT is unset)
# ============================================================
if [ "${SKIP_GIT:-0}" = "1" ]; then
    log "SKIP_GIT=1 — skipping git commit/push."
else
    log "------------------------------------------------------------"
    log "Step 7: Git commit and push"
    log "------------------------------------------------------------"
    cd "$SCRIPT_DIR"

    # Stage everything except large binaries / frames
    git add run_pipeline.sh scripts/ logs/ .gitignore README.md 2>/dev/null || true
    # Do NOT git add frames/ database.db sparse/ (they are in .gitignore)

    if git diff --cached --quiet; then
        log "Nothing new to commit (scripts already committed)."
    else
        git commit -m "Working COLMAP reconstruction pipeline (CPU, headless, verified)"
        log "Committed."
    fi

    git push origin main
    log "Pushed to origin/main."
fi

log "============================================================"
log " PIPELINE COMPLETE — All steps passed."
log " Log: $LOG_FILE"
log "============================================================"
