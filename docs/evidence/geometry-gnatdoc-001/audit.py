"""Independently record retrieved release and untouched Geometry inputs."""
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else Path(__file__).resolve().parent
SOURCE = ROOT / "enhancer-release-git"
sys.path.insert(0, str(SOURCE / "scripts"))
from check_distributions import audit, wheel_files, sdist_files


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def git(*args):
    return subprocess.check_output(["git", "-C", str(SOURCE), *args])


def files(root):
    return {p.relative_to(root).as_posix(): {"bytes": p.stat().st_size,
                                            "sha256": sha(p.read_bytes())}
            for p in sorted(root.rglob("*")) if p.is_file()}


release = ROOT / "release"
provenance = json.loads((release / "release-provenance.json").read_bytes())
published = json.loads((release / "release.json").read_bytes())
assert published["tagName"] == "v0.1.5"
assert not published["isDraft"] and not published["isPrerelease"]
assert git("rev-parse", "HEAD").decode().strip() == provenance["expected_source_commit"]
assert git("rev-parse", "HEAD^{tree}").decode().strip() == provenance["expected_source_tree"]
tracked = git("ls-tree", "-r", "--name-only", "HEAD").decode().splitlines()
assert set(tracked) == set(provenance["source_files"])
for name in tracked:
    data = git("show", "HEAD:" + name)
    expected = provenance["source_files"][name]
    assert sha(data) == expected["sha256"] and len(data) == expected["bytes"], name
    assert git("rev-parse", "HEAD:" + name).decode().strip() == expected["git_blob"], name
wheel = release / "ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl"
sdist = release / "ada_gnatdoc_enhancer-0.1.5.tar.gz"
# This audit does not claim an independent rebuild: compare the official wheel
# and sdist to the independently retrieved Git source, including wheel RECORD.
content_audit = audit(SOURCE, wheel, sdist, wheel)
for label, path, members in (("wheel", wheel, wheel_files(wheel)),
                             ("sdist", sdist, sdist_files(sdist))):
    expected = provenance["archives"][label]
    assert sha(path.read_bytes()) == expected["sha256"]
    assert path.stat().st_size == expected["bytes"]
    actual = {n: {"bytes": len(data), "sha256": sha(data)} for n, data in members.items()}
    recorded = expected["members"]
    if label == "sdist":
        prefix = "ada_gnatdoc_enhancer-0.1.5/"
        recorded = {n.removeprefix(prefix): v for n, v in recorded.items()}
    assert actual == recorded, label
dist = importlib.metadata.distribution("ada-gnatdoc-enhancer")
assert dist.version == "0.1.5"
direct = json.loads(dist.read_text("direct_url.json"))
assert not direct.get("dir_info", {}).get("editable")
assert direct["archive_info"]["hashes"]["sha256"] == sha(wheel.read_bytes())
for name, data in wheel_files(wheel).items():
    if name.startswith("ada_gnatdoc_enhancer/"):
        assert Path(dist.locate_file(name)).read_bytes() == data, name
write("release-verification.json", {
    "release": published, "source_commit": provenance["expected_source_commit"],
    "source_tree": provenance["expected_source_tree"],
    "assets": files(release), "source_files_verified": len(tracked),
    "archive_members_match_provenance": True, "wheel_record_verified": True,
    "wheel_sdist_modules_match_git": True, "installed_modules_match_wheel": True,
    "installed_distribution": dist.version, "installed_direct_url": direct,
    "independent_sdist_rebuild_performed": False,
    "provenance_publication_authorized": provenance["publication_authorized"],
    "publication_authority": "GitHub published non-draft non-prerelease release, not provenance flag",
})
sys.path.insert(0, str(ROOT / "policy-main/scripts"))
from investigate_shared_gnatdoc_types import sections
from check_doc_coverage import check_site
from enhance_gnatdoc_navigation import entries
from additive_gnatdoc_policy import inventory

native = sections(ROOT / "baseline/pristine")
site = sections(ROOT / "baseline/site")
assert native.keys() == site.keys()
assert all(native[key][2].text == site[key][2].text for key in native)
coverage, missing, errors = check_site(ROOT / "baseline/site", ROOT / "policy-main")
assert not missing and not errors
write("baseline-files.json", {"site": files(ROOT / "baseline/site"),
                              "pristine": files(ROOT / "baseline/pristine")})
write("baseline-declarations.json", {
    "packages": sorted({p for p, _ in native}),
    "native_declarations": len(native), "documented_items": len(coverage),
    "source_declarations": inventory(ROOT / "policy-main"),
    "declarations": [{"package": p, "anchor": a, "page": page, "name": name,
                       "text": snippet.text, "links": site[p, a][2].links}
                     for (p, a), (page, name, snippet) in sorted(native.items())],
    "navigation": entries(ROOT / "baseline/site/api", ROOT / "policy-main/src",
                           ROOT / "policy-main/docs/api-categories.json"),
})
print("Release source/archive/installed identities verified; baseline inventories recorded")