"""Negative-first synthetic controls for scripts/cross_geometry.py.

Fake compilers, readelf, pkg-config, gprbuild and gprinstall stand in for a
target toolchain. These tests prove the fail-closed logic only; they are not
target compiler, link or execution evidence.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import shlex
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "cross", ROOT / "scripts/cross_geometry.py")
cross = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cross)

TARGET = "aarch64-linux-gnu"
IDENTITY = "GCC: (Fake 12.2.0-14) 12.2.0"

FAKE_READELF = r'''#!/usr/bin/env python3
import fnmatch, json, os, sys
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                      "readelf.json")))
mode, path = sys.argv[1], sys.argv[-1]
if not os.path.exists(path):
    sys.exit("readelf: missing " + path)
def attribute(name):
    value = config["default"][name]
    for pattern, override in config["overrides"].items():
        if fnmatch.fnmatch(path, pattern) and name in override:
            value = override[name]
    return value
if mode == "-h":
    print("  Class:     " + attribute("class"))
    print("  Data:      " + attribute("data"))
    print("  Machine:   " + attribute("machine"))
elif mode == "-d":
    for soname in attribute("sonames"):
        print(" 0x0e (SONAME) Library soname: [" + soname + "]")
    for needed in attribute("needed"):
        print(" 0x01 (NEEDED) Shared library: [" + needed + "]")
    for runpath in attribute("runpath"):
        print(" 0x1d (RUNPATH) Library runpath: [" + runpath + "]")
elif mode == "-p":
    print("String dump of section '.comment':")
    for comment in attribute("comment"):
        print("  [     0]  " + comment)
elif mode == "--version-info":
    print(" ".join(attribute("versions")))
elif mode == "-V":
    print("Version definition section '.gnu.version_d' contains 1 entry:")
    for index, name in enumerate(attribute("defines")):
        print(f"  0x00{index}0: Rev: 1  Flags: none  Index: {index + 2}"
              f"  Cnt: 1  Name: {name}")
    print("Version needs section '.gnu.version_r' contains 1 entry:")
    for file, names in attribute("needs").items():
        print(f"  000000: Version: 1  File: {file}  Cnt: {len(names)}")
        for name in names:
            print(f"  0x0010:   Name: {name}  Flags: none  Version: 2")
'''

FAKE_COMPILER = r'''#!/usr/bin/env python3
import json, os, sys
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                      "compilers.json")))[
    os.path.basename(__file__)]
arguments = sys.argv[1:]
for argument in arguments:
    if argument == "-dumpmachine":
        print(config["machine"]); sys.exit(0)
    if argument == "-dumpfullversion":
        print(config["version"]); sys.exit(0)
    if argument.startswith("-print-file-name="):
        print(config["files"][argument.split("=", 1)[1]]); sys.exit(0)
if "-c" in arguments:
    output = arguments[arguments.index("-o") + 1]
    if not config.get("omit_object"):
        open(output, "w").close()
    if "identity_probe.adb" in arguments and not config.get("omit_ali"):
        open("identity_probe.ali", "w").write(
            config.get("ali", 'V "GNAT Lib v12"') +
            '\nU identity_probe%b identity_probe.adb 721448c7 NE\n')
    sys.exit(0)
sys.exit("unexpected compiler arguments: " + " ".join(arguments))
'''

FAKE_PKG_CONFIG = r'''#!/usr/bin/env python3
import json, os, sys
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                      "pkg-config.json")))
arguments = sys.argv[1:]
package = arguments[-1]
if arguments[0] == "--exists":
    sys.exit(0 if package == config["package"] else 1)
if package != config["package"]:
    sys.exit(1)
if arguments[0] == "--modversion":
    print(config["version"])
elif arguments[0].startswith("--variable="):
    print(config["variables"][arguments[0].split("=", 1)[1]])
elif arguments[:2] == ["--cflags", "--libs"]:
    print(" ".join(config["cflags"] + config["libs"]))
elif arguments[0] == "--cflags":
    print(" ".join(config["cflags"]))
'''

# A gprbuild stand-in: writes target-looking outputs and a -v style trace.
FAKE_GPRBUILD = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                     "gprbuild.json")))
project = Path(sys.argv[sys.argv.index("-P") + 1])
base = project.parent
ada, cxx, binder = config["ada"], config["cxx"], config["binder"]
lines = []
def output(path, text=""):
    path = base / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
if project.name == "probe.gpr":
    output("obj/probe.o"); output("obj/cxx_probe.o"); output("bin/probe")
    output("obj/probe.ali", 'V "GNAT Lib v12"\n')
    lines += [f"{ada} -c -x ada -gnatA {base}/probe.adb",
              f"{cxx} -c -x c++ {base}/cxx_probe.cpp",
              f"{binder} -x probe.ali",
              f"{cxx} probe.o b__probe.o -o {base}/bin/probe"]
else:
    output("obj/release/opencv-geometry.o")
    output("obj/release/opencv-geometry.ali", 'V "GNAT Lib v12"\n')
    output("obj/shim/release/opencv_geometry_shim.o")
    output("lib/libopencv_geometry_ada.a")
    output("lib/libopencv_geometry_shim.a")
    lines += [f"{ada} -c -x ada -gnatA {base}/src/opencv-geometry.adb",
              f"{cxx} -c -x c++ -I{config['include']} "
              f"{base}/cpp/opencv_geometry_shim.cpp",
              f"{config['archiver']} cr lib/libopencv_geometry_ada.a"]
lines += config.get("extra", [])
print("\n".join(lines))
'''

FAKE_GPRINSTALL = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
config = json.load(open(os.path.join(os.path.dirname(__file__),
                                     "gprinstall.json")))
project = Path(sys.argv[sys.argv.index("-P") + 1]).stem
prefix = Path([a for a in sys.argv if a.startswith("--prefix=")][0][9:])
(prefix / "share/gpr").mkdir(parents=True, exist_ok=True)
(prefix / "include" / project).mkdir(parents=True, exist_ok=True)
library = prefix / "lib" / project
library.mkdir(parents=True, exist_ok=True)
(library / f"lib{project}.a").write_text("")
(prefix / "share/gpr" / f"{project}.gpr").write_text(
    f'with "opencv_core";\nlibrary project {project} is\n'
    f'   for Source_Dirs use ("../../include/{project}");\n'
    f'   for Library_Dir use "../../lib/{project}";\n'
    f'   for Linker_Options use ("{config["link"]}");\n'
    'end ' + project + ';\n')
'''


class CrossGeometryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="geometry-cross.")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.tools = self.base / "tools"
        self.sysroot = self.base / "sysroot"
        self.include = self.sysroot / "usr/include/opencv4"
        self.library = self.sysroot / "usr/lib"
        self.runtime = self.base / "runtime"
        self.core = self.base / "core-prefix"
        for directory in [
                self.tools, self.include / "opencv2/core",
                self.library / "pkgconfig", self.runtime / "adalib",
                self.runtime / "adainclude", self.core / "share/gpr",
                self.core / "include/opencv_core",
                self.core / "lib/opencv_core",
                self.core / "lib/opencv_core_shim",
                self.base / "cxxlib"]:
            directory.mkdir(parents=True)
        for path in [
                self.include / "opencv2/core.hpp",
                self.include / "opencv2/imgproc.hpp",
                self.library / "libopencv_core.so",
                self.library / "libopencv_imgproc.so",
                self.library / "libc.so.6", self.library / "libstdc++.so.6",
                self.library / "libz.so.1",
                self.runtime / "adalib/libgnat.a",
                self.core / "lib/opencv_core/libopencv_core_ada.a",
                self.core / "lib/opencv_core_shim/libopencv_core_shim.a",
                self.base / "cxxlib/libstdc++.so"]:
            path.touch()
        self.version(4, 6, 0)
        (self.runtime / "adalib/system.ali").write_text('V "GNAT Lib v12"\n')
        (self.core / "lib/opencv_core/opencv.ali").write_text(
            'V "GNAT Lib v12"\n')
        (self.core / "share/gpr/opencv_core.gpr").write_text(
            'with "opencv_core_shim";\nlibrary project OpenCV_Core is\n'
            '   for Source_Dirs use ("../../include/opencv_core");\n'
            '   for Library_Dir use "../../lib/opencv_core";\n'
            '   for Externally_Built use "True";\nend OpenCV_Core;\n')
        (self.core / "share/gpr/opencv_core_shim.gpr").write_text(
            'library project OpenCV_Core_Shim is\n'
            '   for Library_Dir use "../../lib/opencv_core_shim";\n'
            f'   for Linker_Options use ("-L{self.library}");\n'
            '   for Externally_Built use "True";\nend OpenCV_Core_Shim;\n')

        self.ada = self.executable(f"{TARGET}-gcc-12", FAKE_COMPILER)
        self.cxx = self.executable(f"{TARGET}-g++-12", FAKE_COMPILER)
        self.compilers = {
            Path(self.ada).name: dict(
                machine=TARGET, version="12.2.0",
                files={"adalib": str(self.runtime / "adalib")}),
            Path(self.cxx).name: dict(
                machine=TARGET, version="12.2.0",
                files={"libstdc++.so": str(self.base / "cxxlib/libstdc++.so")})}
        self.readelf_config = dict(
            default=dict(machine="AArch64", **{"class": "ELF64"},
                         data="2's complement, little endian", sonames=[],
                         needed=[], runpath=[], comment=[IDENTITY],
                         versions=["GLIBCXX_3.4", "CXXABI_1.3"],
                         needs={}, defines=[]),
            overrides={
                "*/libopencv_core.so": dict(
                    sonames=["libopencv_core.so.406"], needed=["libz.so.1"]),
                "*/libopencv_imgproc.so": dict(
                    sonames=["libopencv_imgproc.so.406"]),
                "*/libopencv_geometry.so": dict(
                    sonames=["libopencv_geometry.so.500"])})
        self.pkg = dict(
            package="opencv4", version="4.6.0",
            variables=dict(includedir="/usr/include/opencv4",
                           libdir="/usr/lib",
                           pcfiledir=str(self.library / "pkgconfig")),
            cflags=[f"-I{self.include}"],
            libs=[f"-L{self.library}", "-lopencv_core", "-lopencv_imgproc"])
        self.readelf = self.executable("readelf", FAKE_READELF)
        self.pkg_config = self.executable("pkg-config", FAKE_PKG_CONFIG)
        self.binder = self.executable(f"{TARGET}-gnatbind-12", "")
        self.gprbuild_config = dict(
            ada=self.ada, cxx=self.cxx, binder=self.binder,
            include=str(self.include),
            archiver=str(self.tools / f"{TARGET}-ar"))
        self.gprbuild = self.executable("gprbuild", FAKE_GPRBUILD)
        self.gprinstall = self.executable("gprinstall", FAKE_GPRINSTALL)
        self.install_config = dict(link=f"-L{self.library}")
        self.config = self.base / "target.cgpr"
        self.config.write_text(
            f'for Target use "{TARGET}";\n"{self.ada}"\n"{self.cxx}"\n'
            f'"{self.runtime}/"\nfor Driver use Compiler\'Driver ("C++");\n')
        self.env = {
            "PATH": os.environ["PATH"], "OPENCV_CROSS_TARGET": TARGET,
            "ENV_PREFIX": str(self.sysroot),
            "OPENCV_CROSS_ADA": self.ada, "OPENCV_CROSS_CXX": self.cxx,
            "OPENCV_CROSS_RUNTIME": str(self.runtime),
            "OPENCV_CROSS_GPR_CONFIG": str(self.config),
            "OPENCV_CROSS_GPRBUILD": self.gprbuild,
            "OPENCV_CROSS_GPRINSTALL": self.gprinstall,
            "OPENCV_CROSS_PKG_CONFIG": self.pkg_config,
            "OPENCV_CROSS_READELF": self.readelf,
            "PKG_CONFIG_LIBDIR": str(self.library / "pkgconfig"),
            "OPENCV_CROSS_CORE_PREFIX": str(self.core)}
        self.write_configs()

    # Fixture helpers.

    def executable(self, name, body):
        path = self.tools / name
        path.write_text(body or "#!/bin/sh\nexit 0\n")
        path.chmod(0o755)
        return str(path)

    def version(self, major, minor, revision):
        (self.include / "opencv2/core/version.hpp").write_text(
            f"#define CV_VERSION_MAJOR {major}\n"
            f"#define CV_VERSION_MINOR {minor}\n"
            f"#define CV_VERSION_REVISION {revision}\n")

    def write_configs(self):
        for name, item in [("readelf.json", self.readelf_config),
                           ("compilers.json", self.compilers),
                           ("pkg-config.json", self.pkg),
                           ("gprbuild.json", self.gprbuild_config),
                           ("gprinstall.json", self.install_config)]:
            (self.tools / name).write_text(json.dumps(item))

    def snapshot(self):
        return sorted((str(path), path.is_symlink()
                       or (path.is_file() and path.read_bytes()))
                      for path in self.base.rglob("*")
                      if "source" not in path.relative_to(self.base).parts[:1])

    def check(self, require_core=True):
        self.write_configs()
        with patch.dict(os.environ, self.env, clear=True):
            return cross.validate(require_core)

    def reject(self, message, require_core=True):
        self.write_configs()
        before = self.snapshot()
        with self.assertRaisesRegex(cross.ConfigurationError, message):
            self.check(require_core)
        self.assertEqual(before, self.snapshot(),
                         "a rejected check modified its inputs")

    def override(self, pattern, **attributes):
        self.readelf_config["overrides"].setdefault(pattern, {}).update(
            attributes)

    def source_checkout(self):
        """A clean Git checkout with the files the workspace needs."""
        source = self.base / "source"
        if (source / ".git").is_dir():
            return source
        for name, text in [
                ("opencv_geometry.gpr", "project Opencv_Geometry is\n"),
                ("opencv_geometry_shim.gpr", "project Shim is\n"),
                ("tests/gnat12/opencv_geometry_config.gpr", "--\n"),
                ("tests/cross/probe/probe.gpr", "project Probe is\n"),
                ("src/opencv-geometry.adb", "--\n"),
                ("cpp/opencv_geometry_shim.cpp", "//\n")]:
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        git = ["git", "-C", str(source), "-c", "user.name=t",
               "-c", "user.email=t@example.invalid"]
        subprocess.run(["git", "init", "-q", str(source)], check=True)
        subprocess.run(git + ["add", "-A"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", "fixture"], check=True)
        return source

    def run_workspace(self, mode, destination, source=None):
        source = source or self.source_checkout()
        self.write_configs()
        with patch.dict(os.environ, self.env, clear=True), \
                patch.object(cross, "ROOT", source):
            settings = cross.validate()
            cross.workspace(mode, str(destination), settings)
        return Path(destination)

    def reject_workspace(self, message, mode="--build", destination=None,
                         source=None):
        destination = destination or self.base / "work"
        with self.assertRaisesRegex(cross.ConfigurationError, message):
            self.run_workspace(mode, destination, source)

    # Positive controls.

    def test_valid_check_is_repeatable(self):
        first = self.check()
        self.assertEqual(first, self.check())
        self.assertFalse(first["production_qualified"])
        self.assertEqual(first["native_geometry_module"], "imgproc")
        self.assertEqual(first["identities"], [IDENTITY])

    def gnatls(self, text=None, status=0):
        self.compilers[Path(self.ada).name]["files"]["adalib"] = "adalib"
        text = text if text is not None else (
            f"Source Search Path:\n <Current_Directory>\n"
            f" {self.runtime}/adainclude\n\nObject Search Path:\n"
            f" <Current_Directory>\n {self.runtime}/adalib\n")
        return Path(self.executable(f"{TARGET}-gnatls-12",
                    "#!/bin/sh\nprintf '%s\\n' " + shlex.quote(text)
                    + f"\nexit {status}\n"))

    def test_gnatls_fallback_and_compiler_symlink(self):
        self.gnatls()
        self.assertEqual(self.check()["runtime_identity"]["method"], "gnatls")
        alias = self.base / "compiler-alias"
        alias.symlink_to(self.ada)
        self.assertEqual(cross.matching_gnatls(alias).parent, self.tools)

    def test_gnatls_is_never_selected_from_path_or_foreign_directory(self):
        sibling = self.gnatls()
        sibling.unlink()
        self.env["PATH"] = str(self.tools) + ":" + os.environ["PATH"]
        self.executable("gnatls", "#!/bin/sh\nexit 0\n")
        self.reject("matching GNATLS unavailable")
        foreign = self.base / "foreign-gnatls"
        foreign.write_text("#!/bin/sh\nexit 0\n")
        foreign.chmod(0o755)
        sibling.symlink_to(foreign)
        self.reject("another toolchain directory")

    def test_gnatls_complete_sections_and_all_paths_are_required(self):
        for text in [
                f"Object Search Path:\n {self.runtime}/adalib\n",
                "Source Search Path:\nrelative/path\n",
                f"Source Search Path:\n {self.runtime}/adainclude\n"
                "Source Search Path:\n",
                f"Source Search Path:\n {self.runtime}/adainclude\n"
                f"Object Search Path:\n {self.runtime}/adalib\n {self.base}\n",
                f"Source Search Path:\n {self.base}\n"
                f"Object Search Path:\n {self.runtime}/adalib\n",
                "Source Search Path:\n /missing-runtime\n"]:
            with self.subTest(text=text):
                self.gnatls(text)
                self.reject("GNATLS|runtime differs")

    def test_gnatls_failed_command_and_absolute_mismatch(self):
        self.gnatls(status=1)
        self.reject("command failed")
        self.compilers[Path(self.ada).name]["files"]["adalib"] = str(self.base)
        self.reject("runtime differs")

    def test_gnatls_crlf_whitespace_and_runtime_alias(self):
        self.gnatls(f" Source Search Path :\r\n {self.runtime}/adainclude\r\n"
                    f" Object Search Path :\r\n {self.runtime}/adalib\r\n")
        self.check()

    def test_ali_version_is_compiled_not_gcc_major(self):
        for compiler in self.compilers.values():
            compiler["version"] = "13.3.1"
        self.compilers[Path(self.ada).name]["ali"] = 'V "GNAT Lib v25"'
        for path in [self.runtime / "adalib/system.ali",
                     self.core / "lib/opencv_core/opencv.ali"]:
            path.write_text('V "GNAT Lib v25"\n')
        self.assertEqual(self.check()["ali_signature"], 'V "GNAT Lib v25"')
        (self.core / "lib/opencv_core/stale.ali").write_text('V "GNAT Lib v13"\n')
        self.reject("ALI from another GNAT")

    def test_probe_missing_outputs_invalid_ali_and_runtime_mismatch(self):
        compiler = self.compilers[Path(self.ada).name]
        for key, value in [("omit_object", True), ("omit_ali", True),
                           ("ali", "not a GNAT ALI"),
                           ("ali", 'V "GNAT Lib v25"')]:
            with self.subTest(key=key, value=value):
                compiler[key] = value
                self.reject("missing|invalid|differs")
                del compiler[key]

    def test_probe_host_object_is_rejected_before_core(self):
        self.override("*/identity_probe.o", machine="X86-64")
        self.reject("not ELF64 little-endian AArch64", require_core=False)

    def test_mixed_geometry_alis_are_rejected(self):
        work = self.run_workspace("--build", self.base / "work")
        (work / "obj/stale.ali").write_text('V "GNAT Lib v25"\n')
        with self.assertRaisesRegex(cross.ConfigurationError,
                                    "ALI from another GNAT"):
            cross.check_outputs(work, self.check())

    def test_opencv5_selects_the_geometry_backend(self):
        (self.include / "opencv2/geometry.hpp").touch()
        (self.include / "opencv2/imgproc.hpp").unlink()
        (self.library / "libopencv_geometry.so").touch()
        self.override("*/libopencv_core.so", sonames=["libopencv_core.so.500"])
        self.version(5, 0, 0)
        self.pkg.update(package="opencv5", version="5.0.0",
                        libs=[f"-L{self.library}", "-lopencv_core",
                              "-lopencv_geometry"])
        settings = self.check()
        self.assertEqual(settings["native_geometry_module"], "geometry")
        generated = cross.configuration(settings)
        self.assertIn('OpenCV_Geometry_Link_Option := "-lopencv_geometry";',
                      generated)
        self.assertIn('Native_Geometry_Module := "geometry";', generated)
        self.assertNotIn("imgproc", generated)

    def test_generated_configuration_is_target_only(self):
        generated = cross.configuration(self.check())
        for line in [
                'Shim_Build : Shim_Build_Kind := "Static_PIC";',
                'Native_Geometry_Module := "imgproc";',
                f'Include_Switch := "-I{self.include}";',
                f'Library_Search_Switch := "-L{self.library}";',
                'OpenCV_Geometry_Link_Option := "-lopencv_imgproc";',
                f'Cxx_Driver := "{self.cxx}";']:
            self.assertIn(line, generated)
        for switch in ['"-I', '"-L']:
            for line in generated.splitlines():
                if switch in line:
                    self.assertIn(switch + str(self.sysroot) + "/", line)

    def test_build_and_install_in_new_workspace(self):
        work = self.run_workspace("--build", self.base / "work")
        evidence = json.loads((work / "cross-evidence.json").read_text())
        self.assertEqual(evidence["qualification"],
                         "TARGET_BUILD_INSTALL_ONLY")
        self.assertFalse(evidence["production_qualified"])
        self.assertTrue((work / "install/share/gpr/opencv_geometry.gpr")
                        .is_file())
        self.assertEqual((work / "source-revision.txt").read_text().strip(),
                         evidence["source_sha"])

    def test_independent_toolchains_require_explicit_opt_in(self):
        self.compilers[Path(self.cxx).name]["version"] = "13.3.0"
        self.reject("compilers differ")
        self.env["OPENCV_CROSS_INDEPENDENT_TOOLCHAINS"] = "True"
        self.assertTrue(self.check()["independent_toolchains"])

    # Inputs and host contamination.

    def test_missing_inputs(self):
        for key in [
                "OPENCV_CROSS_TARGET", "ENV_PREFIX", "OPENCV_CROSS_ADA",
                "OPENCV_CROSS_CXX", "OPENCV_CROSS_RUNTIME",
                "OPENCV_CROSS_GPR_CONFIG", "OPENCV_CROSS_GPRBUILD",
                "OPENCV_CROSS_GPRINSTALL", "OPENCV_CROSS_PKG_CONFIG",
                "PKG_CONFIG_LIBDIR", "OPENCV_CROSS_CORE_PREFIX"]:
            with self.subTest(key=key):
                item = self.env.pop(key)
                self.reject(key)
                self.env[key] = item

    def test_tools_are_never_looked_up_on_path(self):
        for key in ["OPENCV_CROSS_ADA", "OPENCV_CROSS_CXX",
                    "OPENCV_CROSS_GPRBUILD", "OPENCV_CROSS_PKG_CONFIG"]:
            with self.subTest(key=key):
                original = self.env[key]
                self.env[key] = Path(original).name
                self.env["PATH"] = str(self.tools) + ":" + os.environ["PATH"]
                self.reject("absolute path")
                self.env[key] = original

    def test_host_search_environment(self):
        for key in cross.HOST_SEARCH:
            with self.subTest(key=key):
                self.env[key] = "/usr/include"
                self.reject(key)
                del self.env[key]

    def test_host_pkg_config_metadata(self):
        self.env["PKG_CONFIG_LIBDIR"] = str(self.base)
        self.reject("escapes")
        self.env["PKG_CONFIG_LIBDIR"] = str(self.library / "pkgconfig") + ":"
        self.reject("empty pkg-config")
        self.env["PKG_CONFIG_LIBDIR"] = str(self.library / "pkgconfig")
        self.env["PKG_CONFIG_SYSROOT_DIR"] = "/"
        self.reject("sysroot mismatch")

    def test_host_flags_and_libraries(self):
        host = self.base / "host"
        (host / "lib").mkdir(parents=True)
        (host / "lib/libopencv_core.so").touch()
        for flags in [dict(cflags=[f"-I{host}"]),
                      dict(libs=[f"-L{host / 'lib'}", "-lopencv_core",
                                 "-lopencv_imgproc"]),
                      dict(libs=[str(host / "lib/libopencv_core.so")]),
                      dict(libs=["-Wl,-rpath,/usr/lib", "-lopencv_core",
                                 "-lopencv_imgproc"])]:
            with self.subTest(flags=flags):
                saved = dict(self.pkg)
                self.pkg.update(flags)
                self.reject("escapes|unsupported")
                self.pkg.clear()
                self.pkg.update(saved)

    def test_embedded_host_run_path(self):
        self.override("*/libopencv_core.so",
                      runpath=["/usr/lib/x86_64-linux-gnu"])
        self.reject("unqualified embedded search path")

    def test_trace_with_host_compiler_or_directories(self):
        for extra, message in [
                (["/usr/bin/gcc -c -x ada /work/src/opencv-geometry.adb"],
                 "unsupplied driver"),
                (["g++ probe.o -o probe"], "unsupplied driver"),
                ([f"{self.ada} -c -I/usr/include/opencv4 /work/a.adb"],
                 "host search directory"),
                ([f"/usr/bin/gnatbind-12 -x probe.ali"],
                 "outside the supplied toolchain"),
                (["/usr/bin/ar cr lib/x.a"], "archiver is not a target"),
                ([f"{self.cxx} -c /usr/lib/x86_64-linux-gnu/x.cpp"],
                 "host architecture")]:
            with self.subTest(extra=extra):
                self.gprbuild_config["extra"] = extra
                destination = self.base / "work-trace"
                self.reject_workspace(message, destination=destination)
                self.gprbuild_config["extra"] = []
                subprocess.run(["rm", "-rf", str(destination),
                                str(self.base / "source")], check=True)

    # Target architecture.

    def test_target_names(self):
        for target in ["aarch64-linux-gnu", "aarch64-unknown-linux-gnu",
                       "aarch64-poky-linux", "aarch64-linux-musl"]:
            self.assertTrue(cross.re.fullmatch(cross.TARGET_PATTERN, target))
        for target in ["x86_64-linux-gnu", "arm-linux-gnueabihf",
                       "aarch64-elf", "aarch64-linux-gnu;rm"]:
            with self.subTest(target=target):
                self.env["OPENCV_CROSS_TARGET"] = target
                self.reject("AArch64 Linux|unsafe")
        self.env["OPENCV_CROSS_TARGET"] = TARGET

    def test_compiler_target_mismatch(self):
        for name in [Path(self.ada).name, Path(self.cxx).name]:
            with self.subTest(compiler=name):
                self.compilers[name]["machine"] = "x86_64-linux-gnu"
                self.reject("compiler target mismatch")
                self.compilers[name]["machine"] = TARGET

    def test_wrong_architecture_class_or_endianness(self):
        for pattern in ["*/libopencv_imgproc.so", "*/libz.so.1",
                        "*/libgnat.a", "*/libc.so.6",
                        "*/libopencv_core_ada.a"]:
            for bad in [dict(machine="Advanced Micro Devices X86-64"),
                        dict(data="2's complement, big endian"),
                        dict(**{"class": "ELF32"})]:
                with self.subTest(pattern=pattern, bad=bad):
                    self.readelf_config["overrides"][pattern] = dict(
                        self.readelf_config["overrides"].get(pattern, {}),
                        **bad)
                    self.reject("not ELF64 little-endian AArch64")
                    for key in bad:
                        del self.readelf_config["overrides"][pattern][key]

    # Runtime and compiler identity.

    def test_missing_or_mismatched_runtime(self):
        self.compilers[Path(self.ada).name]["files"]["adalib"] = str(
            self.library)
        self.reject("runtime differs")
        self.compilers[Path(self.ada).name]["files"]["adalib"] = str(
            self.runtime / "adalib")
        (self.runtime / "adalib/libgnat.a").unlink()
        self.reject("missing or invalid")

    def test_compiler_cxx_runtime_newer_than_target(self):
        self.override("*/cxxlib/libstdc++.so",
                      versions=["GLIBCXX_3.4", "GLIBCXX_3.4.32"])
        self.reject("symbol versions the target lacks")

    def test_core_built_by_another_compiler(self):
        self.override("*/libopencv_core_shim.a",
                      comment=["GCC: (GNU) 16.1.0"])
        self.reject("Core library built by another compiler")

    def test_core_ali_from_another_gnat(self):
        (self.core / "lib/opencv_core/opencv-core.ali").write_text(
            'V "GNAT Lib v16"\n')
        self.reject("Core ALI from another GNAT")

    def test_core_prefix_structure(self):
        project = self.core / "share/gpr/opencv_core.gpr"
        original = project.read_text()
        project.write_text(original.replace("Externally_Built", "Other"))
        self.reject("installed")
        project.write_text(original.replace(
            '"../../lib/opencv_core"', '"/usr/lib/opencv_core"'))
        self.reject("missing or invalid|escapes")
        imports = self.base / "elsewhere"
        imports.mkdir()
        (imports / "opencv_core_shim").touch()
        project.write_text(original.replace(
            'with "opencv_core_shim"', f'with "{imports}/opencv_core_shim"'))
        self.reject("escapes")
        project.write_text(original.replace(
            'with "opencv_core_shim"', 'with "../gpr/opencv_core_shim"'))
        self.reject("path import")
        project.write_text(original)
        for path in [self.core / "share/gpr/opencv_core_shim.gpr",
                     self.core / "lib/opencv_core/libopencv_core_ada.a",
                     self.core / "lib/opencv_core/opencv.ali"]:
            with self.subTest(path=path.name):
                text = path.read_bytes()
                path.unlink()
                self.reject("missing")
                path.write_bytes(text)

    def test_core_prefix_overlapping_checkout(self):
        self.env["OPENCV_CROSS_CORE_PREFIX"] = str(ROOT)
        self.reject("overlaps the Geometry checkout")

    # Missing OpenCV and incorrect metadata.

    def test_missing_headers_and_libraries(self):
        for path in [self.include / "opencv2/core.hpp",
                     self.include / "opencv2/imgproc.hpp",
                     self.library / "libopencv_core.so",
                     self.library / "libopencv_imgproc.so",
                     self.library / "libc.so.6",
                     self.library / "libstdc++.so.6"]:
            with self.subTest(path=path.name):
                path.unlink()
                self.reject("missing|unresolved")
                path.touch()

    def test_missing_transitive_dependency(self):
        (self.library / "libz.so.1").unlink()
        self.reject("unresolved target dependency: libz.so.1")

    def test_dependency_outside_the_loader_search_path(self):
        # As unpacked Debian packages leave an alternatives-managed library
        # such as libblas.so.3: present, but only in a private directory.
        (self.library / "libz.so.1").unlink()
        (self.library / "private").mkdir()
        (self.library / "private/libz.so.1").touch()
        self.reject("not on the target loader's search path")
        self.override("*/libopencv_core.so", runpath=["$ORIGIN/private"])
        self.check()
        (self.library / "libz.so.1").symlink_to("/etc/alternatives/libz")
        self.override("*/libopencv_core.so", runpath=[])
        self.reject("missing or invalid|escapes")

    def test_symbol_versions_must_be_defined_by_the_target(self):
        self.override("*/libopencv_core.so",
                      needs={"libz.so.1": ["ZLIB_1.2.9"]})
        self.reject("does not define")
        self.override("*/libz.so.1", defines=["ZLIB_1.2.0", "ZLIB_1.2.9"])
        self.assertEqual(self.check()["symbol_versions_checked"], 1)
        self.override("*/libopencv_core.so",
                      needs={"libm.so.6": ["GLIBC_2.38"]})
        self.reject("does not name as a dependency")

    def test_loader_configuration_directories(self):
        (self.library / "libz.so.1").unlink()
        (self.sysroot / "opt/extra").mkdir(parents=True)
        (self.sysroot / "opt/extra/libz.so.1").touch()
        self.reject("not on the target loader's search path")
        (self.sysroot / "etc/ld.so.conf.d").mkdir(parents=True)
        (self.sysroot / "etc/ld.so.conf").write_text(
            "include /etc/ld.so.conf.d/*.conf\n")
        (self.sysroot / "etc/ld.so.conf.d/extra.conf").write_text(
            "# target loader\n/opt/extra\n")
        self.check()

    def test_metadata_versions_and_sonames(self):
        self.pkg["version"] = "4.6.1"
        self.reject("versions differ")
        self.pkg["version"] = "4.6.0"
        self.override("*/libopencv_imgproc.so",
                      sonames=["libopencv_imgproc.so.410"])
        self.reject("SONAME")

    def test_unsupported_opencv_versions(self):
        for version in ["3.4.20", "5.1.0", "6.0.0"]:
            with self.subTest(version=version):
                self.pkg["version"] = version
                self.version(*version.split("."))
                self.reject("unsupported OpenCV version")

    def test_metadata_without_backend_library(self):
        self.pkg["libs"] = [f"-L{self.library}", "-lopencv_core"]
        self.reject("lacks -lopencv_imgproc")

    def test_opencv5_without_geometry_module(self):
        self.version(5, 0, 0)
        self.pkg.update(package="opencv5", version="5.0.0",
                        libs=[f"-L{self.library}", "-lopencv_core",
                              "-lopencv_imgproc"])
        self.reject("opencv2/geometry.hpp")
        (self.include / "opencv2/geometry.hpp").touch()
        self.reject("lacks -lopencv_geometry")

    def test_reviewed_gpr_configuration(self):
        original = self.config.read_text()
        for token, message in [(TARGET, "GPR target"),
                               (self.ada, "GPR Ada compiler"),
                               (self.cxx, "GPR C\\+\\+ compiler"),
                               (str(self.runtime), "GPR Ada runtime"),
                               ("Compiler'Driver", "GPR linker")]:
            with self.subTest(token=token):
                self.config.write_text(original.replace(token, "WRONG"))
                self.reject(message)
        self.config.write_text("\n".join(
            "-- " + line for line in original.splitlines()))
        self.reject("GPR target")
        self.config.write_text(original)

    # Symbolic links and containment.

    def test_sysroot_symlink_escapes(self):
        outside = self.base / "outside.hpp"
        outside.touch()
        for link in [self.include / "opencv2/escape.hpp",
                     self.library / "pkgconfig/escape.pc",
                     self.core / "include/opencv_core/escape.ads"]:
            for destination in [outside, self.base / "absent"]:
                with self.subTest(link=link.name, to=destination.name):
                    link.symlink_to(destination)
                    self.reject("escapes|missing or invalid|broken link")
                    link.unlink()

    def test_library_symlink_escape_and_cycle(self):
        library = self.library / "libopencv_imgproc.so"
        library.unlink()
        (self.base / "libopencv_imgproc.so").touch()
        library.symlink_to(self.base / "libopencv_imgproc.so")
        self.reject("escapes")
        library.unlink()
        library.touch()
        loop = self.include / "opencv2/loop"
        loop.symlink_to(self.include / "opencv2")
        self.reject("broken link or cycle")
        loop.unlink()

    def test_dedicated_sysroot(self):
        self.env["ENV_PREFIX"] = "/"
        self.reject("dedicated target sysroot")
        self.env["ENV_PREFIX"] = str(ROOT)
        self.reject("overlaps the Geometry checkout|missing")

    # Workspace: stale output, exact revision and isolation.

    def test_existing_workspace_is_stale(self):
        existing = self.base / "work"
        existing.mkdir()
        self.reject_workspace("must not already exist", destination=existing)
        link = self.base / "work-link"
        link.symlink_to(self.base / "absent")
        self.reject_workspace("must not already exist", destination=link)

    def test_workspace_is_recreated_only_from_scratch(self):
        work = self.run_workspace("--prepare", self.base / "work")
        self.assertTrue((work / "config/opencv_geometry_install.gpr")
                        .is_file())
        self.reject_workspace("must not already exist", destination=work,
                              source=self.base / "source")

    def test_workspace_overlapping_protected_trees(self):
        alias = self.base / "alias"
        alias.symlink_to(self.sysroot)
        for destination in [self.sysroot / "work", self.core / "work",
                            alias / "work",
                            self.source_checkout() / "work"]:
            with self.subTest(destination=destination):
                self.reject_workspace("overlaps", destination=destination)
        self.reject_workspace("absolute", destination="relative/work")

    def test_dirty_or_artifact_bearing_source(self):
        source = self.source_checkout()
        (source / "untracked.txt").touch()
        self.reject_workspace("must be clean", source=source)
        (source / "untracked.txt").unlink()
        (source / "obj").mkdir()
        (source / "obj/stale.o").touch()
        git = ["git", "-C", str(source), "-c", "user.name=t",
               "-c", "user.email=t@example.invalid"]
        subprocess.run(git + ["add", "-f", "obj/stale.o"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", "artifact"], check=True)
        self.reject_workspace("prebuilt artifacts", source=source)

    def test_production_outputs_must_be_target_objects(self):
        self.override("*/opencv-geometry.o", machine="X86-64")
        self.reject_workspace("not ELF64 little-endian AArch64")

    def test_production_outputs_from_another_compiler(self):
        self.override("*/libopencv_geometry_shim.a",
                      comment=["GCC: (GNU) 16.1.0"])
        self.reject_workspace("not built by the supplied compilers")

    def test_installed_metadata_with_host_paths(self):
        self.install_config["link"] = "-L/usr/lib/x86_64-linux-gnu"
        self.reject_workspace("escapes|missing or invalid")


if __name__ == "__main__":
    unittest.main()
