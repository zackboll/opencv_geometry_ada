#!/usr/bin/env python3
"""Cross-link and inspect the independent installed consumers.

Builds tests/installed_consumers (Ada and mixed Ada/C++) for the target with
the GPR configuration and sysroot recorded by scripts/cross_geometry.py,
against installed Core and Geometry prefixes only, and without any run path
(gprbuild -R). Each executable must be an AArch64 ELF for the target loader,
contain only code from the supplied compilers or the target's own startup
files, have every dependency resolved as the target loader would inside the
sysroot, and need only symbol versions the target defines. The Geometry
prefix must carry the checkout's verified redistribution notices
(tests/installed_consumers/check_notices.sh).

With --emulator, each executable is also run under that user-mode emulator
with the sysroot as its root. That is emulated reference execution, not
target execution.

usage: qualify_reference_consumers.py EVIDENCE_JSON CORE_PREFIX
           GEOMETRY_PREFIX WORK LOGS [--emulator PATH]
"""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "cross", ROOT / "scripts/cross_geometry.py")
cross = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cross)
require = cross.require

PROGRAMS = {"ada_consumer": "installed_geometry_consumer",
            "mixed_consumer": "installed_mixed_consumer"}


def startup_identities(settings):
    """Compiler identities of the startup objects and libraries that a
    target link legitimately adds: the sysroot's C runtime start files and
    the compiler's own support objects."""
    sysroot = Path(settings["sysroot"])
    readelf = settings["readelf"]
    names = ["crt1.o", "crti.o", "crtn.o", "Scrt1.o", "libc_nonshared.a"]
    found = set()
    for name in names:
        for path in sysroot.rglob(name):
            found |= cross.comments(cross.resolved(path, [sysroot]), readelf)
    for name in ["crtbegin.o", "crtend.o", "crtbeginS.o", "crtendS.o",
                 "libgcc.a"]:
        path = cross.run([settings["cxx"], "--sysroot=" + settings["sysroot"],
                          "-print-file-name=" + name])
        if os.path.isabs(path) and os.path.isfile(path):
            found |= cross.comments(path, readelf)
    return found


