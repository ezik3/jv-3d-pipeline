#!/bin/bash
# ============================================================
# 02_extract_frames.sh — Extract frames from video
# Auto-detects any .mp4 in uploads/ — no hardcoded filename
# ============================================================

set -e

UPLOADS_DIR="uploads"
FRAMES_DIR="frames"
FRAME_FPS="${FRAME_FPS:-3}"
MIN_FRAMES="${MIN_FRAMES:-200}"

echo "[Step 2] Extracting frames..."

# —— Auto-detect video file ——————————————————————————————————
VIDEO_FILE=$(find "$UPLOADS_DIR" -maxdepth 1 -name "*.mp4" -o -name "*.mov" -o -name "*.MP4" -o -name "*.MOV" 2>/dev/null | head -1)

if [ -z "$VIDEO_FILE" ]; then
  echo "  ✘ ERROR: No video file found in $UPLOADS_DIR/"
  echo "    Upload any .mp4 or .mov file — no renaming required."
  exit 1
fi

echo "  ✔ Found video: $VIDEO_FILE"

# —— Extract frames ——————————————————————————————————————————
echo "  → Extracting at ${FRAME_FPS}fps..."

ffmpeg -i "$VIDEO_FILE" \
  -vf "fps=${FRAME_FPS},scale=960:-1,unsharp=5:5:1.5" \
  -q:v 2 \
  "$FRAMES_DIR/frame_%04d.jpg" \
  -hide_banner -loglevel warning

FRAME_COUNT=$(find "$FRAMES_DIR" -name "*.jpg" | wc -l)
echo "  ✔ Extracted $FRAME_COUNT frames"

# —— Validate frame count ————————————————————————————————————
if [ "$FRAME_COUNT" -lt "$MIN_FRAMES" ]; then
  echo "  ⚠  Only $FRAME_COUNT frames (minimum $MIN_FRAMES). Retrying at 5fps..."
  rm -f "$FRAMES_DIR"/*.jpg

  ffmpeg -i "$VIDEO_FILE" \
    -vf "fps=5,scale=960:-1,unsharp=5:5:1.5" \
    -q:v 2 \
    "$FRAMES_DIR/frame_%04d.jpg" \
    -hide_banner -loglevel warning

  FRAME_COUNT=$(find "$FRAMES_DIR" -name "*.jpg" | wc -l)
  echo "  ✔ Retry extracted $FRAME_COUNT frames"

  if [ "$FRAME_COUNT" -lt 30 ]; then
    echo "  ✘ ERROR: Only $FRAME_COUNT frames. Video too short or corrupted."
    exit 1
  fi
fi

echo "  ✔ Frame extraction complete: $FRAME_COUNT frames"
