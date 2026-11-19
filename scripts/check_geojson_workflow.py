"""Verify the real file consumer against Shapely; --fetch recreates public fixtures.

Shapely is development-only. The Node host supplies file I/O to compiled MoonBit.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import random
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REVISION = "ca96624a56bd078437bca8184e78163e5039ad19"
URL = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{REVISION}/geojson/ne_110m_admin_0_countries.geojson"
FIXTURE = ROOT / "testdata/natural-earth-request.json"


def collection(features):
    return {"type": "FeatureCollection", "features": features}


def fetch():
    data = urllib.request.urlopen(URL, timeout=60).read()
    source = json.loads(data)
    wanted = {"South Africa": 101, "Lesotho": 102}
    features = [{"type": "Feature", "id": wanted[f["properties"]["ADMIN"]],
                 "properties": {"name": f["properties"]["ADMIN"]},
                 "geometry": f["geometry"]} for f in source["features"]
                if f["properties"]["ADMIN"] in wanted]
    features.sort(key=lambda f: f["id"])
    assert len(features) == 2
    rng = random.Random(20261119)
    queries = [{"op": "query", "point": [rng.uniform(16, 34), rng.uniform(-36, -21)]}
               for _ in range(400)]
    for feature in features:
        ring = feature["geometry"]["coordinates"][0]
        queries += [{"op": "query", "point": ring[0], "include_boundary": b} for b in (True, False)]
    hole_point = [28.2, -29.6]
    invalid = copy.deepcopy(features[0])
    invalid["geometry"] = {"type": "Polygon", "coordinates": [[[20, -30], [22, -28], [20, -28], [22, -30], [20, -30]]]}
    expanded = copy.deepcopy(features[0])
    expanded["geometry"]["coordinates"] = expanded["geometry"]["coordinates"][:1]
    operations = queries + [
        {"op": "query", "point": hole_point},
        {"op": "replace", "regions": collection([invalid])},
        {"op": "query", "point": hole_point},
        {"op": "replace", "regions": collection([expanded])},
        {"op": "query", "point": hole_point},
        {"op": "remove", "id": 102},
        {"op": "query", "point": hole_point},
        {"op": "insert", "regions": collection([features[1]])},
        {"op": "query", "point": hole_point},
    ]
    FIXTURE.write_text(json.dumps({"regions": collection(features), "operations": operations}, indent=2) + "\n", encoding="utf-8", newline="\n")
    demo_path = ROOT / "testdata/geojson-demo.json"
    demo = {"regions": collection(features), "operations": [operations[400 + 4 + i] for i in (0, 3, 4, 5, 6, 7, 8)]}
    demo_path.write_text(json.dumps(demo, indent=2) + "\n", encoding="utf-8", newline="\n")
    manifest = {"source": URL, "commit": REVISION, "source_sha256": hashlib.sha256(data).hexdigest(),
                "fixture_sha256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
                "demo_sha256": hashlib.sha256(demo_path.read_bytes()).hexdigest(),
                "license": "Public domain", "license_url": "https://www.naturalearthdata.com/about/terms-of-use/",
                "changes": "Retained South Africa and Lesotho geometry. Assigned numeric IDs. Generated probes and artificial update operations.", "seed": 20261119}
    (ROOT / "testdata/natural-earth-source.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("Public-domain source fixture generated.")


def verify():
    from shapely.geometry import Point, shape
    import shapely
    request = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "testdata/natural-earth-source.json").read_text(encoding="utf-8"))
    assert hashlib.sha256(FIXTURE.read_bytes()).hexdigest() == manifest["fixture_sha256"]
    assert hashlib.sha256((ROOT / "testdata/geojson-demo.json").read_bytes()).hexdigest() == manifest["demo_sha256"]
    process = subprocess.run(["node", "scripts/query_geojson.mjs", str(FIXTURE)], cwd=ROOT,
                             capture_output=True, text=True, encoding="utf-8")
    assert process.returncode == 1, process.stderr  # One intentionally invalid update.
    report = json.loads(process.stdout)
    assert report["ok"] and report["invariant_errors"] == [], report
    live = {f["id"]: shape(f["geometry"]) for f in request["regions"]["features"]}
    revision = len(live)
    comparisons = 0
    rejected = 0
    for operation, actual in zip(request["operations"], report["results"], strict=True):
        if operation["op"] == "query":
            p = Point(operation["point"])
            boundary = operation.get("include_boundary", True)
            expected = sorted(i for i, poly in live.items() if (poly.covers(p) if boundary else poly.contains(p)))
            assert actual["ok"] and actual["hits"] == expected, (operation, actual, expected)
            for d in actual["decisions"]:
                poly = live[d["id"]]
                location = "OnBoundary" if poly.boundary.covers(p) else "Inside" if poly.contains(p) else "Outside"
                assert d["location"] == location, (operation, d, location)
            comparisons += 1
        elif operation["op"] == "remove":
            changed = operation["id"] in live
            live.pop(operation["id"], None)
            revision += int(changed)
            assert actual["ok"] and actual["changed"] == changed
        else:
            f = operation["regions"]["features"][0]
            poly = shape(f["geometry"])
            if not poly.is_valid:
                assert not actual["ok"]
                rejected += 1
            else:
                live[f["id"]] = poly
                revision += 1
                assert actual["ok"] and actual["changed"]
        assert actual["revision"] == revision
    assert report["revision"] == revision
    logs = ROOT / "work/validation"
    logs.mkdir(parents=True, exist_ok=True)
    (logs / "geojson-workflow-report.json").write_text(process.stdout, encoding="utf-8")
    demo_run = subprocess.run(["node", "scripts/query_geojson.mjs", "testdata/geojson-demo.json", "work/validation/geojson-demo-result.json"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    assert demo_run.returncode == 0, demo_run.stderr
    demo = json.loads((logs / "geojson-demo-result.json").read_text(encoding="utf-8"))
    assert demo["ok"] and all(r["ok"] for r in demo["results"])
    assert [r["hits"] for r in demo["results"] if "hits" in r] == [[102], [101, 102], [101], [101, 102]]
    print(f"Shapely {shapely.__version__}: {comparisons} queries match; {rejected} invalid update rejected; revisions and index invariants verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    if args.fetch:
        fetch()
    else:
        verify()
