"""Download the released package from Mooncakes and run the README API examples."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    metadata = (ROOT / "moon.mod").read_text(encoding="utf-8")
    current_version = re.search(r'^version\s*=\s*"([^"]+)"', metadata, re.M).group(1)
    parser.add_argument("--version", default=current_version)
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("expected a numeric semantic version")
    module = re.search(r'^name\s*=\s*"([^"]+)"', metadata, re.M).group(1)
    work = ROOT / "work"
    work.mkdir(exist_ok=True)
    consumer = Path(tempfile.mkdtemp(prefix="registry-consumer-", dir=work))
    (consumer / "moon.mod").write_text(
        f'name = "test/moongeo-registry-consumer"\nimport {{ "{module}@{args.version}" }}\npreferred_target = "wasm"\n', encoding="utf-8"
    )
    new_workflow = tuple(map(int, args.version.split("."))) >= (0, 2, 0)
    imports = f'"{module}" @geo'
    if new_workflow:
        imports += f', "{module}/geojson" @gj, "{module}/workflow" @wf, "moonbitlang/core/json"'
    (consumer / "moon.pkg").write_text('import { ' + imports + ' } for "test"\n', encoding="utf-8")
    blocks = re.findall(r"```mbt nocheck\s*(.*?)```", (ROOT / "README.mbt.md").read_text(encoding="utf-8"), re.S)
    assert len(blocks) == 3, "expected three README examples"
    (consumer / "consumer_test.mbt").write_text("\n\n".join(blocks) + "\n", encoding="utf-8")
    if new_workflow:
        demo_text = (ROOT / "testdata/geojson-demo.json").read_text(encoding="utf-8")
        regions = json.dumps(json.loads(demo_text)["regions"])
        test = f'''///|
test "published GeoJSON and workflow exports" {{
  let index = @gj.build_index({json.dumps(regions)})
  assert_eq(index.query_point(@geo.Point::new(28.2, -29.6)).hits, [102])
  let report = @json.parse(@wf.run({json.dumps(demo_text)}))
  guard report is Object(fields) else {{ fail("report object") }}
  assert_eq(fields.get("ok"), Some(Json(true)))
  assert_eq(fields.get("revision"), Some(Json(5)))
  guard fields.get("results") is Some(Array(results)) else {{ fail("results") }}
  let expected : Array[Array[Int32]] = [[102], [101,102], [101], [101,102]]
  for i in 0..<4 {{
    guard results[i * 2] is Object(query) else {{ fail("query result") }}
    assert_eq(query.get("hits"), Some(Json(expected[i])))
  }}
}}
'''
        (consumer / "workflow_test.mbt").write_text(test, encoding="utf-8")
    logs = work / "validation" / f"registry-{args.version}"
    logs.mkdir(exist_ok=True)
    commands = [["moon", "update"]] + [["moon", "test", "--target", target, "--deny-warn"] for target in ("wasm", "wasm-gc", "js")]
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=consumer, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / f"registry-{index}.log").write_text("$ " + " ".join(command) + "\n" + result.stdout, encoding="utf-8")
        print(result.stdout.strip())
        if result.returncode:
            raise SystemExit(result.returncode)
    print(f"Verified published registry package {module}@{args.version}; no local override.")
    if new_workflow:
        released = consumer / ".mooncakes" / module
        result_path = consumer / "workflow-result.json"
        command = ["node", str(released / "scripts/query_geojson.mjs"), str(released / "testdata/geojson-demo.json"), str(result_path)]
        result = subprocess.run(command, cwd=consumer, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (logs / "file-workflow.log").write_text(result.stdout, encoding="utf-8")
        assert result.returncode == 0, result.stdout
        report = json.loads(result_path.read_text(encoding="utf-8"))
        assert report["ok"] and report["invariant_errors"] == []
        assert [r["hits"] for r in report["results"] if "hits" in r] == [[102], [101,102], [101], [101,102]]
        print("Downloaded package's file workflow verified.")
    print(f"Consumer workspace: {consumer}")


if __name__ == "__main__":
    main()
