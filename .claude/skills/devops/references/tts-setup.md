# tts-setup — dialogue voice toolchain

Goal: from a fresh clone, end with a machine that can regenerate and upload the
spoken dialogue, proven by synthesizing a real clip.

## What travels in git and what doesn't

| In the repo | Gitignored (install locally) |
|---|---|
| `tools/voice-tools/scripts/generate-voice-lines.py` | `.tts-models/` — 353 MB of Kokoro weights |
| `tools/voice-tools/scripts/upload-voice-lines.py` | `.venv-tts/` — the python env |
| `tools/voice-tools/scripts/setup-tts.sh` | |
| `audio/lines/*.mp3` — the generated clips | |
| `audio/manifest.json` | |
| `src/shared/Data/VoiceLines.luau` — Roblox asset ids | |

**The game does not need this toolchain to run.** Dialogue audio plays from
Roblox asset ids that are already committed, so a fresh clone has working
voices immediately. This setup is only needed to *change* the dialogue — add a
line, recast a character, or re-record everything.

## Phase 1 — Audit (always first, read-only)

```bash
zsh <skill-base-dir>/scripts/tts-setup-check.sh
```

If `kokoro-env` and both model rows are `ok`, the toolchain is ready — offer
the Phase 4 smoke test and stop. `asset-ids` showing `NEEDED` means clips exist
that haven't been uploaded yet; that's the `upload` step, not a setup problem.

## Phase 2 — Plan

| Step | Size / time | Interactive? |
|---|---|---|
| `brew install uv` (if missing) | ~30 MB, <1 min | No |
| `brew install ffmpeg` (if missing) | ~120 MB, ~2 min | No |
| Create `.venv-tts` + install kokoro-onnx, soundfile | ~250 MB, ~1 min | No |
| Download Kokoro model + voices | **353 MB**, 1–4 min | No |

Confirm before the model download — it's the one large item.

## Phase 3 — Install

One idempotent script does all of it:

```bash
zsh tools/voice-tools/scripts/setup-tts.sh
```

It checks prerequisites, creates the venv only if absent, installs the two
packages, downloads each model file only if missing, and finishes by
synthesizing a test clip. Re-running on a healthy setup changes nothing.

If `uv` or `ffmpeg` are missing it stops and names the `brew install` to run
rather than installing them silently.

## Phase 4 — Verify (smoke test)

1. Re-run the audit — `kokoro-env`, `kokoro-v1`, `voices-v1` all `ok`.
2. Regenerate the real dialogue and confirm the engine line reads
   `Kokoro (neural)` rather than the `say` fallback:
   ```bash
   python3 tools/voice-tools/scripts/generate-voice-lines.py --force
   ```
3. Spot-check a clip actually plays:
   ```bash
   afplay audio/lines/MiraBreakfast__greeting__1.mp3
   ```

## Uploading new clips

Regenerated audio needs re-uploading — the committed asset ids point at the
*previous* recordings.

```bash
export ROBLOX_API_KEY='...'      # create at create.roblox.com/dashboard/credentials
export ROBLOX_USER_ID='...'      # the number in your roblox.com profile URL
python3 tools/voice-tools/scripts/upload-voice-lines.py
```

The uploader writes each id into `VoiceLines.luau` as it lands, so an
interruption never loses progress. Set the ids back to `0` first if you want
existing lines re-uploaded (regenerating audio does not do this automatically).

## Notes

- **Casting lives in `voice-cast.json`** at the project root. Each character
  has a Kokoro voice and a speed, plus a macOS `say` voice used as fallback
  when the model isn't installed. The toolchain itself
  (`tools/voice-tools/`) is a shared git submodule — see its README.
- Kokoro ships **54 voices**; list them with:
  ```bash
  .venv-tts/bin/python -c "from kokoro_onnx import Kokoro; \
    print(sorted(Kokoro('.tts-models/kokoro-v1.0.onnx','.tts-models/voices-v1.0.bin').get_voices()))"
  ```
  Prefixes: `af_`/`am_` US female/male, `bf_`/`bm_` British female/male.
- The model is **local and free** — no API key, no per-use cost, works offline.
  It was chosen over Roblox's built-in TTS, which needs a published experience
  and bills against a quota.
- Never commit `ROBLOX_API_KEY`. It belongs in the shell environment only.
