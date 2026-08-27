# scripts/

Standalone Swift scripts. Run with `swift scripts/<name>.swift` — no build step, no package manifest.

| Script | Purpose |
|---|---|
| `refvideo.swift` | Reference-video analysis — frame extraction and contact sheets from competitor screen recordings. See below. |
| `generate_icon.swift` | Renders the app icon PNG. |
| `generate_launch_logo.swift` | Renders the launch-screen logo PNG. |

---

## refvideo.swift

Extracts frames from reference-game screen recordings so their gameplay and animation can be read frame by frame. Written because this machine has no `ffmpeg`; it drives AVFoundation directly.

The recordings themselves live **outside this repo**, in `../Screen Recordings/` (with already-processed ones moved to `../Screen Recordings/analyzed videos/`). Paths are arguments, so the script doesn't care where they are.

Run with no arguments for full usage.

### Two workflows

**Triage — "what is in this recording?"** Cheap, one pass, safe to run unattended over a folder.

```bash
swift scripts/refvideo.swift info  "../Screen Recordings/clip.MP4"
swift scripts/refvideo.swift sheet "../Screen Recordings/clip.MP4" /tmp/clip.jpg --step 1
```

`info` prints `key=value` lines (duration, dimensions, fps, size) for easy parsing. `sheet` builds a single tiled contact sheet of the whole clip with each thumbnail timestamped — one image that shows the entire recording at a glance, and cheap to re-read later without decoding the video again.

**Deep dive — "how exactly does this animation work?"** Iterative, interactive, expensive. Go coarse first, find the moment, then re-run tight.

```bash
# 1. structure: where does anything happen?
swift scripts/refvideo.swift frames "../Screen Recordings/clip.MP4" /tmp/f --step 0.5

# 2. narrow to the interesting window
swift scripts/refvideo.swift frames "../Screen Recordings/clip.MP4" /tmp/f2 --start 6.3 --end 7.2 --step 0.06

# 3. zoom into one tile at full source resolution
swift scripts/refvideo.swift crop  "../Screen Recordings/clip.MP4" /tmp/z \
      --rect 985,1285,215,195 --start 8.7 --end 9.0 --step 0.04
```

`--rect X,Y,W,H` is in **source pixels, origin top-left** — measure it off a full frame as you would off a screenshot. `crop` writes at native resolution (no downscaling), which is what makes small particle and glow detail readable.

### Notes

- Sampling is exact (zero tolerance), so `--step 0.03` on 60fps footage gives roughly every other real frame — dense enough to read a 0.06s animation phase.
- Output filenames embed the timestamp (`frame_003.90.jpg`, `crop_008.70.jpg`), so they sort in playback order and the name alone says where in the clip you are.
- Frame extraction is slow and produces a lot of images. The script refuses more than 20,000 frames in one run as a guard; in practice keep deep-dive sweeps to short windows.
- A full-depth animation analysis of one ~18s clip runs to roughly 50–60 extracted images. Triage first, and only deep-dive recordings that contain something new.

### Where the findings go

Analysis results are written up as draft specs in `specs/` — see `Spec_BoardAnimation_Draft.md` and `Spec_PartyBoard_Draft.md`, both produced with this tool. Those drafts are accumulating ahead of a design pass; they are not implementation-ready.
