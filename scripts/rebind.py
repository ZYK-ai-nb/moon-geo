"""Bind the module and repo-local commit identity; does not push or publish."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("github_id")
    parser.add_argument("email", nargs="?")
    args = parser.parse_args()
    owner = args.github_id
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?", owner) or "--" in owner:
        parser.error("invalid GitHub username")
    email = args.email or f"{owner}@users.noreply.github.com"
    if any(c in email for c in "\r\n\0") or "@" not in email:
        parser.error("invalid commit email")
    metadata_path = ROOT / "moon.mod"
    metadata = metadata_path.read_text(encoding="utf-8")
    module_match = re.search(r'^name\s*=\s*"([^"]+)"', metadata, re.M)
    module = f"{owner}/moon-geo"
    if not module_match or module_match.group(1) not in ("OWNER/moon-geo", module):
        parser.error("module is already bound to another identity")
    repository = f"https://github.com/{owner}/moon-geo"
    repository_match = re.search(r'^repository\s*=\s*"([^"]*)"', metadata, re.M)
    if not repository_match or repository_match.group(1) not in ("", repository):
        parser.error("repository already points elsewhere")
    excluded = {".git", "_build", "work", "deliverables", "validation", "scripts", "__pycache__"}
    changed = 0
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [name for name in dirs if name not in excluded]
        for name in files:
            path = Path(folder) / name
            if path.suffix not in {".mbt", ".mbti", ".pkg", ".mod", ".md"}:
                continue
            if path == ROOT / "docs" / "实施回执.md":
                continue
            text = path.read_text(encoding="utf-8")
            updated = text.replace("OWNER/moon-geo", module)
            if path == metadata_path:
                updated = re.sub(r'^repository\s*=\s*"[^"]*"', f'repository = "{repository}"', updated, flags=re.M)
            if updated != text:
                path.write_text(updated, encoding="utf-8", newline="\n")
                changed += 1
    if (ROOT / ".git").exists():
        for key, value in (("user.name", owner), ("user.email", email)):
            subprocess.run(["git", "-C", str(ROOT), "config", "--local", key, value], check=True)
    print(f"Bound module: {module}; updated files: {changed}; no remote operations performed.")


if __name__ == "__main__":
    main()
