#!/usr/bin/env python3
"""Generate one audio file per dialogue line, cast with per-character voices.

Uses Kokoro (a local 82M-parameter neural TTS, ~325MB ONNX model) when it is
installed, which sounds dramatically better than macOS `say` — blind tests rank
it ahead of Google WaveNet and Amazon Polly Neural. Falls back to `say` if the
model is missing, so the script always works.

  Set up Kokoro once:
    uv venv .venv-tts --python 3.12
    uv pip install --python .venv-tts/bin/python kokoro-onnx soundfile
    mkdir -p .tts-models && cd .tts-models
    curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
    curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin


Reads src/shared/Data/Dialogue.luau, speaks every line with macOS `say` using
the voice cast below, converts to mp3, and writes:

  audio/lines/<TreeId>__<NodeId>__<n>.mp3   the clips to upload to Roblox
  audio/manifest.json                        text + voice per clip (for review)
  src/shared/Data/VoiceLines.luau            key -> Roblox asset id (0 until set)

Roblox can only play audio it hosts, so the mp3s must be uploaded to your
account; drop the returned asset ids into VoiceLines.luau (or use
scripts/upload-voice-lines.py) and the game plays them instead of cloud TTS.

Usage:  python3 scripts/generate-voice-lines.py [--force]
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIALOGUE = ROOT / "src" / "shared" / "Data" / "Dialogue.luau"
OUT_DIR = ROOT / "audio" / "lines"
MANIFEST = ROOT / "audio" / "manifest.json"
LUAU_OUT = ROOT / "src" / "shared" / "Data" / "VoiceLines.luau"

KOKORO_MODEL = ROOT / ".tts-models" / "kokoro-v1.0.onnx"
KOKORO_VOICES = ROOT / ".tts-models" / "voices-v1.0.bin"
VENV_PY = ROOT / ".venv-tts" / "bin" / "python"

# Casting. `kokoro`/`speed` drive the neural engine; `voice`/`rate` are the
# macOS `say` fallback. Speed is a multiplier (1.0 = natural pace).
CAST: dict[str, dict] = {
    # mother: warm, unhurried — af_heart is Kokoro's highest-graded voice
    "Mira":       {"kokoro": "af_heart",  "speed": 0.95, "voice": "Samantha", "rate": 168},
    # father: older British male, slow and deliberate
    "Daren":      {"kokoro": "bm_george", "speed": 0.88, "voice": "Daniel",   "rate": 148},
    # Kael, 14 — the youngest-sounding male voice available
    "Kael":       {"kokoro": "am_puck",   "speed": 1.02, "voice": "Junior",   "rate": 180},
    # the baker: genuinely jolly
    "Baker Hobb": {"kokoro": "am_santa",  "speed": 1.0,  "voice": "Ralph",    "rate": 190},
    "Elder Bram": {"kokoro": "bm_lewis",  "speed": 0.82, "voice": "Albert",   "rate": 140},
    "Tarin":      {"kokoro": "am_liam",   "speed": 1.1,  "voice": "Fred",     "rate": 195},
    "Lyra":       {"kokoro": "af_bella",  "speed": 1.0,  "voice": "Kathy",    "rate": 172},
}
FALLBACK = {"kokoro": "af_sarah", "speed": 1.0, "voice": "Samantha", "rate": 175}


def kokoro_available() -> bool:
    return KOKORO_MODEL.exists() and KOKORO_VOICES.exists() and VENV_PY.exists()


def synth_kokoro(jobs: list[dict]) -> None:
    """Generate every clip in one subprocess — the model loads only once."""
    script = """
import json, sys
from kokoro_onnx import Kokoro
import soundfile as sf
kok = Kokoro(sys.argv[1], sys.argv[2])
for job in json.loads(sys.argv[3]):
    samples, sr = kok.create(job["text"], voice=job["voice"], speed=job["speed"], lang="en-us")
    sf.write(job["wav"], samples, sr)
    print("ok", job["wav"], flush=True)
