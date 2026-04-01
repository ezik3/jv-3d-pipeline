# JV-3D COLMAP Reconstruction Pipeline

A fully automated, headless, CPU-only COLMAP sparse reconstruction pipeline for video input.

## Environment

- **Platform**: Linux (RunPod or similar)
- **GPU**: Not required — all steps run on CPU
- **Display**: Not required — Qt runs in offscreen mode

## Prerequisites

```bash
# Ubuntu / Debian
sudo apt-get update
sudo apt-get install -y colmap ffmpeg sqlite3
```

## Input

Place your video at:
```
uploads/1 April 2026.mp4
```

## Run

```bash
chmod +x run_pipeline.sh scripts/*.sh
./run_pipeline.sh
```

### Optional environment variables

| Variable     | Default | Description                              |
|--------------|---------|------------------------------------------|
| `FRAME_FPS`  | `3`     | Frames-per-second for extraction         |
| `MIN_FRAMES` | `200`   | Minimum frame count before aborting      |
| `SKIP_GIT`   | `0`     | Set to `1` to skip git commit/push       |

Example:
```bash
FRAME_FPS=4 SKIP_GIT=1 ./run_pipeline.sh
```

## Output

| Path            | Contents                         |
|-----------------|----------------------------------|
| `frames/`       | Extracted JPEG frames            |
| `database.db`   | COLMAP feature/match database    |
| `sparse/0/`     | Final sparse model               |
| `logs/pipeline.log` | Full execution log           |

### Success criteria

`sparse/0/` must contain:
- `cameras.bin`  — camera intrinsics
- `images.bin`   — registered image poses
- `points3D.bin` — reconstructed 3D points

## Pipeline Steps

| Script                     | Purpose                                   |
|----------------------------|-------------------------------------------|
| `scripts/01_setup.sh`      | Clean old artifacts, recreate dirs        |
| `scripts/02_extract_frames.sh` | Extract frames from video via ffmpeg  |
| `scripts/03_colmap_features.sh` | Create DB, extract SIFT features    |
| `scripts/04_colmap_matching.sh` | Exhaustive feature matching         |
| `scripts/05_colmap_mapper.sh`   | Incremental SfM sparse mapper       |
| `scripts/06_validate.sh`   | Verify output files and print stats       |
| `scripts/07_retry_if_failed.sh` | Auto-retry with relaxed params     |

## Troubleshooting

| Error                              | Fix                                        |
|------------------------------------|--------------------------------------------|
| `No good initial image pair found` | Increase `FRAME_FPS`, rerun               |
| OpenGL / Qt errors                 | `QT_QPA_PLATFORM=offscreen` is set by default |
| GPU errors                         | `SiftExtraction.use_gpu 0` is set by default |
| Too few frames                     | Script auto-retries at fps=5               |
