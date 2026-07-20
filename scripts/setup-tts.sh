#!/bin/zsh
# Install the local neural TTS toolchain used to voice dialogue.
#
# Idempotent: re-running on a healthy setup re-verifies and changes nothing.
# Everything it installs is gitignored (a 325MB model and a venv), which is why
# this script exists — the repo carries the generated mp3s and the Roblox asset
# ids, but not the generator's dependencies.
#
# Usage:  zsh scripts/setup-tts.sh

setopt err_exit no_unset

ROOT="${0:A:h}/.."
ROOT="${ROOT:A}"
VENV="$ROOT/.venv-tts"
MODELS="$ROOT/.tts-models"
BASE_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"

echo "==> checking prerequisites"
if ! command -v uv >/dev/null 2>&1; then
  echo "    uv not found. Install it with:  brew install uv" >&2
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1 && ! command -v lame >/dev/null 2>&1; then
  echo "    need ffmpeg or lame for mp3 encoding. Install with:  brew install ffmpeg" >&2
  exit 1
fi
echo "    uv and an mp3 encoder present"

echo "==> python environment"
if [ -x "$VENV/bin/python" ]; then
  echo "    $VENV already exists"
else
  uv venv "$VENV" --python 3.12
fi
uv pip install --python "$VENV/bin/python" --quiet kokoro-onnx soundfile
"$VENV/bin/python" -c "import kokoro_onnx, soundfile" \
  && echo "    kokoro-onnx importable"

echo "==> model files (~353MB, downloaded once)"
mkdir -p "$MODELS"
for f in kokoro-v1.0.onnx voices-v1.0.bin; do
  if [ -s "$MODELS/$f" ]; then
    echo "    $f already present"
  else
    echo "    downloading $f ..."
    curl -fSL --progress-bar -o "$MODELS/$f" "$BASE_URL/$f"
  fi
done

echo "==> verifying end to end"
"$VENV/bin/python" - "$MODELS" <<'PY'
import sys, tempfile, pathlib
from kokoro_onnx import Kokoro
import soundfile as sf
models = pathlib.Path(sys.argv[1])
kok = Kokoro(str(models / "kokoro-v1.0.onnx"), str(models / "voices-v1.0.bin"))
samples, sr = kok.create("The harvest festival begins at dawn.", voice="af_heart", speed=1.0, lang="en-us")
out = pathlib.Path(tempfile.gettempdir()) / "kokoro_setup_check.wav"
sf.write(out, samples, sr)
print(f"    generated {len(samples)/sr:.2f}s of {sr}Hz audio -> {out}")
PY

echo
echo "TTS toolchain ready. Regenerate dialogue audio with:"
echo "    python3 scripts/generate-voice-lines.py --force"
echo "Then upload (needs ROBLOX_API_KEY + ROBLOX_USER_ID):"
echo "    python3 scripts/upload-voice-lines.py"
