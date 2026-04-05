#!/bin/bash
# ============================================================
# 07_retry_if_failed.sh — Retry with relaxed settings
# Auto-detects video — no hardcoded filename
# ============================================================

set -e

UPLOADS_DIR="uploads"
FRAMES_DIR="frames"
RETRY_FPS="${RETRY_FPS:-5}"

echo "[Retry] Re-running with relaxed settings (fps=$RETRY_FPS)..."

# —— Auto-detect video ————————————————————————————————————————
VIDEO_FILE=$(find "$UPLOADS_DIR" -maxdepth 1 -name "*.mp4" -o -name "*.mov" -o -name "*.MP4" -o -name "*.MOV" 2>/dev/null | head -1)

if [ -z "$VIDEO_FILE" ]; then
  echo "  ✘ ERROR: No video file found in $UPLOADS_DIR/"
  exit 1
fi

echo "  ✔ Using video: $VIDEO_FILE"

# —— Clean and re-extract at higher fps ———————————————————————
rm -f "$FRAMES_DIR"/*.jpg
rm -f database.db

ffmpeg -i "$VIDEO_FILE" \
  -vf "fps=${RETRY_FPS},scale=960:-1" \
  -q:v 2 \
  "$FRAMES_DIR/frame_%04d.jpg" \
  -hide_banner -loglevel warning

FRAME_COUNT=$(find "$FRAMES_DIR" -name "*.jpg" | wc -l)
echo "  ✔ Re-extracted $FRAME_COUNT frames at ${RETRY_FPS}fps"

# —— Rebuild DB + features ————————————————————————————————————
export QT_QPA_PLATFORM=offscreen
export DISPLAY=""

colmap database_creator --database_path database.db

colmap feature_extractor \
  --database_path database.db \
  --image_path "$FRAMES_DIR" \
  --SiftExtraction.use_gpu 0 \
  --SiftExtraction.max_num_features 4096

# —— Sequential matcher with higher overlap ———————————————————
colmap sequential_matcher \
  --database_path database.db \
  --SiftMatching.use_gpu 0 \
  --SequentialMatching.overlap 20 \
  --SequentialMatching.loop_detection 1

# —— Mapper with very relaxed thresholds ———————————————————————
mkdir -p sparse

colmap mapper \
  --database_path database.db \
  --image_path "$FRAMES_DIR" \
  --output_path sparse \
  --Mapper.init_min_num_inliers 15 \
  --Mapper.min_model_size 3 \
  --Mapper.abs_pose_min_num_inliers 15 \
  --Mapper.abs_pose_min_inlier_ratio 0.1

echo "  ✔ Retry complete"
