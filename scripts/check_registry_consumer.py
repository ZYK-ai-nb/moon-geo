"""Download the released package from Mooncakes and run the README API examples."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="0.1.0")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("expected a numeric semantic version")
    metadata = (ROOT / "moon.mod").read_text(encoding="utf-8")
    module = re.search(r'^name\s*=\s*"([^"]+)"', metadata, re.M).group(1)
    work = ROOT / "work"
    work.mkdir(exist_ok=True)
    consumer = Path(tempfile.mkdtemp(prefix="registry-consumer-", dir=work))
    (consumer / "moon.mod").write_text(
        f'name = "test/moongeo-registry-consumer"\nimport {{ "{module}@{args.version}" }}\npreferred_target = "wasm"\n', encoding="utf-8"
    )
    (consumer / "moon.pkg").write_text(f'import {{ "{module}" @geo }} for "test"\n', encoding="utf-8")
    blocks = re.findall(r"```mbt nocheck\s*(.*?)```", (ROOT / "README.mbt.md").read_text(encoding="utf-8"), re.S)
    assert len(blocks) == 3, "expected three README examples"
    (consumer / "consumer_test.mbt").write_text("\n\n".join(blocks) + "\n", encoding="utf-8")
    logs = work / "validation"
    logs.mkdir(exist_ok=True)
    commands = [["moon", "update"]] + [["moon", "test", "--target", target, "--deny-warn"] for target in ("wasm", "wasm-gc", "js")]
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=consumer, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / f"registry-{index}.log").write_text("$ " + " ".join(command) + "\n" + result.stdout, encoding="utf-8")
        print(result.stdout.strip())
        if result.returncode:
            raise SystemExit(result.returncode)
    print(f"Verified published registry package {module}@{args.version}; no local override.")


if __name__ == "__main__":
    main()
