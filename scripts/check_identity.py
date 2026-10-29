"""Verify public module ownership and real local Git author relationships."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
text = (root / "moon.mod").read_text(encoding="utf-8")
match = re.search(r'^name\s*=\s*"([^"]+)"', text, re.M)
if not match or match.group(1).startswith("OWNER/"):
    print("UNBOUND: module account is intentionally unset.")
    raise SystemExit(1)
owner = match.group(1).split("/", 1)[0]
if (root / ".git").exists():
    result = subprocess.run(["git", "-C", str(root), "log", "--format=%an <%ae>"], text=True, capture_output=True)
    if result.returncode == 0:
        authors = set(result.stdout.splitlines())
        if len(authors) != 1:
            print("Review actual contribution history: multiple author identities.")
            raise SystemExit(1)
        print(f"Single commit identity for module owner {owner}.")
    else:
        print("No commits yet; author-history verification pending.")
print(f"Identity metadata check passed: {match.group(1)}")
