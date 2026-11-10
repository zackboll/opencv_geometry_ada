#!/usr/bin/env python3
"""Release-backed migration envelope. Execute only from the selected base."""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import re
import shlex
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
    """Example implementation, NOT the authorization authority.

    The envelope below checks bounded commands and the separate production
    campaign checks their actual effects. Comments/layout are not policy.
    """
    reviewed = reviewed.replace("cp docs/index.html _site/index.html\n", "")
    start = reviewed.index("# Presentation: theme metadata,")
    end = reviewed.index("# Declaration, overload and member documentation coverage", start)
    return reviewed[:start] + STAGING + '''# The independent policy workflow supplies the verified official wheel environment.
"$python" -m ada_gnatdoc_enhancer inventory --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --dry-run --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer verify --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" scripts/validate_docs.py _site --core "$core"
''' + reviewed[end:]


PUBLIC = ("opencv-geometry.ads", "opencv-geometry-subdiv2d.ads")
STAGING = '''# Generated build input: recreate exactly the two public specifications.
test ! -L "$root/qualification-public"
rm -rf -- "$root/qualification-public"
mkdir "$root/qualification-public"
for name in opencv-geometry.ads opencv-geometry-subdiv2d.ads; do
    test ! -L "src/$name"
    test -f "src/$name"
    cp -- "src/$name" "qualification-public/$name"
done
'''


def shell_commands(text):
    """Finite shell vocabulary, not execution or a security guess at shell ASTs.

    Keep control operators, expansion spellings and quoting intact. Only blank
    lines, whole-line comments, indentation and continuation layout are free.
    Unknown shell syntax fails closed; no candidate helper/download is allowed.
    """
    require(not any(line.lstrip().startswith("#") and line.endswith("\\")
                    for line in text.splitlines()), "unsafe shell comment continuation")
    require("\x00" not in text and "\r" not in text, "unsafe shell control character")
    text = text.replace("\\\n", " ")
    # Preserve quoted whitespace/expansion exactly. shlex is only a syntax
    # check: it must not erase quote boundaries used by the shell.
    def normalized(line):
        return re.sub(r'''"(?:\\.|[^"\\])*"|'[^']*'|[ \t]+''',
                      lambda m: " " if m[0][0] in " \t" else m[0], line.strip())
    return tuple(normalized(line) for line in text.splitlines()
                 if line.strip() and not line.lstrip().startswith("#"))


def bounded_commands(actual, required, label):
    # shlex validates balanced quotes without discarding shell operators. The
    # literal bounded vocabulary also prevents eval, substitutions and suffixes.
    shlex.split(actual, comments=True)
    observed, expected = shell_commands(actual), shell_commands(required)
    require(observed == expected, label + ": missing, reordered or unauthorized command")


def command_sequence(actual, required, optional, label):
    """Require ordered effects while permitting bounded extra integrity checks."""
    shlex.split(actual, comments=True)
    observed = shell_commands(actual)
    require(all(command in required or command in optional for command in observed),
            label + ": unauthorized command")
    require(tuple(command for command in observed if command not in optional) == required,
            label + ": missing or reordered command")


def generator_contract(policy, candidate):
    """Named native gates plus a bounded integration program, not file equality.

    Native acquisition/toolchain/Core/ratchets retain the reviewed commands.
    The replaceable integration region has its own finite capabilities. Actual
    staging, pristine input, dry-run, output and idempotence are checked again
    from an independent checkout; passing this syntax check is not approval.
    """
    reviewed = regular(policy / "scripts/generate_docs.sh").decode()
    actual = regular(candidate / "scripts/generate_docs.sh").decode()
    start = reviewed.index("# Presentation: theme metadata,")
    end = reviewed.index("# Declaration, overload and member documentation coverage", start)
    native = reviewed[:start].replace("cp docs/index.html _site/index.html\n", "")
    commands = shell_commands(actual)
    prefix, suffix = shell_commands(native), shell_commands(reviewed[end:])
    require(commands[:len(prefix)] == prefix,
            "production generator native/toolchain/Core/warning gates differ")
    require(commands[-len(suffix):] == suffix,
            "production generator coverage/zero-gap gates differ")
    middle = commands[len(prefix):-len(suffix)]
    enhancement = '''
"$python" -m ada_gnatdoc_enhancer inventory --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --dry-run --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer enhance --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" -m ada_gnatdoc_enhancer verify --config docs/gnatdoc-enhancer.toml --source-root . --site _site
"$python" scripts/validate_docs.py _site --core "$core"
'''
    # Extra byte checks are capabilities, not arbitrary shell snippets. This
    # admits materially different staging implementations without authorizing
    # a new candidate helper or weakening the independent staging/output gate.
    command_sequence("\n".join(middle), shell_commands(STAGING + enhancement), {
        'cmp -- "src/$name" "qualification-public/$name"',
        'test -f "qualification-public/$name"',
        'test ! -L "qualification-public/$name"',
    }, "production generator integration")


