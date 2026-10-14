#!/usr/bin/env python3
"""Fail-closed, target-only AArch64 Linux cross configuration for Geometry.

Standard-library tooling, adapted from opencv_core_ada's cross_build_core.sh
and opencv_imgproc_ada's cross_configuration.py. It is not an SDK installer
and it never selects anything from the host: every compiler, runtime, GPR
configuration, pkg-config and sysroot is an explicit input. It never
modifies the supplied sysroot or Core prefix.

Operations:
  check                validate every input; print the resolved settings
  --prepare WORKSPACE  validate, export the clean HEAD of this checkout into
                       a new workspace, generate the target configuration
                       and build a toolchain probe
  --build WORKSPACE    --prepare, then build the production library and
                       C++ shim and install them into WORKSPACE/install

Required inputs:
  OPENCV_CROSS_TARGET       aarch64[-vendor]-linux[-abi] target triplet
  ENV_PREFIX                target sysroot (a dedicated directory)
  OPENCV_CROSS_ADA          absolute path of the target Ada compiler driver
  OPENCV_CROSS_CXX          absolute path of the target C++ compiler driver
  OPENCV_CROSS_RUNTIME      target Ada runtime (adainclude and adalib)
  OPENCV_CROSS_GPR_CONFIG   reviewed GPR configuration for the target
  OPENCV_CROSS_GPRBUILD     absolute path of gprbuild
  OPENCV_CROSS_GPRINSTALL   absolute path of gprinstall
  OPENCV_CROSS_PKG_CONFIG   absolute path of pkg-config
  PKG_CONFIG_LIBDIR         target pkg-config directories inside ENV_PREFIX
  OPENCV_CROSS_CORE_PREFIX  opencv_core installed for this target
Optional inputs:
  PKG_CONFIG_SYSROOT_DIR    must equal ENV_PREFIX when set
  OPENCV_CROSS_READELF      absolute path of readelf (default: readelf)
  OPENCV_CROSS_PROFILE      release (default), validation or development
  OPENCV_CROSS_INDEPENDENT_TOOLCHAINS
                            True when the Ada and C++ compilers come from
                            different GCC releases; recorded, never proof
                            of interoperability
PKG_CONFIG_PATH and the host search variables in HOST_SEARCH must be empty.

Passing synthetic tests of this module are not compiler evidence.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[1]

TARGET_PATTERN = r"aarch64-(?:[A-Za-z0-9_]+-)?linux(?:-[A-Za-z0-9_]+)*"

HOST_SEARCH = [
    "CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "LIBRARY_PATH",
    "GCC_EXEC_PREFIX", "COMPILER_PATH", "ADA_INCLUDE_PATH",
    "ADA_OBJECTS_PATH", "GPR_PROJECT_PATH", "ADA_PROJECT_PATH",
    "LD_LIBRARY_PATH", "PKG_CONFIG_PATH"]

PROFILES = ["release", "validation", "development"]

# Native OpenCV backend per supported major version. OpenCV 4 implements the
# Geometry operations in imgproc, OpenCV 5 in the geometry module.
BACKENDS = {"4": "imgproc", "5": "geometry"}

# Prebuilt artifacts never enter a workspace.
ARTIFACT = re.compile(r".*\.(?:ali|o|a|so(?:\.[0-9.]+)?)$")


class ConfigurationError(Exception):
    """A failed cross prerequisite; never select a host substitute."""


def require(condition, message):
    if not condition:
        raise ConfigurationError(message)


def run(args, **kwargs):
    result = subprocess.run(
        [str(arg) for arg in args], text=True, capture_output=True, **kwargs)
    require(result.returncode == 0,
            f"command failed: {args}\n{result.stdout}{result.stderr}")
    return result.stdout.strip()


def value(name):
    text = os.environ.get(name, "")
    require(text, f"{name} is required")
    require(not re.search(r'[\s"\\]', text), f"unsafe input: {name}")
    return text


def tool(name, default=None):
    """An explicitly supplied absolute executable. Only an inspection tool
    with a default (readelf) may come from PATH."""
    text = os.environ.get(name, "") or (default or "")
    require(text, f"{name} is required")
    require(not re.search(r'[\s"\\]', text), f"unsafe input: {name}")
    if default and text == default:
        found = shutil.which(default)
        require(found, f"{name} executable unavailable: {default}")
        return str(Path(found).absolute())
    path = Path(text)
    require(path.is_absolute(), f"{name} must be an absolute path: {text}")
    require(path.is_file() and os.access(path, os.X_OK),
            f"{name} executable unavailable: {text}")
    return str(path)


def inside(path, parent):
    return path == parent or parent in path.parents


def resolved(path, roots=None):
    """The real path of an existing file, contained in one of roots."""
    try:
        result = Path(path).resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise ConfigurationError(
            f"missing or invalid target path: {path}: {error}") from error
    if roots is not None:
        require(any(inside(result, root) for root in roots),
                f"path escapes the approved target roots: {path}")
    return result


def tree(path, roots):
    """Every entry under path, following links, stays inside roots."""
    output = subprocess.run(
        ["find", "-L", str(path), "-print0"], capture_output=True)
    require(output.returncode == 0,
            f"invalid target tree (broken link or cycle): {path}")
    for entry in output.stdout.split(b"\0"):
        if entry:
            resolved(os.fsdecode(entry), roots)


def elf(path, readelf):
    """ELF64 little-endian AArch64; every member of an archive."""
    details = run([readelf, "-h", path])
    for field, expected in [
            ("Machine", "AArch64"), ("Class", "ELF64"),
            ("Data", "2's complement, little endian")]:
        entries = re.findall(rf"^\s*{field}:\s*(.+)$", details, re.MULTILINE)
        require(entries and all(item.strip() == expected for item in entries),
                f"not ELF64 little-endian AArch64 (or mixed archive): "
                f"{path}: {field}")
    return details


def comments(path, readelf):
    """The compiler identity strings recorded in .comment sections."""
    output = run([readelf, "-p", ".comment", path])
    return {item.strip() for item in re.findall(r"GCC: [^\n]*", output)}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def probe_identity(compiler, language, readelf):
    """The .comment identity of an object compiled by compiler."""
    with tempfile.TemporaryDirectory(prefix="geometry-cross-probe.") as temp:
        directory = Path(temp)
        if language == "ada":
            source = directory / "identity_probe.adb"
            source.write_text("procedure Identity_Probe is\n"
                              "begin\n   null;\nend Identity_Probe;\n")
        else:
            source = directory / "identity_probe.cpp"
            source.write_text("int identity_probe() { return 0; }\n")
        run([compiler, "-c", source.name, "-o", "identity_probe.o"],
            cwd=directory)
        identity = comments(directory / "identity_probe.o", readelf)
    require(identity, f"compiler records no identity: {compiler}")
    return identity


def loader_directories(sysroot, target):
    """The target loader's default library directories, inside sysroot:
    the sysroot's ld.so.conf entries, then the multiarch and standard
    directories."""
    entries = []

    def read(path, depth):
        if depth > 8 or not path.is_file():
            return
        for line in path.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if line.startswith("include"):
                pattern = line.split(None, 1)[1].lstrip("/")
                for match in sorted(sysroot.glob(pattern)):
                    read(match, depth + 1)
            elif line:
                entries.append(line)

    read(sysroot / "etc/ld.so.conf", 0)
    entries += [f"/lib/{target}", f"/usr/lib/{target}", "/lib64",
                "/usr/lib64", "/lib", "/usr/lib"]
    directories = []
    for entry in entries:
        require(entry.startswith("/"),
                f"relative loader directory in the sysroot: {entry}")
        candidate = sysroot / entry.lstrip("/")
        if candidate.is_dir() and candidate not in directories:
            directories.append(candidate)
    return directories


def version_needs(path, readelf):
    """{file: {version}} from an ELF's version-needs section."""
    needs = {}
    current = None
    for line in run([readelf, "-V", path]).splitlines():
        file_match = re.search(r"\bFile:\s+(\S+)", line)
        if file_match:
            current = file_match[1]
            needs.setdefault(current, set())
            continue
        name_match = re.search(r"\bName:\s+(\S+)\s+Flags:", line)
        if name_match and current:
            needs[current].add(name_match[1])
    return needs


