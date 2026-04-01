#!/usr/bin/env bash
# =============================================================================
# STEP 3: COLMAP DATABASE CREATION + FEATURE EXTRACTION (CPU, HEADLESS)
# Creates the COLMAP database and extracts SIFT features from all frames.
# Forces CPU-only SIFT (use_gpu=0) and headless Qt (offscreen platform).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FEATURES] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

log "=========================================="
log "STEP 3: COLMAP Feature Extraction"
log "=========================================="

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
# Ensure no GPU is accidentally used
export CUDA_VISIBLE_DEVICES=""

DB_PATH="$ROOT_DIR/database.db"
FRAMES_DIR="$ROOT_DIR/frames"

# Validate frames exist
FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l)
if [ "$FRAME_COUNT" -eq 0 ]; then
    die "No frames found in $FRAMES_DIR. Run 02_extract_frames.sh first."
fi
log "Found $FRAME_COUNT frames."

# --- 3a. Create database ---
log "Creating COLMAP database: $DB_PATH"
QT_QPA_PLATFORM=offscreen colmap database_creator \
    --database_path "$DB_PATH" \
    2>&1 | tee -a "$LOG_FILE"

if [ ! -f "$DB_PATH" ]; then
    die "Database was not created at $DB_PATH"
fi
log "Database created successfully."

# --- 3b. Extract features ---
log "Extracting SIFT features (CPU mode) ..."
QT_QPA_PLATFORM=offscreen colmap feature_extractor \
    --database_path "$DB_PATH" \
    --image_path "$FRAMES_DIR" \
    --ImageReader.camera_model SIMPLE_RADIAL \
    --ImageReader.single_camera 1 \
    --SiftExtraction.use_gpu 0 \
    --SiftExtraction.max_image_size 3200 \
    --SiftExtraction.max_num_features 8192 \
    --SiftExtraction.first_octave -1 \
    2>&1 | tee -a "$LOG_FILE"

log "Feature extraction complete."

# Quick sanity: verify DB has keypoints via sqlite3 (if available)
if command -v sqlite3 &>/dev/null; then
    KP_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM keypoints;" 2>/dev/null || echo "unknown")
    log "Keypoint rows in DB: $KP_COUNT"
    if [ "$KP_COUNT" = "0" ]; then
        die "No keypoints stored in database. Feature extraction may have failed."
    fi
else
    log "(sqlite3 not available — skipping keypoint count check)"
fi