def qualify(settings, core, geometry, work, logs, emulator):
    sysroot = Path(settings["sysroot"])
    readelf = settings["readelf"]
    sources = ROOT / "tests/installed_consumers"
    require(not work.exists(), f"consumer workspace exists: {work}")
    require(not logs.exists(), f"log directory exists: {logs}")
    for prefix in [core, geometry]:
        require((prefix / "share/gpr").is_dir(),
                f"not an installed prefix: {prefix}")
    work.mkdir(parents=True)
    logs.mkdir(parents=True)
    # The Geometry prefix must carry this checkout's redistribution
    # notices, wherever the prefix currently is.
    notices = subprocess.run(
        ["sh", str(sources / "check_notices.sh"), str(ROOT), str(geometry)],
        capture_output=True, text=True)
    (logs / "notices.log").write_text(notices.stdout + notices.stderr)
    require(notices.returncode == 0,
            f"redistribution notices:\n{notices.stdout}{notices.stderr}")
    for source in sources.iterdir():
        if source.suffix in [".ads", ".adb", ".gpr", ".cpp"]:
            shutil.copy(source, work / source.name)
    env = {key: item for key, item in os.environ.items()
           if key not in cross.HOST_SEARCH}
    env["GPR_PROJECT_PATH"] = f"{core}/share/gpr:{geometry}/share/gpr"
    sysroot_switch = "--sysroot=" + str(sysroot)
    allowed = set(settings["identities"]) | startup_identities(settings)
    summary = {}
    for project, program in PROGRAMS.items():
        log = logs / f"{project}-build.log"
        cross.logged(
            [settings["gprbuild"], "--config=" + settings["config"], "-P",
             work / f"{project}.gpr", "-p", "-v", "-R",
             "-XCONSUMER_CXX_FROM=configuration",
              "-XCONSUMER_OPENCV_BACKEND=-lopencv_"
              + settings["native_geometry_module"],
             "-XCONSUMER_OPENCV_INCLUDE=-I" + settings["include"],
              "-cargs:Ada", sysroot_switch, "-cargs:C++", sysroot_switch,
              "-largs", sysroot_switch, "-Wl,-t",
              *["-Wl,-rpath-link," + str(directory) for directory in
                cross.loader_directories(sysroot, settings["target"])]],
            log, env, cwd=work)
        compiled = cross.check_trace(log, settings)
        cross.check_outputs(work, settings)
        trace = log.read_text()
        for archive in [
                core / "lib/opencv_core/libopencv_core_ada.a",
                core / "lib/opencv_core_shim/libopencv_core_shim.a",
                geometry / "lib/opencv_geometry/libopencv_geometry_ada.a",
                geometry / "lib/opencv_geometry_shim/"
                "libopencv_geometry_shim.a"]:
            require(str(archive) in trace,
                    f"{project} did not link the installed {archive.name}")
        executable = work / "bin" / program
        header = cross.elf(executable, readelf)
        program_headers = cross.run([readelf, "-l", executable])
        interpreter = re.search(
            r"Requesting program interpreter: ([^\]]+)\]", program_headers)
        require(interpreter, f"{program} has no program interpreter")
        cross.resolved(sysroot / interpreter[1].lstrip("/"), [sysroot])
        dynamic = cross.run([readelf, "-d", executable])
        require(not re.search(r"\((?:RPATH|RUNPATH)\)", dynamic),
                f"{program} has a run path")
        identities = cross.comments(executable, readelf)
        require(identities and identities <= allowed,
                f"{program} contains code from another compiler: "
                f"{sorted(identities - allowed)}")
        closure = cross.dependency_closure(
            [executable], sysroot, readelf, settings["target"], [work])
        versions = cross.check_versions(closure, readelf)
        needed = re.findall(r"\(NEEDED\).*\[([^\]]+)\]", dynamic)
        for name in ["libopencv_core.so.", "libstdc++.so.6", "libc.so.6"]:
            require(any(item.startswith(name) for item in needed),
                    f"{program} does not need {name}")
        backend = "libopencv_" + settings["native_geometry_module"] + ".so."
        require(any(item.startswith(backend) for item in needed),
                f"{program} does not need {backend}")
        (logs / f"{program}-elf.log").write_text(
            header + program_headers + dynamic
            + cross.run([readelf, "-V", executable]))
        result = dict(compilations=compiled, interpreter=interpreter[1],
                      needed=needed, identities=sorted(identities),
                      closure=len(closure), symbol_versions=versions,
                      sha256=cross.digest(executable),
                      emulated_execution="NOT RUN")
        if emulator:
            run = subprocess.run([emulator, "-L", str(sysroot), executable],
                                 capture_output=True, text=True, env=env)
            (logs / f"{program}-emulated.log").write_text(
                run.stdout + run.stderr)
            require(run.returncode == 0
                    and re.search(r"^consumer PASS", run.stdout, re.M)
                    and not re.search(r"^FAIL", run.stdout, re.M),
                    f"{program} failed under emulation:\n{run.stdout}"
                    f"{run.stderr}")
            result["emulated_execution"] = "PASS"
        summary[program] = result
    (logs / "consumers.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n")
    return summary


def main(arguments):
    emulator = None
    if "--emulator" in arguments:
        index = arguments.index("--emulator")
        emulator = arguments[index + 1]
        del arguments[index:index + 2]
        require(os.path.isabs(emulator) and os.access(emulator, os.X_OK),
                f"emulator unavailable: {emulator}")
    require(len(arguments) == 5, __doc__)
    evidence, core, geometry, work, logs = arguments
    settings = json.loads(Path(evidence).read_text())
    summary = qualify(settings, Path(core).resolve(),
                      Path(geometry).resolve(), Path(work), Path(logs),
                      emulator)
    for program, result in summary.items():
        print(f"{program}: AArch64 link PASS ({result['closure']} ELFs, "
              f"{result['symbol_versions']} symbol versions), emulated "
              f"execution {result['emulated_execution']}")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (cross.ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(1)
