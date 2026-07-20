#!/usr/bin/env python3
"""Upload the generated dialogue clips to Roblox via Open Cloud, then record
the returned asset ids in src/shared/Data/VoiceLines.luau.

Why this and not the Creator Dashboard: the dashboard's audio page uploads one
file at a time behind a native file picker, which can't be driven reliably.
Open Cloud takes the same uploads over HTTP and hands back the asset id, so all
17 clips and the id table are done in one pass — and re-running only uploads
what's still missing.

Setup (once):
  1. https://create.roblox.com/dashboard/credentials  -> "Create API Key"
  2. Add the "Assets" API System, permissions: read + write
  3. Accept the default IP restriction (0.0.0.0/0) or add your IP
  4. Copy the key, then:  export ROBLOX_API_KEY='...'
  5. Find your user id at https://www.roblox.com/users/profile (the number in
     the URL), then:  export ROBLOX_USER_ID='...'
     (For a group instead: export ROBLOX_GROUP_ID='...')

Usage:
  python3 scripts/upload-voice-lines.py [--dry-run] [--limit N]

Roblox moderates uploaded audio; a clip may be Pending briefly before it plays.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "audio" / "manifest.json"
LUAU_OUT = ROOT / "src" / "shared" / "Data" / "VoiceLines.luau"
CREATE_URL = "https://apis.roblox.com/assets/v1/assets"
OP_URL = "https://apis.roblox.com/assets/v1/operations/{}"


def multipart(fields: dict[str, str], file_field: str, path: Path) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    out = bytearray()
    for name, value in fields.items():
        out += f"--{boundary}\r\n".encode()
        out += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        out += value.encode() + b"\r\n"
    out += f"--{boundary}\r\n".encode()
    out += (
        f'Content-Disposition: form-data; name="{file_field}"; filename="{path.name}"\r\n'
        f"Content-Type: audio/mpeg\r\n\r\n"
    ).encode()
    out += path.read_bytes() + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def request(url: str, key: str, data: bytes | None = None, content_type: str | None = None) -> dict:
    req = urllib.request.Request(url, data=data)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {exc.code}: {body}") from None


def upload(path: Path, name: str, key: str, creator: dict) -> str:
    payload = {
        "assetType": "Audio",
        "displayName": name[:50],
        "description": "Dialogue line for Isekai in an Adventuring World",
        "creationContext": {"creator": creator},
    }
    body, ctype = multipart({"request": json.dumps(payload)}, "fileContent", path)
    result = request(CREATE_URL, key, body, ctype)

    # Creation is asynchronous: poll the operation for the assetId
    op = result.get("operationId") or (result.get("path", "").rsplit("/", 1)[-1])
    if result.get("done") and result.get("response", {}).get("assetId"):
        return str(result["response"]["assetId"])
    for _ in range(30):
        time.sleep(2)
        status = request(OP_URL.format(op), key)
        if status.get("done"):
            asset_id = status.get("response", {}).get("assetId")
            if asset_id:
                return str(asset_id)
            raise RuntimeError(f"operation finished without an assetId: {status}")
    raise RuntimeError("timed out waiting for the asset to be created")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="upload at most N clips")
    args = parser.parse_args()

    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    user_id = os.environ.get("ROBLOX_USER_ID", "").strip()
    group_id = os.environ.get("ROBLOX_GROUP_ID", "").strip()
    if not args.dry_run:
        if not key:
            print("error: set ROBLOX_API_KEY (see this file's docstring)", file=sys.stderr)
            return 1
        if not user_id and not group_id:
            print("error: set ROBLOX_USER_ID (or ROBLOX_GROUP_ID)", file=sys.stderr)
            return 1
    creator = {"groupId": group_id} if group_id else {"userId": user_id}

    manifest = json.loads(MANIFEST.read_text())
    existing = dict(re.findall(r'\["([^"]+)"\] = (\d+),', LUAU_OUT.read_text()))
    todo = [m for m in manifest if existing.get(m["key"], "0") == "0"]
    if args.limit:
        todo = todo[: args.limit]

    print(f"{len(manifest)} clips, {len(todo)} still need uploading")
    if args.dry_run:
        for m in todo:
            print(f"  would upload {m['file']}  ({m['speaker']}: {m['text'][:44]})")
        return 0

    uploaded = 0
    for m in todo:
        path = ROOT / m["file"]
        try:
            asset_id = upload(path, f'{m["speaker"]} - {m["key"]}', key, creator)
        except Exception as exc:  # noqa: BLE001 - surface the reason and keep going
            print(f"  FAILED {m['key']}: {exc}", file=sys.stderr)
            continue
        existing[m["key"]] = asset_id
        uploaded += 1
        print(f"  {m['key']} -> {asset_id}")

        # rewrite the table after each success so a crash never loses ids
        rows = "\n".join(
            f'\t["{e["key"]}"] = {existing.get(e["key"], "0")}, -- {e["speaker"]}: {e["text"][:58]}'
            for e in manifest
        )
        LUAU_OUT.write_text(
            "--!strict\n"
            "-- Roblox asset id per spoken dialogue line. GENERATED by\n"
            "-- scripts/generate-voice-lines.py and filled in by\n"
            "-- scripts/upload-voice-lines.py.\n"
            "-- A 0 means 'not uploaded yet'; the game just stays silent for that line.\n\n"
            "local VoiceLines: { [string]: number } = {\n" + rows + "\n}\n\nreturn VoiceLines\n"
        )

    print(f"uploaded {uploaded}; ids written to {LUAU_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
