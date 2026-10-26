#!/usr/bin/env python3
"""Generate ElevenLabs dialogue VO for Old Money.

Reads static lines for known speakers from content/*.tres and a few GDScript pools,
writes MP3s under assets/voices/<speaker>/<hash>.mp3 and assets/voices/manifest.json.

Usage (from repo root):
  python tools/voices/generate_dialogue_voices.py          # generate missing
  python tools/voices/generate_dialogue_voices.py --dry    # list only
  python tools/voices/generate_dialogue_voices.py --force  # regenerate all
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOICES_CFG = Path(__file__).with_name("voices.json")
SECRETS = Path(__file__).with_name("secrets.local.json")
OUT_DIR = ROOT / "assets" / "voices"
MANIFEST = OUT_DIR / "manifest.json"
CACHE_DIR = Path(__file__).with_name(".cache")

# PackedStringArray pools in GDScript that are spoken by a fixed speaker.
POOL_SOURCES: list[tuple[str, Path, str]] = [
    ("Вивьен", ROOT / "scenes" / "home" / "vivienne.gd", "GOSSIP"),
    ("Вивьен", ROOT / "scenes" / "home" / "vivienne.gd", "EVENING"),
    ("Вивьен", ROOT / "scenes" / "home" / "vivienne.gd", "AFTERNOON"),
    ("Вивьен", ROOT / "scenes" / "home" / "vivienne.gd", "NIGHT"),
    ("Вивьен", ROOT / "scenes" / "home" / "vivienne.gd", "SAID_ALL"),
]

LINE_BLOCK = re.compile(
    r'(?:speaker\s*=\s*"(?P<speaker>[^"]*)"\s*\ntext\s*=\s*"(?P<text>(?:\\.|[^"\\])*)"'
    r'|text\s*=\s*"(?P<text2>(?:\\.|[^"\\])*)"\s*\nspeaker\s*=\s*"(?P<speaker2>[^"]*)")',
    re.MULTILINE,
)
POOL_BLOCK = re.compile(
    r'const\s+(?P<name>[A-Z_]+)\s*:\s*PackedStringArray\s*=\s*\[\s*(?P<body>.*?)\s*\]',
    re.DOTALL,
)
STRING_LIT = re.compile(r'"((?:\\.|[^"\\])*)"')


def unescape(text: str) -> str:
    return (
        text.replace(r"\\", "\\")
        .replace(r"\"", '"')
        .replace(r"\n", "\n")
        .replace(r"\t", "\t")
    )


def line_key(speaker: str, text: str) -> str:
    return f"{speaker}\n{text}"


def line_hash(speaker: str, text: str) -> str:
    return hashlib.sha1(line_key(speaker, text).encode("utf-8")).hexdigest()[:16]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def collect_from_tres(speakers: set[str]) -> list[tuple[str, str, str]]:
    found: list[tuple[str, str, str]] = []
    for path in (ROOT / "content").rglob("*.tres"):
        text = path.read_text(encoding="utf-8")
        for match in LINE_BLOCK.finditer(text):
            speaker = match.group("speaker") or match.group("speaker2") or ""
            line = unescape(match.group("text") or match.group("text2") or "")
            if speaker in speakers and line.strip():
                found.append((speaker, line, str(path.relative_to(ROOT))))
    return found


def collect_pools(speakers: set[str]) -> list[tuple[str, str, str]]:
    found: list[tuple[str, str, str]] = []
    for speaker, path, pool_name in POOL_SOURCES:
        if speaker not in speakers or not path.exists():
            continue
        source = path.read_text(encoding="utf-8")
        for match in POOL_BLOCK.finditer(source):
            if match.group("name") != pool_name:
                continue
            for lit in STRING_LIT.findall(match.group("body")):
                line = unescape(lit)
                if "%" in line or not line.strip():
                    continue
                found.append((speaker, line, f"{path.relative_to(ROOT)}::{pool_name}"))
    return found


def collect_static_gdscript(speakers: set[str]) -> list[tuple[str, str, str]]:
    """DialogueLineDef.make(\"Name\", \"literal without %\") in scenes/ and sim/."""
    found: list[tuple[str, str, str]] = []
    pattern = re.compile(
        r'DialogueLineDef\.make\(\s*(?:UiText\.(?P<const>LORD|REGGIE|VIVIENNE|JACK)|"(?P<name>[^"]+)")\s*,\s*"(?P<text>(?:\\.|[^"\\])*)"\s*\)'
    )
    const_map = {
        "LORD": "Лорд Эшкомб",
        "REGGIE": "Реджи",
        "VIVIENNE": "Вивьен",
        "JACK": "Джек",
    }
    for folder in (ROOT / "scenes", ROOT / "sim", ROOT / "content"):
        for path in folder.rglob("*.gd"):
            source = path.read_text(encoding="utf-8")
            for match in pattern.finditer(source):
                speaker = const_map.get(match.group("const") or "", match.group("name") or "")
                line = unescape(match.group("text"))
                if speaker in speakers and line.strip() and "%" not in line:
                    found.append((speaker, line, str(path.relative_to(ROOT))))
    return found


def unique_lines(rows: list[tuple[str, str, str]]) -> list[tuple[str, str, list[str]]]:
    by_key: dict[str, tuple[str, str, list[str]]] = {}
    for speaker, text, source in rows:
        key = line_key(speaker, text)
        if key not in by_key:
            by_key[key] = (speaker, text, [source])
        else:
            by_key[key][2].append(source)
    return list(by_key.values())


def synthesize(api_key: str, voice_id: str, text: str, model_id: str, settings: dict, out_path: Path) -> None:
    payload = {
        "text": text,
        "model_id": model_id,
        "voice_settings": settings,
    }
    request = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_bytes(response.read())
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"ElevenLabs {error.code}: {body}") from error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry", action="store_true", help="list lines, do not call the API")
    parser.add_argument("--force", action="store_true", help="regenerate existing files")
    parser.add_argument("--limit", type=int, default=0, help="generate at most N missing files")
    args = parser.parse_args()

    cfg = load_json(VOICES_CFG)
    speakers = set(cfg["speakers"].keys())
    rows = unique_lines(
        collect_from_tres(speakers)
        + collect_pools(speakers)
        + collect_static_gdscript(speakers)
    )
    rows.sort(key=lambda row: (row[0], row[1]))

    print(f"speakers: {', '.join(sorted(speakers))}")
    print(f"unique lines: {len(rows)}")
    for speaker, text, sources in rows:
        print(f"  [{speaker}] {text[:80]}{'…' if len(text) > 80 else ''}  ({sources[0]})")

    if args.dry:
        return 0

    if not SECRETS.exists():
        print(f"Missing {SECRETS}. Copy secrets.local.json.example and put your API key there.", file=sys.stderr)
        return 2
    api_key = load_json(SECRETS).get("elevenlabs_api_key", "").strip()
    if not api_key or api_key.startswith("sk_REPLACE"):
        print("Set elevenlabs_api_key in tools/voices/secrets.local.json", file=sys.stderr)
        return 2

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, str] = {}
    if MANIFEST.exists():
        manifest = load_json(MANIFEST)

    generated = 0
    skipped = 0
    failed = 0
    for speaker, text, _sources in rows:
        speaker_id = cfg["speakers"][speaker]["id"]
        voice_id = cfg["speakers"][speaker]["voice_id"]
        digest = line_hash(speaker, text)
        rel = f"{speaker_id}/{digest}.mp3"
        path = OUT_DIR / rel
        key = line_key(speaker, text)
        if path.exists() and not args.force:
            manifest[key] = f"res://assets/voices/{rel}"
            skipped += 1
            continue
        if args.limit and generated >= args.limit:
            break
        print(f"TTS [{speaker}] {digest}…")
        try:
            synthesize(
                api_key,
                voice_id,
                text,
                cfg["model_id"],
                cfg["voice_settings"],
                path,
            )
            manifest[key] = f"res://assets/voices/{rel}"
            generated += 1
            time.sleep(0.35)
        except Exception as error:  # noqa: BLE001 — report and continue
            failed += 1
            print(f"  FAIL: {error}", file=sys.stderr)
            message = str(error)
            if "payment_required" in message or "paid_plan_required" in message:
                print(
                    "Library/professional voices need API credits on this account.\n"
                    "Add ~$5 at https://elevenlabs.io/app/subscription/api then re-run.",
                    file=sys.stderr,
                )
                break

    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"done: generated={generated} skipped={skipped} failed={failed} manifest={len(manifest)}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
