#!/usr/bin/env python3
"""Release-backed migration envelope. Execute only from the selected base."""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.5"
WHEEL = "ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl"
WHEEL_SHA256 = "d712d330f213fc1909a66c47bc2c7e5e15d5ec687222bea3c4922f5243db4247"
WORKFLOW = ".github/workflows/documentation.yml"
CONFIGURATION = frozenset({"docs/gnatdoc-enhancer.toml", "docs/gnatdoc-authored.json"})
TEST_REPAIRS = frozenset({
    "scripts/test_check_doc_coverage.py", "scripts/test_gnatdoc_navigation.py",
    "scripts/test_gnatdoc_navigation_browser.cjs", "scripts/test_shared_gnatdoc_shadow.py",
    "scripts/test_additive_gnatdoc_policy.py",
})
MIGRATION = TEST_REPAIRS | CONFIGURATION | frozenset({
    "scripts/generate_docs.sh", "scripts/validate_docs.py", "scripts/test_validate_docs.py",
    WORKFLOW, "docs/documentation.md",
})

# Only these three step bodies may change. Event selection, preflight, historical
# regression, examples, browser checks, permissions and Pages jobs stay exact.
INSTALL = '''          python3 -m venv .doc-tools/markdown
          .doc-tools/markdown/bin/pip install -r ../build-policy/docs/requirements.txt
          curl --fail --location --output /tmp/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl https://github.com/zackboll/ada-gnatdoc-enhancer/releases/download/v0.1.5/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl
          .doc-tools/markdown/bin/python -I ../build-policy/scripts/gnatdoc_migration_policy.py --wheel /tmp/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl --install
          echo "DOC_PYTHON=$GITHUB_WORKSPACE/geometry/.doc-tools/markdown/bin/python" >> "$GITHUB_ENV"
'''
GENERATE = '''          sh scripts/generate_docs.sh
          "$DOC_PYTHON" -I ../build-policy/scripts/gnatdoc_migration_policy.py --wheel /tmp/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl
'''
DETERMINISM = '''          cp -a _site /tmp/documentation-first
          sh scripts/generate_docs.sh
          diff -r /tmp/documentation-first _site
          "$DOC_PYTHON" -m ada_gnatdoc_enhancer enhance --config docs/gnatdoc-enhancer.toml --source-root . --site _site
          "$DOC_PYTHON" -m ada_gnatdoc_enhancer verify --config docs/gnatdoc-enhancer.toml --source-root . --site _site
          diff -r /tmp/documentation-first _site
          "$DOC_PYTHON" -I ../build-policy/scripts/gnatdoc_migration_policy.py --wheel /tmp/ada_gnatdoc_enhancer-0.1.5-py3-none-any.whl
'''
STEP_BODIES = {
    "Install qualified documentation-only Markdown renderer": INSTALL,
    "Generate and validate public API and guides": GENERATE,
    "Qualify deterministic fresh generation and idempotent enhancement": DETERMINISM,
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def regular(path):
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            "substituted policy input: " + str(path))
    require(path.is_file(), "missing policy input: " + str(path))
    return path.read_bytes()


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def migration_workflow(reviewed):
    """Exact reviewed layout with finite, policy-owned command replacements."""
    for name, body in STEP_BODIES.items():
        marker = "      - name: " + name + "\n"
        require(reviewed.count(marker) == 1, "documentation step identity differs: " + name)
        start = reviewed.index(marker) + len(marker)
        end = reviewed.find("      - name:", start)
        require(end != -1, "documentation step boundary missing: " + name)
        step = reviewed[start:end]
        require(step.startswith("        run:"), "unexpected documentation step settings: " + name)
        reviewed = reviewed[:start] + "        run: |\n" + body + reviewed[end:]
    return reviewed


def migration_generator(reviewed):
    """Replace only the duplicated enhancement block; preserve native gates."""
    start = reviewed.index("# Presentation: theme metadata,")
    end = reviewed.index("# Declaration, overload and member documentation coverage", start)
    return reviewed[:start] + '''# The independent policy workflow supplies the verified official wheel environment.
"$python" -m ada_gnatdoc_enhancer inventory --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --dry-run --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer verify --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" scripts/validate_docs.py _site --core "$core"
''' + reviewed[end:]


def file_set(root):
    return set(git(root, "ls-files").decode().splitlines())