def version_definitions(path, readelf):
    """The version names an ELF defines."""
    output = run([readelf, "-V", path])
    section = output.split("Version definition section", 1)
    if len(section) < 2:
        return set()
    definitions = section[1].split("Version needs section", 1)[0]
    return set(re.findall(r"Name:\s+(\S+)", definitions))


def check_versions(closure, readelf):
    """Every symbol version an object needs is defined by the library the
    target loader resolves for it."""
    checked = 0
    for path, details in closure.items():
        for file, versions in version_needs(path, readelf).items():
            require(file in details["needed"],
                    f"{path} needs versions from {file}, which it does not "
                    "name as a dependency")
            provided = version_definitions(details["needed"][file], readelf)
            missing = sorted(versions - provided)
            require(not missing, f"{path} needs {missing} from {file}, "
                    "which the target library does not define")
            checked += len(versions)
    return checked


def dependency_closure(paths, sysroot, readelf, target, roots=()):
    """Resolve every DT_NEEDED as the target loader would, through the
    object's run paths and then the loader's default directories, to a
    contained AArch64 ELF. A library that exists in the sysroot only outside
    those directories is unresolved. The given paths may also lie in roots
    (for example linked executables); their dependencies may not."""
    defaults = loader_directories(sysroot, target)
    visited = {}
    pending = [resolved(path, [sysroot, *roots]) for path in paths]
    while pending:
        path = pending.pop()
        if str(path) in visited:
            continue
        elf(path, readelf)
        dynamic = run([readelf, "-d", path])
        run_paths = []
        for search in re.findall(
                r"\((?:RPATH|RUNPATH)\).*\[([^\]]+)\]", dynamic):
            for directory in search.split(":"):
                if directory.startswith("$ORIGIN"):
                    require(inside(path, sysroot),
                            f"$ORIGIN run path outside the sysroot: {path}")
                    directory = "/" + str(path.parent.relative_to(sysroot)) \
                        + directory[len("$ORIGIN"):]
                require(directory.startswith("/")
                        and "x86_64" not in directory,
                        f"unqualified embedded search path: {path}: "
                        f"{directory}")
                # Run-time absolute paths name the target root.
                run_paths.append(resolved(
                    sysroot / directory.lstrip("/"), [sysroot]))
        needed = re.findall(r"\(NEEDED\).*\[([^\]]+)\]", dynamic)
        resolution = {}
        for name in needed:
            require("/" not in name, f"unsafe target dependency: {name}")
            found = None
            for directory in run_paths + defaults:
                candidate = directory / name
                if candidate.exists() or candidate.is_symlink():
                    found = resolved(candidate, [sysroot])
                    break
            require(found, f"unresolved target dependency: {name} from "
                    f"{path} (not on the target loader's search path)")
            resolution[name] = str(found)
            pending.append(found)
        visited[str(path)] = dict(sha256=digest(path), needed=resolution)
    return visited


