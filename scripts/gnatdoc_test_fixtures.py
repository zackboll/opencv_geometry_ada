"""Disposable legacy policy inputs for tests of migration, never production.

Verifier modules still come from the selected candidate. Only test input data
is reset to the immutable pre-migration generator/workflow/configuration state.
"""
from pathlib import Path
import subprocess

LEGACY = "49afc3285d4e5e3d93c0f67cedd93c77eb0ffad3"


def legacy_policy(repository, destination):
    from gnatdoc_migration_policy import CONFIGURATION, WORKFLOW, git, require
    require(not destination.exists(), "legacy fixture destination must be new")
    subprocess.run(["git", "clone", "--quiet", "--shared", str(repository),
                    str(destination)], check=True)
    for name in ("scripts/generate_docs.sh", WORKFLOW):
        (destination / name).write_bytes(git(repository, "show", LEGACY + ":" + name))
    for name in CONFIGURATION:
        (destination / name).unlink(missing_ok=True)
    subprocess.run(["git", "add", "--all"], cwd=destination, check=True)
    subprocess.run(["git", "-c", "user.name=Migration test fixture", "-c",
                    "user.email=fixture@invalid.example", "commit", "--quiet",
                    "--allow-empty", "-m", "Isolated immutable legacy migration inputs"],
                   cwd=destination, check=True)
    return destination


def released(site):
    import json
    path = site / "api/presentation.json"
    return path.is_file() and json.loads(path.read_text()).get("enhancer_version") == "0.1.5"


def release_source(root):
    import os
    if (root / "docs/gnatdoc-enhancer.toml").is_file():
        return root
    preview = os.environ.get("GEOMETRY_MIGRATION_PREVIEW")
    if not preview:
        raise ValueError("released test output requires its real production preview")
    return Path(preview) / "candidate"


def validate_generated(site, root):
    if not released(site):
        from validate_docs import validate
        return validate(site, root)
    from gnatdoc_migration_policy import validate_local_site
    from validate_docs import DocumentationError
    source = release_source(root)
    try:
        return validate_local_site(source, site, source.parent / "core")
    except (ValueError, OSError, KeyError) as error:
        raise DocumentationError("released enhancer integrity: " + str(error)) from error