def changes(policy, candidate):
    """Compare bytes and inventories, not a candidate-supplied change manifest."""
    before, after = file_set(policy), file_set(candidate)
    # Include untracked executable/config substitutions, but not build output.
    for prefix in ("scripts", ".github/workflows"):
        after |= {p.relative_to(candidate).as_posix() for p in (candidate / prefix).rglob("*")
                  if p.is_file() and "__pycache__" not in p.parts}
    after |= {n for n in CONFIGURATION if (candidate / n).exists()}
    return {n for n in before | after if n not in before or n not in after or
            regular(policy / n) != regular(candidate / n)}


def verify_current_commit(source, revision):
    require(git(source, "rev-parse", "HEAD").decode().strip() == revision,
            "stale/substituted candidate commit")


def envelope(policy, candidate, qualification_pins=False):
    changed = changes(policy, candidate)
    if qualification_pins:
        # validate_gnatdoc_inputs must check the exact disposable pin suffixes.
        from validate_gnatdoc_inputs import validate
        validate(candidate, policy, qualification_pins=True)
        changed -= {"alire.toml", "tests/alire.toml"}
    protected = {n for n in changed if n.startswith(("scripts/", ".github/workflows/"))
                 or n in CONFIGURATION}
    require(protected <= MIGRATION,
            "unapproved migration verification files: " + repr(sorted(protected - MIGRATION)))
    if not protected:
        return set()
    # Repairs are a separate, contemporary-test-only task, not migration approval.
    if protected <= TEST_REPAIRS:
        require(changed <= TEST_REPAIRS | {"docs/documentation.md"},
                "test repair includes unrelated changes")
        return protected
    require(changed <= MIGRATION,
            "migration includes unrelated files: " + repr(sorted(changed - MIGRATION)))
    require(CONFIGURATION <= file_set(candidate), "migration configuration missing")
    require(regular(candidate / WORKFLOW).decode() ==
            migration_workflow(regular(policy / WORKFLOW).decode()),
            "production documentation workflow is not the release-backed template")
    require(regular(candidate / "scripts/generate_docs.sh").decode() ==
            migration_generator(regular(policy / "scripts/generate_docs.sh").decode()),
            "production generator is not the release-backed template")
    for name in CONFIGURATION:
        regular(candidate / name)
    return protected


def verify_wheel(path):
    data = regular(path)
    require(path.name == WHEEL and hashlib.sha256(data).hexdigest() == WHEEL_SHA256,
            "official v0.1.5 wheel identity differs")
    # The fixed digest authenticates all archive bytes, not just its version field.
    return data


def native_output(source, pristine, site):
    """Source-owned declaration identities and native anchors, not output claims."""
    from additive_gnatdoc_policy import inventory
    from investigate_shared_gnatdoc_types import sections
    from link_gnatdoc_types import Sources
    before, after = sections(pristine), sections(site)
    require(before.keys() == after.keys(), "native declaration/anchor inventory differs")
    require(len(before) == sum(map(len, inventory(source).values())),
            "source/native declaration inventory differs")
    sources = Sources(source / "src")
    matched = {owner: set() for owner in sources.packages}
    for key, (page, name, snippet) in before.items():
        rendered_page, rendered_name, rendered = after[key]
        require((page, name, snippet.text) == (rendered_page, rendered_name, rendered.text),
                "native declaration profile changed: " + repr(key))
        declaration = sources.packages[key[0].lower()].match(rendered.text)
        identity = declaration["signature"]
        require(identity not in matched[key[0].lower()], "duplicate source/native declaration")
        matched[key[0].lower()].add(identity)
    require(all(len(matched[owner]) == len(package.top) for owner, package in sources.packages.items()),
            "missing source/native declaration")
    return len(before)


def installed_wheel(path):
    verify_wheel(path)
    distribution = importlib.metadata.distribution("ada-gnatdoc-enhancer")
    require(distribution.version == VERSION, "installed enhancer version differs")
    direct = json.loads(distribution.read_text("direct_url.json") or "{}")
    require(direct.get("archive_info", {}).get("hashes", {}).get("sha256") == WHEEL_SHA256
            and "dir_info" not in direct and "vcs_info" not in direct,
            "installed enhancer is not the official wheel")
    with zipfile.ZipFile(path) as archive:
        expected = {n: archive.read(n) for n in archive.namelist()
                    if n.startswith("ada_gnatdoc_enhancer/") and not n.endswith("/")}
    package = Path(distribution.locate_file("ada_gnatdoc_enhancer"))
    actual = {p.relative_to(package.parent).as_posix(): regular(p) for p in package.rglob("*")
              if p.is_file() and "__pycache__" not in p.parts}
    require(actual == expected, "installed enhancer module/asset substitution")
    return {"version": VERSION, "wheel_sha256": WHEEL_SHA256}