def installed_projects(prefix, roots, allowed):
    """Paths named by installed GPR files stay inside roots or allowed."""
    projects = sorted((prefix / "share/gpr").glob("*.gpr"))
    require(projects, f"no installed projects in {prefix}")
    for project in projects:
        text = re.sub(r"--[^\n]*", "", project.read_text())
        for quoted in re.findall(r'"([^"\n]+)"', text):
            candidate = quoted[2:] if quoted.startswith(("-I", "-L")) \
                else quoted
            if candidate.startswith("/") and candidate not in allowed:
                resolved(candidate, roots)
        for imported in re.findall(r'\bwith\s+"([^"\n]+)"', text,
                                   re.IGNORECASE):
            name = imported if imported.endswith(".gpr") \
                else imported + ".gpr"
            # Imports resolve through GPR_PROJECT_PATH, which holds only the
            # installed share/gpr directories.
            require("/" not in name, f"path import in {project}: {imported}")
        for directories in re.findall(
                r"for\s+(?:Source_Dirs|Object_Dir|Library_Dir|"
                r"Library_ALI_Dir)\s+use\s+([^;]+);", text, re.IGNORECASE):
            for directory in re.findall(r'"([^"\n]+)"', directories):
                resolved(project.parent / directory, [prefix])
    return [str(project) for project in projects]


