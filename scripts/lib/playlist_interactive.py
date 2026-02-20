#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class PlaylistItem:
    index: int
    path: Path
    basename: str
    numeric_prefix: int
    alpha_key: str
    is_timer: bool
    enabled: bool = True
    override_hhmmss: str | None = None


def discover_items(sketch_root: Path) -> list[PlaylistItem]:
    items: list[PlaylistItem] = []
    for p in sorted(sketch_root.glob("*.ino")):
        stem = p.stem
        numeric_prefix = 999999
        alpha_key = stem
        m = re.match(r"^(\d+)_(.+)$", stem)
        if m:
            numeric_prefix = int(m.group(1))
            alpha_key = m.group(2)
        items.append(
            PlaylistItem(
                index=0,
                path=p.resolve(),
                basename=p.name,
                numeric_prefix=numeric_prefix,
                alpha_key=alpha_key,
                is_timer=("timer" in stem.lower()),
            )
        )
    items.sort(key=lambda it: (it.numeric_prefix, it.alpha_key, str(it.path)))
    for i, it in enumerate(items, start=1):
        it.index = i
    return items


def ask_yes_no(prompt: str, default_yes: bool = True) -> bool:
    suffix = "[Y/n]" if default_yes else "[y/N]"
    while True:
        raw = input(f"{prompt} {suffix} ").strip().lower()
        if not raw:
            return default_yes
        if raw in {"y", "yes"}:
            return True
        if raw in {"n", "no"}:
            return False
        print("Please answer y or n.")


def parse_remove_indices(raw: str, max_index: int) -> list[int]:
    out: list[int] = []
    parts = [p.strip() for p in raw.split(",") if p.strip()]
    for p in parts:
        if not p.isdigit():
            raise ValueError(f"invalid index '{p}'")
        idx = int(p)
        if idx < 1 or idx > max_index:
            raise ValueError(f"index out of range '{idx}'")
        out.append(idx)
    return sorted(set(out))


def is_valid_hhmmss(v: str) -> bool:
    if not re.fullmatch(r"\d{6}", v):
        return False
    mm = int(v[2:4])
    ss = int(v[4:6])
    return mm <= 59 and ss <= 59


def hhmmss_to_seconds(v: str) -> int:
    hh = int(v[0:2])
    mm = int(v[2:4])
    ss = int(v[4:6])
    return hh * 3600 + mm * 60 + ss


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: playlist_interactive.py <sketch_root>", file=sys.stderr)
        return 2

    sketch_root = Path(sys.argv[1]).expanduser()
    if not sketch_root.is_dir():
        print(f"[interactive] sketch root not found: {sketch_root}", file=sys.stderr)
        return 2

    items = discover_items(sketch_root)
    if not items:
        print("[interactive] no .ino files discovered", file=sys.stderr)
        return 2

    print("\nDiscovered sketches:")
    for it in items:
        marker = " (timer)" if it.is_timer else ""
        print(f"  {it.index:>2}. {it.basename}{marker}")

    run_all = ask_yes_no("Run all discovered sketches?", default_yes=True)
    if not run_all:
        while True:
            enabled = [it for it in items if it.enabled]
            if not enabled:
                print("You removed all sketches. Keeping previous selection.")
                for it in items:
                    it.enabled = True
                break

            print("\nCurrently enabled:")
            for it in enabled:
                marker = " (timer)" if it.is_timer else ""
                print(f"  {it.index:>2}. {it.basename}{marker}")

            raw = input("Enter index or comma list to remove (e.g. 2 or 2,4): ").strip()
            try:
                to_remove = parse_remove_indices(raw, len(items))
            except ValueError as exc:
                print(f"Invalid input: {exc}")
                continue

            for idx in to_remove:
                items[idx - 1].enabled = False

            if not ask_yes_no("Remove another file?", default_yes=False):
                break

    for it in [x for x in items if x.enabled and x.is_timer]:
        if ask_yes_no(f"Override preconfigured time for {it.basename}?", default_yes=False):
            while True:
                v = input("Enter HHMMSS (example 003000 = 30 minutes): ").strip()
                if is_valid_hhmmss(v):
                    it.override_hhmmss = v
                    break
                print("Invalid HHMMSS. Format must be 6 digits with MM/SS <= 59.")

    # Machine-readable output for shell caller.
    for it in items:
        if it.enabled:
            print(f"SKETCH|{it.path}")
            if it.override_hhmmss:
                print(f"OVERRIDE|{it.basename}|{hhmmss_to_seconds(it.override_hhmmss)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

