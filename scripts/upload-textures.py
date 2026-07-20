#!/usr/bin/env python3
"""Upload the generated card textures (textures/manifest.json) to Roblox via
Open Cloud as Decal assets, then record the returned asset ids in
src/shared/Data/Textures.luau. Mirrors scripts/upload-voice-lines.py's
approach for the same reason: Open Cloud takes uploads over HTTP and hands
back the asset id, so re-running only uploads what's still missing.

Setup: same Open Cloud API key/user id as scripts/upload-voice-lines.py
(ROBLOX_API_KEY, ROBLOX_USER_ID or ROBLOX_GROUP_ID) — the "Assets" API
System permission covers both Audio and Decal uploads.

Usage:
  python3 scripts/upload-textures.py [--dry-run]

Roblox moderates uploaded images; a texture may be Pending briefly before it
renders.
"""

from __future__ import annotations

import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "textures" / "manifest.json"
LUAU_OUT = ROOT / "src" / "shared" / "Data" / "Textures.luau"
CREATE_URL = "https://apis.roblox.com/assets/v1/assets"
OP_URL = "https://apis.roblox.com/assets/v1/operations/{}"


def multipart(fields: dict[str, str], file_field: str, path: Path) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    content_type = mimetypes.guess_type(path.name)[0] or "image/png"
    out = bytearray()
    for name, value in fields.items():
        out += f"--{boundary}\r\n".encode()
        out += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        out += value.encode() + b"\r\n"
    out += f"--{boundary}\r\n".encode()
    out += (
        f'Content-Disposition: form-data; name="{file_field}"; filename="{path.name}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n"
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
        "assetType": "Decal",
        "displayName": name[:50],
        "description": "Procedural card texture for Isekai in an Adventuring World",
        "creationContext": {"creator": creator},
    }
    body, ctype = multipart({"request": json.dumps(payload)}, "fileContent", path)
    result = request(CREATE_URL, key, body, ctype)

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
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
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
    existing: dict[str, str] = {}
    if LUAU_OUT.exists():
        existing = dict(re.findall(r'\["([^"]+)"\] = (\d+),', LUAU_OUT.read_text()))
    todo = [m for m in manifest if existing.get(m["key"], "0") == "0"]

    print(f"{len(manifest)} textures, {len(todo)} still need uploading")
    if args.dry_run:
        for m in todo:
            print(f"  would upload {m['file']}")
        return 0

    uploaded = 0
    for m in todo:
        path = ROOT / m["file"]
        try:
            asset_id = upload(path, m["displayName"], key, creator)
        except Exception as exc:  # noqa: BLE001 - surface the reason and keep going
            print(f"  FAILED {m['key']}: {exc}", file=sys.stderr)
            continue
        existing[m["key"]] = asset_id
        uploaded += 1
        print(f"  {m['key']} -> {asset_id}")

        rows = "\n".join(f'\t["{e["key"]}"] = {existing.get(e["key"], "0")}, -- {e["displayName"]}' for e in manifest)
        LUAU_OUT.parent.mkdir(parents=True, exist_ok=True)
        LUAU_OUT.write_text(
            "--!strict\n"
            "-- Roblox asset id per card texture. GENERATED by\n"
            "-- scripts/generate-textures.py and filled in by\n"
            "-- scripts/upload-textures.py.\n"
            "-- A 0 means 'not uploaded yet'.\n\n"
            "local Textures: { [string]: number } = {\n" + rows + "\n}\n\nreturn Textures\n"
        )

    print(f"uploaded {uploaded}; ids written to {LUAU_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
