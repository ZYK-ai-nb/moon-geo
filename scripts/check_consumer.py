"""Test the README snippets from an isolated local consumer; never publish."""
from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    work = ROOT / "work"
    work.mkdir(exist_ok=True)
    workspace = Path(tempfile.mkdtemp(prefix="consumer-", dir=work))
    library = workspace / "library"
    excluded = {"_build", "work", "deliverables", ".git", ".mooncakes", ".moonagent", "__pycache__"}
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [name for name in dirs if name not in excluded]
        for name in files:
            source = Path(folder) / name
            target = library / source.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    metadata = (ROOT / "moon.mod").read_text(encoding="utf-8")
    module = re.search(r'^name\s*=\s*"([^"]+)"', metadata, re.M).group(1)
    version = re.search(r'^version\s*=\s*"([^"]+)"', metadata, re.M).group(1)
    consumer = workspace / "consumer"
    consumer.mkdir()
    (workspace / "moon.work").write_text('members = ["library", "consumer"]\n', encoding="utf-8")
    (consumer / "moon.mod").write_text(
        f'name = "test/moongeo-consumer"\nimport {{ "{module}@{version}" }}\npreferred_target = "wasm"\n', encoding="utf-8"
    )
    (consumer / "moon.pkg").write_text(f'import {{ "{module}" @geo }} for "test"\n', encoding="utf-8")
    blocks = re.findall(r"```mbt nocheck\s*(.*?)```", (ROOT / "README.mbt.md").read_text(encoding="utf-8"), re.S)
    assert len(blocks) == 3, "expected exactly three README examples"
    (consumer / "readme_examples_test.mbt").write_text("\n\n".join(blocks) + "\n", encoding="utf-8")
    logs = work / "validation"
    logs.mkdir(exist_ok=True)
    for backend in ("wasm", "wasm-gc", "js"):
        command = ["moon", "test", "consumer", "--target", backend, "--deny-warn"]
        result = subprocess.run(command, cwd=workspace, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / f"consumer-{backend}.log").write_text("$ " + " ".join(command) + "\n" + result.stdout, encoding="utf-8")
        print(f"consumer {backend}: {result.stdout.strip()}")
        if result.returncode:
            raise SystemExit(result.returncode)
    print("README consumer checks passed; three snippets on three backends.")


if __name__ == "__main__":
    main()
