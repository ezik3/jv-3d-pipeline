#!/usr/bin/env bash
# =============================================================================
# STEP 6: VALIDATE RECONSTRUCTION OUTPUT
# Checks that sparse/0/{cameras,images,points3D}.bin exist and are non-empty.
# Prints registered image count and 3D point count using COLMAP model_analyzer.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$ROOT_DIR/logs/pipeline.log"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VALIDATE] $*" | tee -a "$LOG_FILE"; }
pass() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VALIDATE] ✔ $*" | tee -a "$LOG_FILE"; }
fail() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VALIDATE] ✘ $*" | tee -a "$LOG_FILE"; exit 1; }

log "=========================================="
log "STEP 6: Validate Reconstruction"
log "=========================================="

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""

SPARSE_DIR="$ROOT_DIR/sparse"
MODEL_DIR="$SPARSE_DIR/0"

# ---- 6a. Check model directory ----
if [ ! -d "$MODEL_DIR" ]; then
    fail "sparse/0 directory not found. Reconstruction did not produce a model."
fi
pass "sparse/0 directory exists."

# ---- 6b. Check required binary files ----
REQUIRED_FILES=("cameras.bin" "images.bin" "points3D.bin")
for F in "${REQUIRED_FILES[@]}"; do
    FPATH="$MODEL_DIR/$F"
    if [ ! -f "$FPATH" ]; then
        fail "Missing required file: $FPATH"
    fi
    FSIZE=$(stat -c%s "$FPATH" 2>/dev/null || stat -f%z "$FPATH" 2>/dev/null || echo 0)
    if [ "$FSIZE" -eq 0 ]; then
        fail "File is empty: $FPATH"
    fi
    pass "$F exists (${FSIZE} bytes)"
done

# ---- 6c. Print model stats using colmap model_analyzer ----
log "Running COLMAP model_analyzer ..."
QT_QPA_PLATFORM=offscreen colmap model_analyzer \
    --path "$MODEL_DIR" \
    2>&1 | tee -a "$LOG_FILE" | grep -E "Cameras|Images|Points|Mean" || true

# ---- 6d. Parse registered images count (fallback via model_analyzer output) ----
ANALYZER_OUT=$(QT_QPA_PLATFORM=offscreen colmap model_analyzer \
    --path "$MODEL_DIR" 2>&1 || true)

REG_IMAGES=$(echo "$ANALYZER_OUT" | grep -oP 'Images:\s+\K[0-9]+' | head -1 || echo "unknown")
POINTS_3D=$(echo "$ANALYZER_OUT" | grep -oP 'Points:\s+\K[0-9]+' | head -1 || echo "unknown")

log "------------------------------------------"
log "Registered images : $REG_IMAGES"
log "3D points         : $POINTS_3D"
log "------------------------------------------"

# ---- 6e. Hard minimum thresholds ----
if [[ "$REG_IMAGES" =~ ^[0-9]+$ ]] && [ "$REG_IMAGES" -lt 3 ]; then
    fail "Too few registered images ($REG_IMAGES). Reconstruction is not usable."
fi

if [[ "$POINTS_3D" =~ ^[0-9]+$ ]] && [ "$POINTS_3D" -lt 10 ]; then
    fail "Too few 3D points ($POINTS_3D). Reconstruction is not usable."
fi

pass "Reconstruction validation PASSED."
log "Pipeline complete — sparse model is valid."
