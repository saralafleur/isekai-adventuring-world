#!/bin/zsh
# Read-only audit of the local neural TTS (dialogue voice) toolchain.
# Prints one "KEY | STATUS | DETAIL" line per check; exits 0 always.
# Safe to run any time — changes nothing.

setopt null_glob

line() { printf '%-18s | %-8s | %s\n' "$1" "$2" "$3"; }

# Project root: this script lives at <project>/.claude/skills/devops/scripts/
PROJECT_DIR="${0:A:h}/../../../.."
PROJECT_DIR="${PROJECT_DIR:A}"
VENV="$PROJECT_DIR/.venv-tts"
MODELS="$PROJECT_DIR/.tts-models"

avail_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ "$avail_gb" -ge 2 ]; then disk_status="ok"; else disk_status="LOW"; fi
line "disk-free" "$disk_status" "${avail_gb} GB free (model needs ~0.4 GB)"

# --- uv (creates the python env) ---
if command -v uv >/dev/null 2>&1; then
  line "uv" "ok" "$(uv --version 2>/dev/null | head -1)"
else
  line "uv" "MISSING" "uv package manager (brew install uv)"
fi

# --- mp3 encoder ---
if command -v ffmpeg >/dev/null 2>&1; then
  line "encoder" "ok" "ffmpeg $(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')"
elif command -v lame >/dev/null 2>&1; then
  line "encoder" "ok" "lame (ffmpeg preferred)"
else
  line "encoder" "MISSING" "need ffmpeg or lame for mp3 (brew install ffmpeg)"
fi

# --- python env with kokoro ---
if [ -x "$VENV/bin/python" ]; then
  if "$VENV/bin/python" -c "import kokoro_onnx, soundfile" >/dev/null 2>&1; then
    line "kokoro-env" "ok" ".venv-tts has kokoro-onnx + soundfile"
  else
    line "kokoro-env" "WRONG" ".venv-tts exists but kokoro-onnx is not importable"
  fi
else
  line "kokoro-env" "MISSING" ".venv-tts not created (run: zsh scripts/setup-tts.sh)"
fi

# --- model weights (gitignored: too large for the repo) ---
for f in kokoro-v1.0.onnx voices-v1.0.bin; do
  if [ -s "$MODELS/$f" ]; then
    line "${f%%.*}" "ok" "$(du -h "$MODELS/$f" | awk '{print $1}')"
  else
    line "${f%%.*}" "MISSING" "download via scripts/setup-tts.sh"
  fi
done

# --- generated clips + asset ids (these DO travel in git) ---
clip_count=$(ls "$PROJECT_DIR"/audio/lines/*.mp3 2>/dev/null | wc -l | tr -d ' ')
if [ "$clip_count" -gt 0 ]; then
  line "clips" "ok" "$clip_count mp3 files in audio/lines"
else
  line "clips" "MISSING" "no generated clips (run scripts/generate-voice-lines.py)"
fi

VOICE_TABLE="$PROJECT_DIR/src/shared/Data/VoiceLines.luau"
if [ -f "$VOICE_TABLE" ]; then
  uploaded=$(grep -c '\] = [1-9]' "$VOICE_TABLE" 2>/dev/null | head -1)
  pending=$(grep -c '\] = 0,' "$VOICE_TABLE" 2>/dev/null | head -1)
  : "${uploaded:=0}" "${pending:=0}"
  if [ "$pending" -eq 0 ] && [ "$uploaded" -gt 0 ]; then
    line "asset-ids" "ok" "$uploaded lines have Roblox asset ids"
  else
    line "asset-ids" "NEEDED" "$uploaded uploaded, $pending still 0 (run scripts/upload-voice-lines.py)"
  fi
else
  line "asset-ids" "MISSING" "VoiceLines.luau not generated yet"
fi

# --- upload credentials (env only; never stored in the repo) ---
if [ -n "${ROBLOX_API_KEY:-}" ]; then
  line "roblox-key" "ok" "ROBLOX_API_KEY set in this shell"
else
  line "roblox-key" "info" "ROBLOX_API_KEY unset (only needed to upload new clips)"
fi

exit 0