def direct_configuration(source, pristine, published):
    """Finite policy-owned configuration; candidate URLs cannot grant permission."""
    from additive_gnatdoc_policy import authored_contract
    from qualify_current_core import REFERENCED_TYPES
    require(set(published) == REFERENCED_TYPES, "unqualified Core type inventory")
    authored, shadow = authored_contract(source, pristine)
    config = tomllib.loads(shadow.decode())
    config.pop("external_dependencies")
    config["presentation"].update({
        "external_type_target": "_top",
        "theme_css_source": "docs/assets/gnatdoc-theme.css",
        "theme_css_sha256": hashlib.sha256(regular(ROOT / "docs/assets/gnatdoc-theme.css")).hexdigest(),
    })
    config["guides"]["manifest"] = "docs/gnatdoc-authored.json"
    config["security"]["external_hosts"] = ["github.com", "zackboll.github.io"]
    config["external_types"] = {identity: proof["url"] for identity, proof in sorted(published.items())}
    return authored, config


def validate_migration_site(source, pristine, site, core, core_native, publisher=None):
    """Selected-base validation, never candidate validate_docs.py or output authority.

    Native bytes come from the independently generated input, not presentation.json.
    Reconstruct with the integrity-checked official wheel and finite configuration,
    then independently resolve every occurrence/overload and recheck publication.
    The optional transport is for offline negative tests, not a policy CLI input.
    """
    import os
    import shutil
    from additive_gnatdoc_policy import current_output, coverage, EVIDENCE
    from qualify_current_core import authority, GitHubCore, provenance, verify_publication
    installed_wheel(Path(os.environ["PRODUCTION_DOC_WHEEL"]))
    approved = authority(core, core_native)
    with tempfile.TemporaryDirectory(prefix="geometry-direct-") as folder:
        work = Path(folder)
        publisher = publisher or GitHubCore(work / "witness")
        before = provenance(publisher)
        published, _, _ = verify_publication(publisher, before, approved, work / "publisher")
        authored, expected = direct_configuration(source, pristine, published)
        require(regular(source / "docs/gnatdoc-authored.json") == authored,
                "migration authored contract differs")
        require(tomllib.loads(regular(source / "docs/gnatdoc-enhancer.toml").decode()) == expected,
                "migration configuration is not the finite direct-link policy")
        for name in ("opencv-geometry.ads", "opencv-geometry-subdiv2d.ads"):
            require(regular(source / "qualification-public" / name) == regular(source / "src" / name),
                    "migration staged source differs")
        from ada_gnatdoc_enhancer.config import load
        from ada_gnatdoc_enhancer.pipeline import enhance, verify
        configuration = load(source, "docs/gnatdoc-enhancer.toml")
        reconstructed = work / "site"
        shutil.copytree(pristine, reconstructed)
        enhance(configuration, reconstructed)
        from compare_shared_gnatdoc_geometry import file_hashes
        require(file_hashes(site) == file_hashes(reconstructed),
                "migration output differs from independent native reconstruction")
        verify(configuration, site)
        core_types = json.loads(regular(ROOT / EVIDENCE / "core-0.5.0-types.json"))
        comparison = current_output(source, pristine, site, core_types, published)
        native_output(source, pristine, site)
        coverage(source, site, source / "obj/docs/gnatdoc.log")
        require(before == provenance(publisher), "CORE_DEPLOYMENT_RACE: publication changed during validation")
        return {"comparison": comparison, "publisher": before, "production_enabled": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wheel", type=Path, required=True)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    verify_wheel(args.wheel)
    if args.install:
        subprocess.run([sys.executable, "-m", "pip", "install", "--no-index", "--no-deps",
                        "--only-binary=:all:", "--force-reinstall", str(args.wheel)], check=True)
    print(json.dumps(installed_wheel(args.wheel), sort_keys=True))