def validate(require_core=True):
    target = value("OPENCV_CROSS_TARGET")
    require(re.fullmatch(TARGET_PATTERN, target),
            f"not an AArch64 Linux target triplet: {target}")
    sysroot = resolved(value("ENV_PREFIX"))
    require(sysroot.is_dir() and sysroot != Path("/"),
            "a dedicated target sysroot directory is required")
    for name in HOST_SEARCH:
        require(not os.environ.get(name), f"cross mode requires empty {name}")
    require(not inside(sysroot, ROOT) and not inside(ROOT, sysroot),
            "the sysroot overlaps the Geometry checkout")
    # CC, CXX and PATH are never consulted for a compiler.
    ada = tool("OPENCV_CROSS_ADA")
    cxx = tool("OPENCV_CROSS_CXX")
    readelf = tool("OPENCV_CROSS_READELF", "readelf")
    for compiler in [ada, cxx]:
        require(run([compiler, "-dumpmachine"]) == target,
                f"compiler target mismatch: {compiler}")
    runtime = resolved(value("OPENCV_CROSS_RUNTIME"))
    require((runtime / "adainclude").is_dir()
            and (runtime / "adalib").is_dir(),
            "target Ada runtime must contain adainclude and adalib")
    require(resolved(run([ada, "-print-file-name=adalib"]))
            == resolved(runtime / "adalib"),
            "Ada runtime differs from the compiler's runtime")
    elf(resolved(runtime / "adalib/libgnat.a"), readelf)
    ada_version = run([ada, "-dumpfullversion"])
    cxx_version = run([cxx, "-dumpfullversion"])
    independent = os.environ.get(
        "OPENCV_CROSS_INDEPENDENT_TOOLCHAINS", "False")
    require(independent in ["True", "False"],
            "OPENCV_CROSS_INDEPENDENT_TOOLCHAINS must be True or False")
    if independent == "False":
        require(ada_version == cxx_version,
                f"Ada {ada_version} and C++ {cxx_version} compilers differ; "
                "set OPENCV_CROSS_INDEPENDENT_TOOLCHAINS=True to proceed "
                "without an interoperability claim")

    pkg = tool("OPENCV_CROSS_PKG_CONFIG")
    libdirs = value("PKG_CONFIG_LIBDIR").split(":")
    require(all(libdirs), "empty pkg-config search component")
    for directory in libdirs:
        metadata = resolved(directory, [sysroot])
        require(metadata.is_dir(), "missing target pkg-config directory")
        tree(metadata, [sysroot])
    require(os.environ.get("PKG_CONFIG_SYSROOT_DIR", str(sysroot))
            == str(sysroot), "pkg-config sysroot mismatch")
    env = dict(os.environ, PKG_CONFIG_SYSROOT_DIR=str(sysroot))
    package = None
    for candidate in ["opencv5", "opencv4", "opencv"]:
        if subprocess.run([pkg, "--exists", candidate], env=env,
                          capture_output=True).returncode == 0:
            package = candidate
            break
    require(package, "target OpenCV pkg-config metadata missing")
    version = run([pkg, "--modversion", package], env=env)
    require(re.fullmatch(r"(?:4\.[1-9][0-9]*|5\.0)(?:\.[0-9]+)*", version),
            f"unsupported OpenCV version: {version} "
            "(OpenCV 4.x and 5.0 are supported)")
    module = BACKENDS[version.split(".")[0]]

    def metadata_path(name):
        raw = run([pkg, f"--variable={name}", package], env=env)
        require(raw.startswith("/"), "OpenCV metadata path must be absolute")
        path = Path(raw)
        if not inside(path, sysroot):
            path = sysroot / raw.lstrip("/")
        return resolved(path, [sysroot])

    include = metadata_path("includedir")
    library = metadata_path("libdir")
    tree(include, [sysroot])
    for header in ["core.hpp", f"{module}.hpp", "core/version.hpp"]:
        require((include / "opencv2" / header).is_file(),
                f"missing target header: opencv2/{header}")
    header_version = (include / "opencv2/core/version.hpp").read_text()
    numbers = [re.search(rf"#\s*define\s+CV_VERSION_{part}\s+(\d+)",
                         header_version)
               for part in ["MAJOR", "MINOR", "REVISION"]]
    require(all(numbers)
            and ".".join(match[1] for match in numbers) == version,
            "OpenCV header and pkg-config versions differ")
    flags = run([pkg, "--cflags", "--libs", package], env=env).split()
    advertised = []
    search = [library]
    for flag in flags:
        if flag.startswith("-L"):
            search.append(resolved(flag[2:], [sysroot]))
    for flag in flags:
        if flag.startswith(("-I", "-L")):
            directory = resolved(flag[2:], [sysroot])
            require(directory.is_dir(), "missing pkg-config directory")
            if flag.startswith("-I"):
                tree(directory, [sysroot])
        elif flag.startswith("/"):
            path = resolved(flag, [sysroot])
            elf(path, readelf)
            advertised.append(path)
        else:
            require(re.fullmatch(
                r"-l(?:opencv_[a-z0-9_]+|stdc\+\+)|-D[A-Za-z0-9_=]+|-pthread",
                flag), f"unsupported target pkg-config flag: {flag}")
            if flag.startswith("-l"):
                name = "lib" + flag[2:] + ".so"
                matches = {resolved(directory / name, [sysroot])
                           for directory in search
                           if (directory / name).exists()}
                require(len(matches) == 1,
                        f"unresolved or ambiguous target library: {flag}")
                advertised.extend(matches)
    for required in ["-lopencv_core", f"-lopencv_{module}"]:
        require(required in flags,
                f"target pkg-config metadata lacks {required}")
    cflags = run([pkg, "--cflags", package], env=env).split()
    require(all(flag.startswith(("-I", "-D")) or flag == "-pthread"
                for flag in cflags), "invalid target cflags")
    libraries = {}
    for name in ["core", module]:
        path = resolved(library / f"libopencv_{name}.so", [sysroot])
        elf(path, readelf)
        abi = version.split(".")
        sonames = re.findall(r"\(SONAME\).*\[([^\]]+)\]",
                             run([readelf, "-d", path]))
        require(f"libopencv_{name}.so.{abi[0]}{int(abi[1]):02d}" in sonames,
                f"OpenCV {name} SONAME and version differ")
        libraries[name] = str(path)
    for name in ["libc.so.6", "libstdc++.so.6"]:
        found = list(sysroot.rglob(name))
        require(found, f"missing target runtime library: {name}")
        for path in found:
            elf(resolved(path, [sysroot]), readelf)
    closure = dependency_closure(advertised + list(libraries.values()),
                                 sysroot, readelf, target)
    versions_checked = check_versions(closure, readelf)
    # The C++ compiler's libstdc++ must not need newer symbol versions than
    # the target provides.
    compiler_runtime = resolved(run(
        [cxx, "--sysroot=" + str(sysroot), "-print-file-name=libstdc++.so"]))
    elf(compiler_runtime, readelf)
    target_runtime = resolved(next(sysroot.rglob("libstdc++.so.6")),
                              [sysroot])
    pattern = r"(?:GLIBCXX|CXXABI)_[0-9.]+"
    compiler_symbols = set(re.findall(pattern, run(
        [readelf, "--version-info", compiler_runtime])))
    target_symbols = set(re.findall(pattern, run(
        [readelf, "--version-info", target_runtime])))
    require(compiler_symbols and compiler_symbols <= target_symbols,
            "the C++ compiler's libstdc++ needs symbol versions the target "
            "lacks")

    config = resolved(value("OPENCV_CROSS_GPR_CONFIG"))
    gpr = re.sub(r"--[^\n]*", "", config.read_text())
    for declaration, message in [
            (f'for Target use "{target}";', "GPR target mismatch"),
            (f'"{ada}"', "GPR Ada compiler mismatch"),
            (f'"{cxx}"', "GPR C++ compiler mismatch"),
            (f'"{runtime}/"', "GPR Ada runtime mismatch"),
            ('for Driver use Compiler\'Driver ("C++");',
             "GPR linker mismatch")]:
        require(declaration in gpr, message)
    settings = dict(
        target=target, sysroot=str(sysroot), ada=ada, cxx=cxx,
        ada_version=ada_version, cxx_version=cxx_version,
        independent_toolchains=independent == "True",
        runtime=str(runtime), readelf=readelf, pkg_config=pkg,
        config=str(config), config_sha256=digest(config),
        opencv_package=package, opencv_version=version,
        native_geometry_module=module, include=str(include),
        library=str(library), libraries=libraries, cflags=cflags,
        pkgconfig_flags=flags, dependency_closure=closure,
        symbol_versions_checked=versions_checked,
        target_cxx_runtime_symbols=sorted(target_symbols),
        gprbuild=tool("OPENCV_CROSS_GPRBUILD"),
        gprinstall=tool("OPENCV_CROSS_GPRINSTALL"),
        identities=sorted(probe_identity(ada, "ada", readelf)
                          | probe_identity(cxx, "c++", readelf)),
        production_qualified=False)
    if require_core:
        settings.update(core_prefix(settings))
    return settings


