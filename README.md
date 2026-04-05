# JV 3D Pipeline

Automated video → COLMAP → 3D reconstruction pipeline for JointVibe venues.

---

## Every time you start a new RunPod pod

### Step 1 — Boot (one time per pod)
```bash
curl -sSL https://raw.githubusercontent.com/ezik3/jv-3d-pipeline/main/boot.sh | bash
```
Or if repo is already cloned:
```bash
cd /workspace/jv-3d-pipeline && bash boot.sh
```

This installs everything: ffmpeg, colmap, sqlite3, Python packages, sets env vars.

---

### Step 2 — Upload your video

Upload **any** .mp4 or .mov file into the `uploads/` folder.  
**No renaming required.** The pipeline auto-detects it.

---

### Step 3 — Run the pipeline
```bash
cd /workspace/jv-3d-pipeline
./run_pipeline.sh
```

That's it. Three steps total.

---

## Output

On success you will see:
```
sparse/0/cameras.bin
sparse/0/images.bin
sparse/0/points3D.bin
```

Check `logs/pipeline.log` for full output.

---

## Environment variables (optional overrides)

| Variable | Default | Purpose |
|---|---|---|
| `FRAME_FPS` | 3 | Frames per second to extract |
| `MIN_FRAMES` | 200 | Minimum frames before retry |
| `SKIP_GIT` | 0 | Set to 1 to skip git push |

Example:
```bash
FRAME_FPS=5 SKIP_GIT=1 ./run_pipeline.sh
```

---

## Troubleshooting

**"No video file found"** — Make sure a .mp4 or .mov is in the `uploads/` folder

**"No good initial image pair"** — Your video needs more parallax. Walk *around* objects, not toward them. See capture guide below.

**Git push fails** — Run `SKIP_GIT=1 ./run_pipeline.sh` to skip push, set up SSH key separately

---

## Capture guide (critical for COLMAP to work)

✅ DO:
- Walk slowly in a circle around tables/objects
- Move sideways, not just forward
- Keep camera steady
- 20–60 seconds of footage
- Include textured objects (chairs, tables, bar)

❌ DON'T:
- Walk straight forward
- Pan smoothly left-right only
- Film blank walls
- Film in motion blur

---

## Pipeline flow

```
boot.sh
  └─ installs deps, clones/pulls repo, sets env vars

run_pipeline.sh
  ├─ 01_setup.sh          → clean previous run
  ├─ 02_extract_frames.sh → video → frames (auto-detects filename)
  ├─ [retry loop x3]
  │    ├─ 03_colmap_features.sh  → SIFT feature extraction
  │    ├─ 04_colmap_matching.sh  → exhaustive/sequential matching
  │    └─ 05_colmap_mapper.sh    → sparse 3D reconstruction
  ├─ 06_validate.sh       → verify output is valid
  └─ git push             → commit logs back to repo
```
