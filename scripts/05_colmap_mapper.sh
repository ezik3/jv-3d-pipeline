#!/usr/bin/env bash
# =============================================================================
# STEP 5: COLMAP INCREMENTAL MAPPER (SPARSE RECONSTRUCTION, CPU, HEADLESS)
# Runs the incremental SfM mapper with relaxed thresholds to maximise the
# chance of a good initial pair being found (critical for video footage).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MAPPER] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

log "=========================================="
log "STEP 5: COLMAP Incremental Mapper"
log "=========================================="

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
export CUDA_VISIBLE_DEVICES=""

DB_PATH="$ROOT_DIR/database.db"
FRAMES_DIR="$ROOT_DIR/frames"
SPARSE_DIR="$ROOT_DIR/sparse"

if [ ! -f "$DB_PATH" ]; then
    die "Database not found: $DB_PATH. Run previous steps first."
fi

mkdir -p "$SPARSE_DIR"

log "Starting mapper ..."
log "  database  : $DB_PATH"
log "  image_path: $FRAMES_DIR"
log "  output    : $SPARSE_DIR"

QT_QPA_PLATFORM=offscreen colmap mapper \
    --database_path "$DB_PATH" \
    --image_path "$FRAMES_DIR" \
    --output_path "$SPARSE_DIR" \
    --Mapper.init_min_tri_angle 2 \
    --Mapper.min_num_matches 15 \
    --Mapper.abs_pose_min_num_inliers 6 \
    --Mapper.abs_pose_min_inlier_ratio 0.1 \
    --Mapper.max_reg_trials 3 \
    --Mapper.init_max_forward_motion 0.95 \
    --Mapper.init_min_num_inliers 100 \
    --Mapper.num_threads -1 \
    2>&1 | tee -a "$LOG_FILE"

log "Mapper finished."

# List what was produced
MODELS=$(ls -d "$SPARSE_DIR"/[0-9]* 2>/dev/null | wc -l)
log "Models produced: $MODELS"
if [ "$MODELS" -gt 0 ]; then
    for M in "$SPARSE_DIR"/[0-9]*/; do
        log "  $M : $(ls "$M" 2>/dev/null | tr '\n' ' ')"
    done
fi