def core_prefix(settings):
    """The installed Core: contained, target-only and built by these
    compilers, as shown by its binaries."""
    sysroot = Path(settings["sysroot"])
    readelf = settings["readelf"]
    core = resolved(value("OPENCV_CROSS_CORE_PREFIX"))
    require(core.is_dir() and core != Path("/"),
            "a dedicated Core prefix directory is required")
    require(not inside(core, ROOT) and not inside(ROOT, core),
            "the Core prefix overlaps the Geometry checkout")
    roots = [core, sysroot]
    tree(core, roots)
    project = core / "share/gpr/opencv_core.gpr"
    require(project.is_file(), "missing installed Core project")
    require((core / "share/gpr/opencv_core_shim.gpr").is_file(),
            "missing installed Core shim project")
    require(re.search(r'for\s+Externally_Built\s+use\s+"[Tt]rue"',
                      project.read_text()),
            "Core project must be installed (externally built)")
    allowed = [settings["ada"], settings["cxx"], settings["runtime"],
               settings["runtime"] + "/"]
    installed_projects(core, roots, allowed)
    for name, directory in [("opencv_core_ada", "opencv_core"),
                            ("opencv_core_shim", "opencv_core_shim")]:
        archive = resolved(core / f"lib/{directory}/lib{name}.a", roots)
        elf(archive, readelf)
        recorded = comments(archive, readelf)
        require(recorded, f"Core library records no compiler: {archive}")
        require(recorded <= set(settings["identities"]),
                f"Core library built by another compiler: {archive}: "
                f"{sorted(recorded - set(settings['identities']))}")
    alis = sorted(core.rglob("*.ali"))
    require(alis, "missing Core target ALIs")
    expected = f'V "GNAT Lib v{settings["ada_version"].split(".")[0]}"'
    for ali in alis:
        first = ali.read_text().splitlines()[0]
        require(first == expected, f"Core ALI from another GNAT: {ali}")
    return dict(core=str(core), core_alis=len(alis))


