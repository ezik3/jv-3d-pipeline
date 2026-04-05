#!/bin/bash
# ============================================================
# JV 3D PIPELINE — BOOT SCRIPT
# Run this ONCE when pod starts: bash boot.sh
# ============================================================

set -e

REPO_DIR="/workspace/jv-3d-pipeline"
GITHUB_REPO="https://github.com/ezik3/jv-3d-pipeline.git"

echo "======================================"
echo "  JV 3D Pipeline — Boot"
echo "======================================"

# —— 1. Install system dependencies ——————————————————————————
echo "[1/5] Installing dependencies..."
apt-get update -qq
apt-get install -y ffmpeg colmap sqlite3 git > /dev/null 2>&1
echo "      ✔ ffmpeg, colmap, sqlite3, git installed"

# —— 2. Install Python dependencies ——————————————————————————
echo "[2/5] Installing Python packages..."
pip install -q fastapi uvicorn python-multipart
echo "      ✔ Python packages installed"

# —— 3. Clone or update repo —————————————————————————————————
echo "[3/5] Setting up repo..."
cd /workspace

if [ ! -d "$REPO_DIR" ]; then
  git clone "$GITHUB_REPO"
  echo "      ✔ Repo cloned"
else
  cd "$REPO_DIR"
  git pull origin main
  echo "      ✔ Repo updated"
fi

cd "$REPO_DIR"

# —— 4. Set permissions ——————————————————————————————————————
echo "[4/5] Setting permissions..."
chmod +x boot.sh run_pipeline.sh scripts/*.sh
echo "      ✔ Scripts executable"

# —— 5. Create required folders ——————————————————————————————
echo "[5/5] Creating folders..."
mkdir -p uploads frames sparse logs
echo "      ✔ Folders ready"

# —— 6. Set headless env vars ————————————————————————————————
export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
export CUDA_VISIBLE_DEVICES=""

# Persist for this session
echo 'export QT_QPA_PLATFORM=offscreen' >> ~/.bashrc
echo 'export DISPLAY=""' >> ~/.bashrc
echo 'export CUDA_VISIBLE_DEVICES=""' >> ~/.bashrc

echo ""
echo "======================================"
echo "  ✔ Boot complete!"
echo ""
echo "  Next steps:"
echo "  1. Upload your video to: $REPO_DIR/uploads/"
echo "  2. Run: cd $REPO_DIR && ./run_pipeline.sh"
echo "======================================"
