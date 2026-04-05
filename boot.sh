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
echo "[1/6] Installing dependencies..."
apt-get update -qq
apt-get install -y ffmpeg colmap sqlite3 git > /dev/null 2>&1
echo "      ✔ ffmpeg, colmap, sqlite3, git installed"

# —— 2. Install Python dependencies ——————————————————————————
echo "[2/6] Installing Python packages..."
pip install -q fastapi uvicorn python-multipart
echo "      ✔ Python packages installed"

# —— 3. Clone or update repo —————————————————————————————————
echo "[3/6] Setting up repo..."
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
echo "[4/6] Setting permissions..."
chmod +x boot.sh run_pipeline.sh scripts/*.sh
echo "      ✔ Scripts executable"

# —— 5. Create required folders ——————————————————————————————
echo "[5/6] Creating folders..."
mkdir -p uploads frames sparse logs output/gaussian
echo "      ✔ Folders ready"

# —— 6. Set env vars + git identity ——————————————————————————
echo "[6/6] Setting environment..."

export QT_QPA_PLATFORM=offscreen
export DISPLAY=""
export CUDA_VISIBLE_DEVICES=""

echo 'export QT_QPA_PLATFORM=offscreen' >> ~/.bashrc
echo 'export DISPLAY=""' >> ~/.bashrc
echo 'export CUDA_VISIBLE_DEVICES=""' >> ~/.bashrc

git config --global user.email "eziteezi@gmail.com"
git config --global user.name "Ezi"

echo "      ✔ Env vars set"
echo "      ✔ Git identity set"

echo ""
echo "======================================"
echo "  ✔ Boot complete!"
echo ""
echo "  Next steps:"
echo "  1. Upload video to: $REPO_DIR/uploads/"
echo "  2. Run pipeline:    ./run_pipeline.sh"
echo "  3. After success:   ./scripts/08_gaussian_splat.sh"
echo "======================================"
