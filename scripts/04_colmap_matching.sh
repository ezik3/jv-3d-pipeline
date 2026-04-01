#!/usr/bin/env bash
# =============================================================================
# STEP 4: COLMAP EXHAUSTIVE MATCHING (CPU, HEADLESS)
# Uses exhaustive_matcher so every image pair is compared — this is critical
# for videos where sequential matching can miss overlapping frames.
# Falls back to vocab_tree_matcher if the image set is very large (>500 frames)
# to keep runtime manageable while still providing good coverage.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MATCHING] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

log "=========================================="
log "STEP 4: COLMAP Feature Matching"
log "=========================================="

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
export CUDA_VISIBLE_DEVICES=""

DB_PATH="$ROOT_DIR/database.db"
FRAMES_DIR="$ROOT_DIR/frames"
LARGE_SET_THRESHOLD=500  # switch to sequential+overlap above this

if [ ! -f "$DB_PATH" ]; then
    die "Database not found: $DB_PATH. Run 03_colmap_features.sh first."
fi

FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l)
log "Frame count: $FRAME_COUNT"

if [ "$FRAME_COUNT" -le "$LARGE_SET_THRESHOLD" ]; then
    log "Using exhaustive_matcher (all pairs)."
    QT_QPA_PLATFORM=offscreen colmap exhaustive_matcher \
        --database_path "$DB_PATH" \
        --SiftMatching.use_gpu 0 \
        --SiftMatching.max_ratio 0.8 \
        --SiftMatching.max_distance 0.7 \
        --SiftMatching.cross_check 1 \
        --SiftMatching.min_num_inliers 15 \
        2>&1 | tee -a "$LOG_FILE"
else
    log "Large frame set (>$LARGE_SET_THRESHOLD). Using sequential_matcher with overlap=15."
    QT_QPA_PLATFORM=offscreen colmap sequential_matcher \
        --database_path "$DB_PATH" \
        --SiftMatching.use_gpu 0 \
        --SiftMatching.max_ratio 0.8 \
        --SiftMatching.max_distance 0.7 \
        --SiftMatching.cross_check 1 \
        --SiftMatching.min_num_inliers 15 \
        --SequentialMatching.overlap 15 \
        --SequentialMatching.loop_detection 1 \
        2>&1 | tee -a "$LOG_FILE"
fi

log "Feature matching complete."

# Sanity check: count matches in DB
if command -v sqlite3 &>/dev/null; then
    MATCH_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM matches;" 2>/dev/null || echo "unknown")
    log "Match rows in DB: $MATCH_COUNT"
    if [ "$MATCH_COUNT" = "0" ]; then
        die "No matches stored. Matching may have failed."
    fi
else
    log "(sqlite3 not available — skipping match count check)"
fi