"""
    payload = json.dumps(jobs)
    subprocess.run(
        [str(VENV_PY), "-c", script, str(KOKORO_MODEL), str(KOKORO_VOICES), payload],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def parse_dialogue(text: str) -> list[dict]:
    """Pull (tree, node, speaker, lines) out of the Luau dialogue table."""
    entries: list[dict] = []
    tree = None
    node = None
    speaker = None
    lines: list[str] = []
    in_lines = False

    for raw in text.splitlines():
        line = raw.rstrip()

        m = re.match(r"^\t(\w+) = \{$", line)
        if m:
            tree = m.group(1)
            continue

        m = re.match(r"^\t\t\t(\w+) = \{$", line)
        if m and tree:
            node, speaker, lines, in_lines = m.group(1), None, [], False
            continue

        m = re.match(r'^\t\t\t\tspeaker = "(.*)",$', line)
        if m:
            speaker = m.group(1)
            continue

        # single-line form:  lines = { "..." },
        m = re.match(r'^\t\t\t\tlines = \{ (".*") \},$', line)
        if m:
            lines = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))
            in_lines = False
        elif re.match(r"^\t\t\t\tlines = \{$", line):
            in_lines = True
            lines = []
            continue
        elif in_lines:
            if re.match(r"^\t\t\t\t\},$", line):
                in_lines = False
            else:
                found = re.findall(r'"((?:[^"\\]|\\.)*)"', line)
                lines.extend(found)
                continue

        if lines and tree and node and speaker:
            entries.append({"tree": tree, "node": node, "speaker": speaker, "lines": lines})
            lines = []

    return entries


def unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\\\", "\\")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="regenerate existing clips")
    args = parser.parse_args()

    if shutil.which("say") is None:
        print("error: macOS `say` not found", file=sys.stderr)
        return 1
    converter = shutil.which("ffmpeg") or shutil.which("lame")
    if converter is None:
        print("error: need ffmpeg or lame to make mp3s", file=sys.stderr)
        return 1

    entries = parse_dialogue(DIALOGUE.read_text())
    if not entries:
        print("error: parsed no dialogue lines", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    use_kokoro = kokoro_available()
    print("engine:", "Kokoro (neural)" if use_kokoro else "macOS say (fallback)")

    manifest: list[dict] = []
    pending: list[dict] = []
    skipped = 0

    for entry in entries:
        cast = CAST.get(entry["speaker"], FALLBACK)
        for index, raw_line in enumerate(entry["lines"], start=1):
            text = unescape(raw_line)
            key = f'{entry["tree"]}__{entry["node"]}__{index}'
            mp3 = OUT_DIR / f"{key}.mp3"
            manifest.append(
                {
                    "key": key,
                    "file": str(mp3.relative_to(ROOT)),
                    "speaker": entry["speaker"],
                    "voice": cast["kokoro"] if use_kokoro else cast["voice"],
                    "engine": "kokoro" if use_kokoro else "say",
                    "text": text,
                }
            )
            if mp3.exists() and not args.force:
                skipped += 1
                continue
            pending.append({"key": key, "mp3": mp3, "text": text, "cast": cast})

    if pending and use_kokoro:
        jobs = [
            {
                "text": p["text"],
                "voice": p["cast"]["kokoro"],
                "speed": p["cast"]["speed"],
                "wav": str(OUT_DIR / f'{p["key"]}.wav'),
            }
            for p in pending
        ]
        print(f"synthesizing {len(jobs)} clips...")
        synth_kokoro(jobs)

    for p in pending:
        raw = OUT_DIR / (f'{p["key"]}.wav' if use_kokoro else f'{p["key"]}.aiff')
        if not use_kokoro:
            subprocess.run(
                ["say", "-v", p["cast"]["voice"], "-r", str(p["cast"]["rate"]),
                 "-o", str(raw), p["text"]],
                check=True,
            )
        if "ffmpeg" in converter:
            subprocess.run(
                [converter, "-y", "-loglevel", "error", "-i", str(raw),
                 "-codec:a", "libmp3lame", "-b:a", "160k", str(p["mp3"])],
                check=True,
            )
        else:
            subprocess.run([converter, "--quiet", "-b", "160", str(raw), str(p["mp3"])], check=True)
        raw.unlink(missing_ok=True)

    made = len(pending)

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")

    # Preserve any asset ids already filled in
    existing: dict[str, str] = {}
    if LUAU_OUT.exists():
        existing = dict(re.findall(r'\["([^"]+)"\] = (\d+),', LUAU_OUT.read_text()))

    rows = "\n".join(
        f'\t["{m["key"]}"] = {existing.get(m["key"], "0")}, -- {m["speaker"]}: {m["text"][:58]}'
        for m in manifest
    )
    LUAU_OUT.write_text(
        "--!strict\n"
        "-- Roblox asset id per spoken dialogue line. GENERATED by\n"
        "-- scripts/generate-voice-lines.py — the ids are filled in by hand (or by\n"
        "-- scripts/upload-voice-lines.py) after uploading audio/lines/*.mp3.\n"
        "-- A 0 means 'not uploaded yet'; the game just stays silent for that line.\n\n"
        "local VoiceLines: { [string]: number } = {\n" + rows + "\n}\n\nreturn VoiceLines\n"
    )

    print(f"{made} clips generated, {skipped} already present -> {OUT_DIR.relative_to(ROOT)}")
    print(f"manifest: {MANIFEST.relative_to(ROOT)}")
    print(f"asset-id table: {LUAU_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