def workflow_contract(reviewed, actual):
    """Keep all security structure; validate only three bounded run programs.

    YAML outside those bodies (permissions/events/needs/checkout selection and
    immutable regression jobs) cannot change. Within a body formatting and
    comments are irrelevant, but every critical command must execute in order.
    This needs no candidate-controlled YAML parser or additional dependency.
    """
    def extract(text):
        bodies = {}
        for name in STEP_BODIES:
            marker = "      - name: " + name + "\n"
            require(text.count(marker) == 1, "documentation workflow step identity differs")
            start = text.index(marker) + len(marker)
            end = text.find("      - name:", start)
            require(end != -1 and text[start:end].startswith("        run: |\n"),
                    "documentation workflow step settings differ")
            body = text[start + len("        run: |\n"):end]
            require(all(not line.strip() or line.startswith("          ")
                        for line in body.splitlines()), "documentation workflow body escapes run")
            bodies[name] = body
            text = text[:start] + "        run: |\n          POLICY_BODY\n" + text[end:]
        return text, bodies
    skeleton, bodies = extract(actual)
    expected, _ = extract(migration_workflow(reviewed))
    require(skeleton == expected, "production documentation workflow security structure differs")
    for name, required in STEP_BODIES.items():
        optional = {
            'test ! -L /tmp/' + WHEEL,
            '"$DOC_PYTHON" -m ada_gnatdoc_enhancer inventory --config docs/gnatdoc-enhancer.toml --source-root . --site _site',
            '"$DOC_PYTHON" -m ada_gnatdoc_enhancer verify --config docs/gnatdoc-enhancer.toml --source-root . --site _site',
        } - set(shell_commands(required))
        command_sequence(bodies[name], shell_commands(required), optional,
                         "production documentation workflow " + name)


def staged_public(source):
    """Exact bytes and complete inventory; generated staging is never authority."""
    directory = source / "qualification-public"
    require(directory.is_dir() and not directory.is_symlink(), "unsafe public staging directory")
    require({p.name for p in directory.iterdir()} == set(PUBLIC),
            "unexpected public staging inventory")
    require(not any(n.startswith("qualification-public/") for n in file_set(source)),
            "public staging must not be committed")
    for name in PUBLIC:
        require(regular(directory / name) == regular(source / "src" / name),
                "migration staged source differs: " + name)
    return {name: hashlib.sha256(regular(directory / name)).hexdigest() for name in PUBLIC}


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
    workflow_contract(regular(policy / WORKFLOW).decode(), regular(candidate / WORKFLOW).decode())
    generator_contract(policy, candidate)
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


