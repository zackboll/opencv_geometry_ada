#!/usr/bin/env python3
"""One-command target configuration, production install and consumer links.

No SDK paths are defaults. Existing OPENCV_CROSS_* overrides remain subject
to cross_geometry's full validation. Only the mkdtemp workspace is removed,
and only after every gate succeeds. External prefixes are never removed.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import cross_geometry as cross


def executable(variable, default):
    selected = os.environ.get(variable) or default
    found = shutil.which(selected)
    cross.require(found, f"{variable} executable unavailable: {selected}")
    # Do not resolve compiler executable symlinks: GPRconfig selects the
    # actual driver basename; runtime_identity resolves its matching GNATLS.
    selected = str(Path(found).absolute())
    os.environ[variable] = selected
    return selected


def prefix_safety(prefix, source, sysroot, core, work=None):
    cross.require(prefix.is_absolute(), "installation prefix must be absolute")
    cross.require(not cross.re.search(r'[\s"\\]', str(prefix)),
                  "unsafe installation prefix")
    cross.require(not any(path.is_symlink() for path in [prefix, *prefix.parents]),
                  "installation prefix is a symlink")
    prefix = prefix.resolve()
    cross.require(prefix != Path("/"), "dedicated installation prefix required")
    for protected in [source, sysroot, *([work] if work else [])]:
        cross.require(not cross.inside(prefix, protected)
                      and not cross.inside(protected, prefix),
                      f"installation prefix overlaps {protected}")
    cross.require(prefix == core or (
        not cross.inside(prefix, core) and not cross.inside(core, prefix)),
        "Core and Geometry prefixes must be separate or identical, not nested")
    for name in ["share/gpr/opencv_geometry.gpr",
                 "share/gpr/opencv_geometry_shim.gpr",
                 "lib/opencv_geometry", "lib/opencv_geometry_shim",
                 "share/doc/opencv_geometry"]:
        path = prefix / name
        cross.require(not path.exists() and not path.is_symlink(),
                      f"refusing to replace existing Geometry content: {path}")
    return prefix


def publish(staged, prefix):
    """Merge a fresh install without replacing *any* existing prefix file.

    GPRinstall runs only against our owned staging prefix, never recursively
    against Core. Preflight the entire publication, then exclusively create
    files; do not follow preexisting symlinks even in parent directories.
    """
    entries = sorted(staged.rglob("*"))
    for source in entries:
        relative = source.relative_to(staged)
        destination = prefix / relative
        cross.require(not source.is_symlink(), f"staged symlink: {source}")
        for parent in [destination, *destination.parents]:
            cross.require(not parent.is_symlink(),
                          f"installation path is a symlink: {parent}")
        cross.require(not destination.exists() or (
            source.is_dir() and destination.is_dir()),
            f"refusing to overwrite installed file: {destination}")
    for source in entries:
        destination = prefix / source.relative_to(staged)
        if source.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("xb") as output, source.open("rb") as input_file:
                shutil.copyfileobj(input_file, output)
            shutil.copymode(source, destination)


def configuration(run, target, ada, cxx, runtime, core, reuse=True):
    override = os.environ.get("OPENCV_CROSS_GPR_CONFIG")
    if override:
        selected = cross.resolved(override)
        cross.check_configuration(selected, target, ada, cxx, runtime)
        return selected
    # Core versions without a durable configuration are fully supported.
    candidates = [core / f"share/gprconfig/{target}.cgpr",
                  core / f"share/gprconfig/opencv_core-{target}.cgpr"]
    for candidate in candidates if reuse else []:
        if candidate.is_file():
            try:
                cross.check_configuration(candidate, target, ada, cxx, runtime)
            except cross.ConfigurationError:
                continue
            cross.resolved(candidate, [core])
            (run / "gprconfig.log").write_text(f"Reused validated Core configuration: {candidate}\n")
            return candidate
    selected = run / "target.cgpr"
    gprconfig = executable("OPENCV_CROSS_GPRCONFIG", "gprconfig")
    cross.logged([gprconfig, "--batch", "--target=" + target,
                  f"--config=Ada,,{runtime},{Path(ada).parent},GNAT",
                  f"--config=C++,,,{Path(cxx).parent},{Path(cxx).name}",
                  "-o", selected], run / "gprconfig.log", dict(os.environ))
    cross.check_configuration(selected, target, ada, cxx, runtime)
    return selected


def consumer_module():
    spec = importlib.util.spec_from_file_location(
        "geometry_consumers", Path(__file__).resolve().parents[1]
        / "tests/cross/qualify_reference_consumers.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Sources and notices must belong to the selected source export.
    module.ROOT = cross.ROOT
    return module


def install(arguments):
    parser = argparse.ArgumentParser(description=__doc__)
    for option, variable in [
            ("target", "OPENCV_CROSS_TARGET"),
            ("runtime", "OPENCV_CROSS_RUNTIME"),
            ("sysroot", "ENV_PREFIX"),
            ("core-prefix", "OPENCV_CROSS_CORE_PREFIX"),
            ("prefix", "OPENCV_CROSS_INSTALL_PREFIX")]:
        parser.add_argument("--" + option, default=os.environ.get(variable),
                            required=not os.environ.get(variable))
    parser.add_argument("--toolchain-bin", required=True)
    parser.add_argument("--source-root", default=os.environ.get("OPENCV_CROSS_SOURCE_ROOT"))
    parser.add_argument("--profile", choices=cross.PROFILES,
                        default=os.environ.get("OPENCV_CROSS_PROFILE", "release"))
    parser.add_argument("--qualify", action="store_true", help=argparse.SUPPRESS)
    options = parser.parse_args(arguments)
    cross.require(cross.re.fullmatch(cross.TARGET_PATTERN, options.target),
                  "not an AArch64 Linux target triplet")
    source = cross.resolved(options.source_root or cross.ROOT)
    if options.source_root:
        os.environ["OPENCV_CROSS_SOURCE_ROOT"] = str(source)
    cross.ROOT = source
    toolchain = cross.resolved(options.toolchain_bin)
    runtime = cross.resolved(options.runtime)
    sysroot = cross.resolved(options.sysroot)
    core = cross.resolved(options.core_prefix)
    prefix = prefix_safety(Path(options.prefix), source, sysroot, core)
    if options.qualify:
        cross.require(not prefix.exists(), "qualification prefix must not exist")
        cross.require(not os.environ.get("OPENCV_CROSS_GPR_CONFIG"),
                      "unset OPENCV_CROSS_GPR_CONFIG to qualify automatic generation")
    for name in cross.HOST_SEARCH:
        cross.require(not os.environ.get(name), f"cross mode requires empty {name}")
    os.environ["PATH"] = str(toolchain) + os.pathsep + os.environ.get("PATH", "")
    ada = executable("OPENCV_CROSS_ADA", str(toolchain / (options.target + "-gcc")))
    cxx = executable("OPENCV_CROSS_CXX", str(toolchain / (options.target + "-g++")))
    for name, default in [("GPRBUILD", "gprbuild"), ("GPRINSTALL", "gprinstall"),
                          ("PKG_CONFIG", "pkg-config")]:
        executable("OPENCV_CROSS_" + name, default)
    os.environ.update(OPENCV_CROSS_TARGET=options.target,
                      OPENCV_CROSS_RUNTIME=str(runtime), ENV_PREFIX=str(sysroot),
                      OPENCV_CROSS_CORE_PREFIX=str(core),
                      OPENCV_CROSS_PROFILE=options.profile)
    if not os.environ.get("PKG_CONFIG_LIBDIR"):
        os.environ["PKG_CONFIG_LIBDIR"] = ":".join(str(path) for path in [
            sysroot / "usr/lib/pkgconfig",
            sysroot / f"usr/lib/{options.target}/pkgconfig",
            sysroot / "usr/lib64/pkgconfig", sysroot / "usr/share/pkgconfig",
            sysroot / "lib/pkgconfig"] if path.is_dir())
    run = Path(tempfile.mkdtemp(prefix="opencv-geometry-cross-")).resolve()
    print(f"Cross-install workspace: {run}", flush=True)
    try:
        prefix_safety(prefix, source, sysroot, core, run)
        selected = configuration(run, options.target, ada, cxx, runtime, core,
                                 reuse=not options.qualify)
        os.environ["OPENCV_CROSS_GPR_CONFIG"] = str(selected)
        settings = cross.validate()  # Full preflight, including core_prefix().
        (run / "preflight.json").write_text(json.dumps(settings, indent=2) + "\n")
        work = run / "build"
        cross.workspace("--build", str(work), settings)
        staged = work / "install"
        cross.require((staged / "share/gpr/opencv_geometry.gpr").is_file(),
                      "missing installed Geometry project")
        cross.require((staged / "share/gpr/opencv_geometry_shim.gpr").is_file(),
                      "missing installed Geometry shim project")
        archive_evidence = []
        for library in ["opencv_geometry", "opencv_geometry_shim"]:
            name = "opencv_geometry_ada" if library == "opencv_geometry" else library
            archive = staged / f"lib/{library}/lib{name}.a"
            archive_evidence.append(cross.elf(archive, settings["readelf"]))
        cross.check_outputs(staged, settings)
        for notice in ["LICENSE", "THIRD_PARTY_NOTICES"]:
            cross.require(cross.digest(staged / "share/doc/opencv_geometry" / notice)
                          == cross.digest(source / notice), "installed notice mismatch")
        config_relative = Path(f"share/gprconfig/opencv_geometry-{options.target}.cgpr")
        durable = staged / config_relative
        durable.parent.mkdir(parents=True)
        shutil.copyfile(selected, durable)
        settings["config"] = str(prefix / config_relative)
        logs_relative = Path(f"share/doc/opencv_geometry/cross-{options.target}")
        logs = staged / logs_relative
        logs.mkdir()
        (logs / "installed-archives-elf.log").write_text("\n".join(archive_evidence))
        evidence = json.loads((work / "cross-evidence.json").read_text())
        evidence.update(config=settings["config"], build_workspace=str(run),
                        core=str(core), geometry_prefix=str(prefix))
        (logs / "cross-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
        for path in [*run.glob("*.log"), *run.glob("*.json"),
                     *work.glob("*.log"), work / "source-revision.txt"]:
            shutil.copyfile(path, logs / path.name)
        publish(staged, prefix)
        # Installed-only independent consumers, using the durable config.
        consumer_module().qualify(settings, core, prefix, run / "consumers",
                                  prefix / logs_relative / "consumers-installed", None)
    except BaseException:
        print(f"Cross-install FAIL; workspace and logs retained: {run}", file=sys.stderr)
        raise
    shutil.rmtree(run)
    if options.qualify:
        qualify(settings, core, prefix, logs_relative, config_relative, run)
    print(f"PASS Geometry build/install and independent Ada/C++ cross-links: {prefix}\n"
          f"Configuration: {prefix / config_relative}\nLogs: {prefix / logs_relative}\n"
          "Target execution: NOT PERFORMED")


def qualify(settings, core, prefix, logs_relative, config_relative, production):
    """Fresh links after production cleanup and from relocated *copies*.

    Never move or change a caller's verified Core installation. Relocated
    links name only the copied installed GPR projects and durable config.
    """
    cross.require(not production.exists(), "production workspace was not cleaned")
    evidence = Path(tempfile.mkdtemp(prefix="opencv-geometry-qualification-"))
    print(f"Qualification evidence retained: {evidence}", flush=True)
    dispositions = evidence / "dispositions.txt"
    try:
        consumers = consumer_module()
        consumers.qualify(settings, core, prefix, evidence / "installed-work",
                          evidence / "installed-logs", None)
        relocated = evidence / "relocated/a-longer-installation-root"
        moved_core = relocated / "core"
        shutil.copytree(core, moved_core, symlinks=True)
        if core == prefix:
            moved_geometry = moved_core
        else:
            moved_geometry = relocated / "geometry"
            shutil.copytree(prefix, moved_geometry, symlinks=True)
        moved = dict(settings, config=str(moved_geometry / config_relative))
        consumers.qualify(moved, moved_core, moved_geometry,
                          evidence / "relocated-work", evidence / "relocated-logs", None)
        dispositions.write_text(
            "PASS automatic GPRconfig, compatible installed Core, fresh production "
            "build/install, ELF/ALI/compiler checks, production cleanup, "
            "fresh installed and relocated Ada/mixed consumer links\n"
            "TARGET_EXECUTION NOT PERFORMED\n")
        shutil.copytree(evidence / "installed-logs", prefix / logs_relative / "qualification-installed")
        shutil.copytree(evidence / "relocated-logs", prefix / logs_relative / "qualification-relocated")
        shutil.copyfile(dispositions, prefix / logs_relative / "dispositions.txt")
    except BaseException:
        dispositions.write_text("FAIL; diagnostic workspaces and logs retained\n")
        print(f"Qualification FAIL; evidence: {evidence}", file=sys.stderr)
        raise
    print(dispositions.read_text(), end="")


if __name__ == "__main__":
    try:
        install(sys.argv[1:])
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(getattr(failure, "returncode", 1))