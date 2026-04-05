#!/bin/bash
# ============================================================
# 08_gaussian_splat.sh — Convert COLMAP sparse → Gaussian Splat
# Run this AFTER run_pipeline.sh succeeds
# ============================================================

set -e

WORKSPACE="/workspace/jv-3d-pipeline"
SPARSE_DIR="$WORKSPACE/sparse/0"
OUTPUT_DIR="$WORKSPACE/output/gaussian"
FRAMES_DIR="$WORKSPACE/frames"

echo "======================================"
echo "  Step 8: Gaussian Splatting"
echo "======================================"

# —— Verify COLMAP output exists ——————————————————————————————
if [ ! -f "$SPARSE_DIR/cameras.bin" ]; then
  echo "✘ ERROR: No COLMAP output found."
  echo "  Run ./run_pipeline.sh first."
  exit 1
fi

echo "✔ COLMAP sparse model found"

# —— Create output folder ————————————————————————————————————
mkdir -p "$OUTPUT_DIR/data" "$OUTPUT_DIR/model" "$OUTPUT_DIR/export"

# —— Convert COLMAP → Nerfstudio format ———————————————————————
echo ""
echo "[1/3] Converting COLMAP output to Nerfstudio format..."

ns-process-data images \
  --data "$FRAMES_DIR" \
  --output-dir "$OUTPUT_DIR/data" \
  --skip-colmap \
  --colmap-model-path "$SPARSE_DIR"

echo "✔ Data converted"

# —— Train Gaussian Splat ————————————————————————————————————
echo ""
echo "[2/3] Training Gaussian Splat..."
echo "      This takes 10-30 mins. Your RTX 4090 will make it fast."

ns-train splatfacto \
  --data "$OUTPUT_DIR/data" \
  --output-dir "$OUTPUT_DIR/model" \
  --viewer.quit-on-train-completion True

echo "✔ Gaussian Splat trained"

# —— Export to .splat file ————————————————————————————————————
echo ""
echo "[3/3] Exporting .splat file for web viewer..."

LATEST_MODEL=$(ls -td "$OUTPUT_DIR/model/splatfacto/"* 2>/dev/null | head -1)

if [ -n "$LATEST_MODEL" ]; then
  ns-export gaussian-splat \
    --load-config "$LATEST_MODEL/config.yml" \
    --output-dir "$OUTPUT_DIR/export"
  echo "✔ Exported to: $OUTPUT_DIR/export/"
else
  echo "✘ Could not find trained model to export"
  exit 1
fi

echo ""
echo "======================================"
echo "  ✔ Gaussian Splat complete!"
echo ""
echo "  Your .splat file is at:"
echo "  $OUTPUT_DIR/export/"
echo ""
echo "  Next: Download it via Jupyter and"
echo "  load it into your React Three Fiber viewer."
echo "======================================"
