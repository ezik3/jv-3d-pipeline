#!/usr/bin/env bash
# =============================================================================
# STEP 2: FRAME EXTRACTION
# Extracts frames from the input video using ffmpeg.
# Uses fps=3 for high density, sharp frames.
# Validates that at least 200 frames were extracted.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FRAMES] $*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

log "=========================================="
log "STEP 2: Frame Extraction"
log "=========================================="

VIDEO_PATH="$ROOT_DIR/uploads/1 April 2026.mp4"
FRAMES_DIR="$ROOT_DIR/frames"
FPS="${FRAME_FPS:-3}"
MIN_FRAMES="${MIN_FRAMES:-200}"

# Validate input video exists
if [ ! -f "$VIDEO_PATH" ]; then
    die "Input video not found: $VIDEO_PATH"
fi

log "Input video  : $VIDEO_PATH"
log "Output dir   : $FRAMES_DIR"
log "Target FPS   : $FPS"
log "Min frames   : $MIN_FRAMES"

# Get video info
VIDEO_DURATION=$(ffprobe -v quiet -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null || echo "unknown")
log "Video duration: ${VIDEO_DURATION}s"

# Extract frames
# -q:v 2  → high quality JPEG (scale 1-31, lower is better)
# -vf "fps=...,unsharp=5:5:1.0:5:5:0.0" → sharp frames (mild unsharp mask)
log "Extracting frames at ${FPS} fps ..."
ffmpeg -y \
    -i "$VIDEO_PATH" \
    -vf "fps=${FPS},unsharp=5:5:1.0:5:5:0.0" \
    -q:v 2 \
    "$FRAMES_DIR/frame_%04d.jpg" \
    2>&1 | tee -a "$LOG_FILE"

# Count extracted frames
FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l)
log "Frames extracted: $FRAME_COUNT"

if [ "$FRAME_COUNT" -lt "$MIN_FRAMES" ]; then
    log "WARNING: Only $FRAME_COUNT frames extracted (minimum: $MIN_FRAMES)."
    log "Retrying with higher FPS (fps=5) ..."

    rm -f "$FRAMES_DIR"/frame_*.jpg

    ffmpeg -y \
        -i "$VIDEO_PATH" \
        -vf "fps=5,unsharp=5:5:1.0:5:5:0.0" \
        -q:v 2 \
        "$FRAMES_DIR/frame_%04d.jpg" \
        2>&1 | tee -a "$LOG_FILE"

    FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.jpg 2>/dev/null | wc -l)
    log "Frames after retry: $FRAME_COUNT"

    if [ "$FRAME_COUNT" -lt "$MIN_FRAMES" ]; then
        die "Insufficient frames after retry: $FRAME_COUNT (need >= $MIN_FRAMES). Check the input video."
    fi
fi

log "Frame extraction SUCCESS: $FRAME_COUNT frames in $FRAMES_DIR"

# Show a few sample filenames for verification
log "Sample frames:"
ls "$FRAMES_DIR"/frame_*.jpg | head -5 | while read f; do log "  $f"; done
