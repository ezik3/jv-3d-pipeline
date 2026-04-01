#!/usr/bin/env bash
# =============================================================================
# STEP 7 (OPTIONAL): RETRY WITH RELAXED PARAMETERS
# Called automatically by run_pipeline.sh when the first reconstruction attempt
# fails. Increases FPS, adjusts thresholds, and reruns from feature extraction.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RETRY] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

log "=========================================="
log "RETRY: Relaxed parameters reconstruction"
log "=========================================="

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
export CUDA_VISIBLE_DEVICES=""

DB_PATH="$ROOT_DIR/database.db"
FRAMES_DIR="$ROOT_DIR/frames"
SPARSE_DIR="$ROOT_DIR/sparse"
VIDEO_PATH="$ROOT_DIR/uploads/1 April 2026.mp4"

# ---- Re-extract at higher FPS ----
RETRY_FPS="${RETRY_FPS:-5}"
log "Re-extracting frames at fps=$RETRY_FPS ..."
rm -f "$FRAMES_DIR"/frame_*.jpg
ffmpeg -y \
    -i "$VIDEO_PATH" \
    -vf "fps=${RETRY_FPS},unsharp=5:5:1.0:5:5:0.0" \
    -q:v 2 \
    "$FRAMES_DIR/frame_%04d.jpg" \
    2>&1 | tee -a "$LOG_FILE"

FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l)
log "Re-extracted $FRAME_COUNT frames."

# ---- Rebuild database ----
log "Rebuilding COLMAP database ..."
rm -f "$DB_PATH"
QT_QPA_PLATFORM=offscreen colmap database_creator \
    --database_path "$DB_PATH" \
    2>&1 | tee -a "$LOG_FILE"

# ---- Re-extract features ----
log "Re-extracting features ..."
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

# ---- Re-run matching with sequential (overlap=20) as fallback ----
log "Re-running sequential_matcher with overlap=20 ..."
QT_QPA_PLATFORM=offscreen colmap sequential_matcher \
    --database_path "$DB_PATH" \
    --SiftMatching.use_gpu 0 \
    --SiftMatching.max_ratio 0.85 \
    --SiftMatching.cross_check 1 \
    --SiftMatching.min_num_inliers 10 \
    --SequentialMatching.overlap 20 \
    --SequentialMatching.loop_detection 1 \
    2>&1 | tee -a "$LOG_FILE"

# ---- Retry mapper with even more relaxed thresholds ----
log "Re-running mapper with very relaxed thresholds ..."
rm -rf "$SPARSE_DIR"
mkdir -p "$SPARSE_DIR"

QT_QPA_PLATFORM=offscreen colmap mapper \
    --database_path "$DB_PATH" \
    --image_path "$FRAMES_DIR" \
    --output_path "$SPARSE_DIR" \
    --Mapper.init_min_tri_angle 1 \
    --Mapper.min_num_matches 10 \
    --Mapper.abs_pose_min_num_inliers 4 \
    --Mapper.abs_pose_min_inlier_ratio 0.05 \
    --Mapper.max_reg_trials 5 \
    --Mapper.init_max_forward_motion 0.99 \
    --Mapper.init_min_num_inliers 50 \
    --Mapper.num_threads -1 \
    2>&1 | tee -a "$LOG_FILE"

log "Retry mapper finished."
MODELS=$(ls -d "$SPARSE_DIR"/[0-9]* 2>/dev/null | wc -l)
log "Models produced after retry: $MODELS"