def validate_local_site(source, site, core):
    """Production validator adapter, never a substitute for publisher validation.

    The manifest is untrusted: native bytes must match the independently
    derived authored contract and source inventory, and every final file must
    equal reconstruction. Live publisher authentication remains mandatory in
    validate_migration_site from the separately selected checkout.
    """
    import shutil
    from compare_shared_gnatdoc_geometry import file_hashes
    from additive_gnatdoc_policy import current_output, inventory, EVIDENCE
    from ada_gnatdoc_enhancer.config import load
    from ada_gnatdoc_enhancer.pipeline import enhance, verify
    staged_public(source)
    # This is a policy-owned set of source/native identities, not candidate URLs.
    published = json.loads(regular(ROOT / "docs/evidence/geometry-gnatdoc-003r1/referenced-types.json"))
    configuration = load(source, "docs/gnatdoc-enhancer.toml")
    with tempfile.TemporaryDirectory(prefix="geometry-local-validation-") as folder:
        pristine = Path(folder) / "native"
        (pristine / "api").mkdir(parents=True)
        manifest = json.loads(regular(site / "api/presentation.json"))
        for name, content in manifest["original_api_html"].items():
            require(name.startswith("api/") and Path(name).name == name[4:]
                    and name.endswith(".html"), "unsafe native manifest filename")
            (pristine / name).write_text(content)
        shutil.copyfile(site / "api/gnatdoc.css", pristine / "api/gnatdoc.css")
        authored, expected = direct_configuration(source, pristine, published)
        require(regular(source / "docs/gnatdoc-authored.json") == authored,
                "migration authored contract differs")
        require(tomllib.loads(regular(source / "docs/gnatdoc-enhancer.toml").decode()) == expected,
                "migration configuration is not the finite direct-link policy")
        verify(configuration, site)
        reconstructed = Path(folder) / "reconstructed"
        shutil.copytree(pristine, reconstructed)
        enhance(configuration, reconstructed)
        require(file_hashes(site) == file_hashes(reconstructed),
                "migration output differs from independent native reconstruction")
        core_types = json.loads(regular(ROOT / EVIDENCE / "core-0.5.0-types.json"))
        # Check Core source bytes even at this local, non-publisher gate.
        from qualify_shared_gnatdoc_shadow import check_files, CORE
        require(git(core, "rev-parse", "HEAD").decode().strip() == CORE,
                "Core source release differs")
        core_spec = json.loads(regular(ROOT / EVIDENCE / "core-0.5.0-input.json"))
        check_files(core, core_spec["source_sha256"])
        comparison = current_output(source, pristine, site, core_types, published)
        count = native_output(source, pristine, site)
        return {"packages": 2, "pages": len(list(site.rglob("*.html"))),
                "sections": count, "subprograms": sum(
                    row["kind"] in ("function", "procedure")
                    for rows in inventory(source).values()
                    for row in rows), "comparison": comparison}


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
        staged_public(source)
        from ada_gnatdoc_enhancer.config import load
        from ada_gnatdoc_enhancer.pipeline import enhance, verify
        configuration = load(source, "docs/gnatdoc-enhancer.toml")
        reconstructed = work / "site"
        shutil.copytree(pristine, reconstructed)
        from compare_shared_gnatdoc_geometry import file_hashes
        original = file_hashes(pristine)
        enhance(configuration, reconstructed, dry_run=True)
        require(file_hashes(reconstructed) == original, "dry-run changed pristine native input")
        enhance(configuration, reconstructed)
        require(file_hashes(site) == file_hashes(reconstructed),
                "migration output differs from independent native reconstruction")
        verify(configuration, site)
        state = file_hashes(site)
        enhance(configuration, site)
        require(file_hashes(site) == state, "production enhancement is not byte-idempotent")
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
    for name in ("source", "pristine", "site", "core", "core-native"):
        parser.add_argument("--" + name, type=Path)
    args = parser.parse_args()
    verify_wheel(args.wheel)
    if args.install:
        subprocess.run([sys.executable, "-m", "pip", "install", "--no-index", "--no-deps",
                        "--only-binary=:all:", "--force-reinstall", str(args.wheel)], check=True)
    print(json.dumps(installed_wheel(args.wheel), sort_keys=True))
    paths = (args.source, args.pristine, args.site, args.core, args.core_native)
    if any(paths):
        require(all(paths) and not args.install, "complete independent validation paths required")
        # Isolated Python deliberately omits script-directory imports. Add only
        # this selected-base directory, never the candidate or its working dir.
        sys.path.insert(0, str(ROOT / "scripts"))
        import os
        os.environ["PRODUCTION_DOC_WHEEL"] = str(args.wheel.absolute())
        result = validate_migration_site(*paths)
        print(json.dumps({"direct_link_validation": "pass", "publisher": result["publisher"]},
                         sort_keys=True))