def configuration(settings):
    """config/opencv_geometry_install.gpr for the target, with the same
    variables as scripts/configure_opencv.sh writes natively."""
    fields = [
        ("OpenCV_Version", settings["opencv_version"]),
        ("OpenCV_Major", settings["opencv_version"].split(".")[0]),
        ("Native_Geometry_Module", settings["native_geometry_module"]),
        ("Include_Switch", "-I" + settings["include"]),
        ("Library_Search_Switch", "-L" + settings["library"]),
        ("OpenCV_Geometry_Link_Option",
         "-lopencv_" + settings["native_geometry_module"]),
        ("OpenCV_Core_Link_Option", "-lopencv_core"),
        ("Cxx_Runtime_Switch", "-lstdc++"),
        ("Cxx_Driver", settings["cxx"]),
        ("Cxx_Sysroot", "")]
    lines = [
        "--  Generated by scripts/cross_geometry.py for "
        + settings["target"] + "; do not edit.",
        "abstract project OpenCV_Geometry_Install is",
        "   type Shim_Build_Kind is",
        '     ("Static_PIC", "Relocatable", "External_Relocatable");',
        '   type Cxx_Toolchain_Kind is ("GNU", "Apple_Clang");',
        '   Shim_Build : Shim_Build_Kind := "Static_PIC";',
        '   Cxx_Toolchain : Cxx_Toolchain_Kind := "GNU";']
    lines += [f'   {key} := "{item}";' for key, item in fields]
    lines += ["end OpenCV_Geometry_Install;"]
    return "\n".join(lines) + "\n"


def logged(args, log, env, cwd=None):
    with log.open("w") as output:
        result = subprocess.run([str(arg) for arg in args], stdout=output,
                                stderr=subprocess.STDOUT, env=env, cwd=cwd)
    require(result.returncode == 0,
            f"build step failed; diagnostics: {log}\n{log.read_text()}")


TOOL_NAME = re.compile(
    r"(?:[A-Za-z0-9_.-]+-)?(?P<tool>gcc|g\+\+|c\+\+|cc|ld|ar|ranlib|"
    r"gnat[a-z]*)(?:-[0-9.]+)?")


