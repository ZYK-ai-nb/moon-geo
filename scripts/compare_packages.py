"""Run fixed-version package APIs on shared geometry/index tasks.

Downloads upstream snapshots into ignored work/ and never edits their sources.
This checks the tested API paths, not overall correctness or speed rankings.
"""
from pathlib import Path
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "kit": ("cn-xjr/moongeokit", "0300c9cd7600c255011ddae96c9f7d929679e18a"),
    "rbush": ("tc-adventureking/moon-rbush", "ed1ed14457b4b1965c5666b819d49a1f1c5acabb"),
    "geometry": ("walkzzz/moon-geometry", "2b59b8b953ecf8764ef6009dc2f7697f2eec539a"),
}


def snapshot(folder, repository, commit):
    data = urllib.request.urlopen(f"https://api.github.com/repos/{repository}/zipball/{commit}", timeout=60).read()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for info in archive.infolist():
            parts = Path(info.filename).parts[1:]
            if not parts or info.is_dir():
                continue
            target = folder.joinpath(*parts).resolve()
            if not target.is_relative_to(folder.resolve()):
                raise ValueError("unsafe archive path")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(info))


def main():
    # A separate toolchain can be selected without changing the user's installation.
    if len(sys.argv) == 3 and sys.argv[1] == "--moon-home":
        toolchain = Path(sys.argv[2]).resolve()
        os.environ["MOON_HOME"] = str(toolchain)
        os.environ["PATH"] = str(toolchain / "bin") + os.pathsep + os.environ["PATH"]
    elif len(sys.argv) != 1:
        raise SystemExit("Usage: python scripts/compare_packages.py [--moon-home PATH]")
    work = ROOT / "work"
    work.mkdir(exist_ok=True)
    workspace = Path(tempfile.mkdtemp(prefix="package-comparison-", dir=work))
    for name, (repository, commit) in SOURCES.items():
        snapshot(workspace / name, repository, commit)
    ignore = shutil.ignore_patterns(".git", "_build", "work", "deliverables", ".mooncakes", "__pycache__")
    shutil.copytree(ROOT, workspace / "geo", ignore=ignore)
    consumer = workspace / "consumer"
    consumer.mkdir()
    (workspace / "moon.work").write_text('members = ["geo", "kit", "rbush", "geometry", "consumer"]\n', encoding="utf-8")
    # Local workspaces select the fixed snapshots, preserving upstream module names.
    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "moon.mod").read_text(encoding="utf-8"), re.M).group(1)
    (consumer / "moon.mod").write_text(f'name = "test/moongeo-comparison"\nimport {{ "ZYK-ai-nb/moon-geo@{version}", "cn-xjr/moongeokit@0.3.0", "tc-adventureking/rbush@0.1.0", "walkzzz/moon-geometry@0.252.0" }}\n', encoding="utf-8")
    (consumer / "moon.pkg").write_text('import { "ZYK-ai-nb/moon-geo" @geo, "cn-xjr/moongeokit" @kit, "tc-adventureking/rbush" @rb, "walkzzz/moon-geometry/base/core" @mgcore, "walkzzz/moon-geometry/geometry/polygon_holes" @mgholes, "walkzzz/moon-geometry/io/geojson_io" @mgjson }\npkgtype(kind: "executable")\n', encoding="utf-8")
    program = (ROOT / "testdata/comparison/main.mbt").read_text(encoding="utf-8")
    (consumer / "main.mbt").write_text(program, encoding="utf-8")
    result = subprocess.run(["moon", "run", "consumer", "--target", "js"], cwd=workspace, text=True,
                            encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    log = work / "validation"
    log.mkdir(exist_ok=True)
    (log / "package-comparison.log").write_text(result.stdout + "\n" + result.stderr, encoding="utf-8")
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)
    observed = json.loads(result.stdout)
    assert observed["grid_queries_matched"] == 256
    assert observed["delete_then_query_matched"]
    assert observed["hole_workflow_matched"]
    assert observed["moon_geometry_hole_queries_matched"] == 3
    assert observed["moon_geometry_geojson_polygon_parsed"]
    assert observed["geokit_direction"] == 0 and observed["moongeo_direction"] == -1
    assert observed["far_insert_moongeo"] and observed["far_insert_rbush"]
    assert not observed["far_insert_geokit_fixed_grid"]
    assert observed["far_insert_geokit_linear"]
    version = subprocess.check_output(["moon", "version", "--all"], env=os.environ, text=True, encoding="utf-8")
    report = {"snapshots": SOURCES, "target": "js", "toolchain": version, "observed": observed,
              "scope": "API-level shared inputs. Hole handling uses application glue for MoonGeoKit. RBush is tested only for index tasks. No timing or full-feature ranking.",
              "workspace": str(workspace)}
    (log / "package-comparison.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(observed, indent=2))


if __name__ == "__main__":
    main()
