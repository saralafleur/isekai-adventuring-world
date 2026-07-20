#!/usr/bin/env python3
"""Generate one audio file per dialogue line, cast with per-character voices.

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

# Casting. `rate` is words-per-minute (macOS default is ~175).
CAST: dict[str, dict] = {
    "Mira":        {"voice": "Samantha", "rate": 168},  # mother: warm, unhurried
    "Daren":       {"voice": "Daniel",   "rate": 148},  # father: low, deliberate
    "Kael":        {"voice": "Junior",   "rate": 180},  # the 14-year-old himself
    "Baker Hobb":  {"voice": "Ralph",    "rate": 190},  # brisk and cheerful
    "Elder Bram":  {"voice": "Albert",   "rate": 140},  # old and slow
    "Tarin":       {"voice": "Fred",     "rate": 195},  # loud, fast, overconfident
    "Lyra":        {"voice": "Kathy",    "rate": 172},  # clever, calm
}
FALLBACK = {"voice": "Samantha", "rate": 175}


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
    manifest: list[dict] = []
    made = skipped = 0

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
                    "voice": cast["voice"],
                    "text": text,
                }
            )
            if mp3.exists() and not args.force:
                skipped += 1
                continue

            aiff = OUT_DIR / f"{key}.aiff"
            subprocess.run(
                ["say", "-v", cast["voice"], "-r", str(cast["rate"]), "-o", str(aiff), text],
                check=True,
            )
            if "ffmpeg" in converter:
                subprocess.run(
                    [converter, "-y", "-loglevel", "error", "-i", str(aiff),
                     "-codec:a", "libmp3lame", "-b:a", "128k", str(mp3)],
                    check=True,
                )
            else:
                subprocess.run([converter, "--quiet", "-b", "128", str(aiff), str(mp3)], check=True)
            aiff.unlink(missing_ok=True)
            made += 1

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