def check_trace(log, settings):
    """Every compiler, linker, binder and archiver invocation in a gprbuild
    -v trace belongs to the supplied target toolchain, and no compile names
    a host include or library directory."""
    drivers = {settings["ada"], settings["cxx"]}
    ada_directory = str(Path(settings["ada"]).parent)
    prefix = settings["target"] + "-"
    commands = 0
    for line in log.read_text().splitlines():
        words = line.split()
        match = TOOL_NAME.fullmatch(Path(words[0]).name) if words else None
        if not match:
            continue
        name = Path(words[0]).name
        if match["tool"] in ["gcc", "g++", "c++", "cc", "ld"]:
            require(words[0] in drivers,
                    f"invocation of an unsupplied driver in {log.name}: "
                    f"{line}")
        elif match["tool"].startswith("gnat"):
            require(str(Path(words[0]).parent) == ada_directory
                    and name.startswith(prefix),
                    f"Ada tool outside the supplied toolchain in "
                    f"{log.name}: {line}")
        else:
            require(name.startswith(prefix),
                    f"archiver is not a target tool in {log.name}: {line}")
        if "-c" not in words or not re.search(r"\.(?:adb|ads|cpp)$",
                                              words[-1]):
            continue
        commands += 1
        for word in words:
            require(not re.match(r"-[IL]/usr/(?:local/)?(?:include|lib)\b",
                                 word) or word.startswith(
                                     ("-I" + settings["sysroot"],
                                      "-L" + settings["sysroot"])),
                    f"host search directory in {log.name}: {word}")
            require("x86_64" not in word,
                    f"host architecture path in {log.name}: {word}")
    require(commands, f"no compile command in {log.name}")
    return commands


def check_outputs(work, settings):
    """Target ELF, compiler identity and GNAT version of every output."""
    readelf = settings["readelf"]
    identities = set(settings["identities"])
    objects = sorted(path for path in work.rglob("*")
                     if path.is_file() and path.suffix in [".o", ".a"]
                     and "install" not in path.relative_to(work).parts[:1])
    require(objects, "no target objects were produced")
    for path in objects:
        elf(path, readelf)
        recorded = comments(path, readelf)
        require(recorded and recorded <= identities,
                f"object not built by the supplied compilers: {path}")
    expected = f'V "GNAT Lib v{settings["ada_version"].split(".")[0]}"'
    alis = sorted(work.rglob("*.ali"))
    for ali in alis:
        require(ali.read_text().splitlines()[0] == expected,
                f"ALI from another GNAT: {ali}")
    return dict(objects=len(objects), alis=len(alis))


def extract(archive, work):
    with tarfile.open(archive) as source:
        # Git archives contain files, directories and symbolic links only.
        # Validate every destination before extracting.
        for member in source.getmembers():
            require(inside((work / member.name).resolve(), work),
                    "archive path escapes the workspace")
            require(member.isfile() or member.isdir() or member.issym(),
                    "unsafe archive member")
            if member.issym():
                require(inside((work / member.name).parent.joinpath(
                    member.linkname).resolve(), work),
                        "archive symlink escapes the workspace")
        if hasattr(tarfile, "data_filter"):
            source.extractall(work, filter="data")
        else:
            source.extractall(work)


