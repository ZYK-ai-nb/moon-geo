"""Deterministic work-count comparison, not a speed benchmark."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[1]
(root / "work").mkdir(exist_ok=True)
features = []
operations = []
for i in range(16):
    for j in range(16):
        identity = i * 16 + j
        x, y = i - 8, j - 8
        ring = [[x, y], [x + .8, y], [x + .8, y + .8], [x, y + .8], [x, y]]
        features.append({"type": "Feature", "id": identity, "properties": {},
                         "geometry": {"type": "Polygon", "coordinates": [ring]}})
        operations.append({"op": "query", "point": [x + .4, y + .4]})
request = {"regions": {"type": "FeatureCollection", "features": features},
           "operations": operations}
input_path = root / "work/grid-e2e-request.json"
input_path.write_text(json.dumps(request), encoding="utf-8")
result = subprocess.run(["node", "scripts/query_geojson.mjs", str(input_path)], cwd=root,
                        capture_output=True, text=True, encoding="utf-8")
assert result.returncode == 0, result.stderr
report = json.loads(result.stdout)
assert report["ok"] and report["invariant_errors"] == []
assert report["revision"] == 256
assert len(report["results"]) == 256
for identity, actual in enumerate(report["results"]):
    assert actual["ok"] and actual["hits"] == [identity], (identity, actual)
    assert actual["candidates"] == 1
    assert actual["revision"] == 256
    assert len(actual["decisions"]) == 1
    assert actual["decisions"][0]["id"] == identity
    assert actual["decisions"][0]["location"] == "Inside"
summary = {"rectangles": 256, "center_queries": 256, "matching_ids": 256,
           "index_entries_tested": sum(r["entries_tested"] for r in report["results"]),
           "index_nodes_visited": sum(r["nodes_visited"] for r in report["results"]),
           "refined_region_candidates": sum(r["candidates"] for r in report["results"]),
           "brute_force_region_evaluations": 256 * 256,
           "invariant_errors": report["invariant_errors"]}
(root / "work/grid-e2e-report.json").write_text(result.stdout, encoding="utf-8")
(root / "work/grid-e2e-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