def workspace(mode, destination, settings):
    require(mode in ["--prepare", "--build"],
            "usage: --prepare|--build ABSOLUTE_WORKSPACE")
    require(Path(destination).is_absolute(), "workspace must be absolute")
    require(not re.search(r'[\s"\\]', destination), "unsafe workspace path")
    work = Path(destination)
    require(not work.exists() and not work.is_symlink(),
            "workspace must not already exist (stale build output)")
    work = work.resolve()
    require(not work.exists(),
            "workspace must not already exist (stale build output)")
    for protected in [ROOT, Path(settings["sysroot"]),
                      Path(settings["core"])]:
        require(not inside(work, protected) and not inside(protected, work),
                f"workspace overlaps {protected}")
    git = ["git", "-c", f"safe.directory={ROOT}", "-C", ROOT]
    require(not run(git + ["status", "--porcelain", "--untracked-files=all"]),
            "the source checkout must be clean")
    revision = run(git + ["rev-parse", "HEAD"])
    profile = os.environ.get("OPENCV_CROSS_PROFILE", "release")
    require(profile in PROFILES, f"invalid build profile: {profile}")

    # All checks have passed; the workspace is created only now.
    work.mkdir(parents=True)
    archive = work / "source.tar"
    run(git + ["archive", "--output=" + str(archive), revision])
    extract(archive, work)
    archive.unlink()
    prebuilt = [str(path) for path in work.rglob("*")
                if ARTIFACT.fullmatch(path.name)]
    require(not prebuilt, f"prebuilt artifacts in the export: {prebuilt}")
    (work / "source-revision.txt").write_text(revision + "\n")
    install_config = work / "config/opencv_geometry_install.gpr"
    require(not install_config.exists(), "stale target configuration")
    install_config.parent.mkdir(exist_ok=True)
    install_config.write_text(configuration(settings))
    shutil.copyfile(work / "tests/gnat12/opencv_geometry_config.gpr",
                    work / "config/opencv_geometry_config.gpr")
    shutil.copyfile(settings["config"], work / "config/target.cgpr")
    evidence = dict(settings, source_sha=revision, profile=profile,
                    qualification="CROSS_CONFIGURATION_ONLY")
    (work / "cross-evidence.json").write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n")

    env = {key: item for key, item in os.environ.items()
           if key not in HOST_SEARCH}
    env["GPR_PROJECT_PATH"] = str(Path(settings["core"]) / "share/gpr")
    sysroot_switch = "--sysroot=" + settings["sysroot"]
    command = [settings["gprbuild"], "--config=" + str(
        work / "config/target.cgpr")]
    cross_switches = ["-cargs:C++", sysroot_switch, "-largs", sysroot_switch]
    probe = work / "tests/cross/probe"
    logged(command + ["-P", probe / "probe.gpr", "-p", "-v"]
           + cross_switches, work / "toolchain-probe.log", env)
    check_trace(work / "toolchain-probe.log", settings)
    probe_elf = elf(probe / "bin/probe", settings["readelf"])
    (work / "toolchain-probe-elf.log").write_text(probe_elf)
    print("TARGET_PROBE_QUALIFIED (toolchain probe only; not production "
          "or execution qualification)")
    if mode == "--build":
        profile_switch = "-XGEOMETRY_GNAT12_PROFILE=" + profile
        logged(command + ["-P", work / "opencv_geometry.gpr", "-p", "-v",
                          profile_switch] + cross_switches,
               work / "production-build.log", env)
        compiled = check_trace(work / "production-build.log", settings)
        outputs = check_outputs(work, settings)
        for project in ["opencv_geometry_shim", "opencv_geometry"]:
            logged([settings["gprinstall"], "--config=" + str(
                work / "config/target.cgpr"), "-P",
                work / f"{project}.gpr", "-p", "--prefix=" + str(
                    work / "install"), profile_switch],
                work / f"{project}-install.log", env)
        install = work / "install"
        installed = installed_projects(
            install, [install, Path(settings["sysroot"])],
            [settings["ada"], settings["cxx"], settings["runtime"],
             settings["runtime"] + "/"])
        for path in install.rglob("*"):
            if path.is_file() and path.suffix in [".o", ".a"]:
                elf(path, settings["readelf"])
        evidence.update(qualification="TARGET_BUILD_INSTALL_ONLY",
                        compiled_units=compiled, outputs=outputs,
                        installed_projects=installed)
        (work / "cross-evidence.json").write_text(
            json.dumps(evidence, indent=2, sort_keys=True) + "\n")
        print(f"GEOMETRY_TARGET_BUILD_INSTALL ({compiled} compilations, "
              f"{outputs['objects']} AArch64 objects); consumer links, "
              "target execution and release qualification remain "
              "separate gates")
    print(f"Cross workspace: {work}\nSource revision: {revision}")


def main(arguments):
    require(arguments, "operation required: check | --prepare | --build")
    if arguments == ["check"]:
        print(json.dumps(validate(), indent=2, sort_keys=True))
        return
    require(len(arguments) == 2,
            "usage: cross_geometry.py check | --prepare|--build "
            "ABSOLUTE_WORKSPACE")
    workspace(arguments[0], arguments[1], validate())


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ConfigurationError, OSError, ValueError) as failure:
        print(f"error: {failure}", file=sys.stderr)
        sys.exit(1)
