"""Disposable, exact policy-owned additive fixture. Never release these APIs.

This generator intentionally writes only a new temporary checkout. It is test
infrastructure, not a repository editing or authority-update command.
"""
from pathlib import Path
import subprocess

from additive_gnatdoc_policy import ROOT, GUIDE, EXAMPLE, regular, require, git

NAME = "Policy_Probe"
SPEC = """
   --  Synthetic policy fixture, not a production operation.
   --  @param Value The finite fixture coefficient.
   --  @return An independent affine fixture value.
   function Policy_Probe
     (Value : OpenCV.Float64_Value) return Affine_Transform_2D;

   --  Second synthetic overload, not a production operation.
   --  @param Value The fixture perspective value.
   --  @return The first coefficient for the fixture assertion.
   function Policy_Probe
     (Value : Perspective_Transform_2D) return OpenCV.Float64_Value;

"""
BODY = """
   function Policy_Probe
     (Value : OpenCV.Float64_Value) return Affine_Transform_2D
   is
      Result : Affine_Transform_2D := Identity_Affine_Transform;
   begin
      Result (1, 3) := Value;
      return Result;
   end Policy_Probe;

   function Policy_Probe
     (Value : Perspective_Transform_2D) return OpenCV.Float64_Value
   is (Value (1, 1));

"""
TEST_SPEC = """with AUnit.Test_Suites;

package Policy_Probe_Tests is
   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Policy_Probe_Tests;
"""
TEST_BODY = """with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with OpenCV.Geometry;

package body Policy_Probe_Tests is
   use OpenCV.Geometry;
   use type OpenCV.Float64_Value;
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   procedure Probe (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Value : constant Affine_Transform_2D := Policy_Probe (7.0);
   begin
      AUnit.Assertions.Assert
        (Value (1, 3) = 7.0
         and then Policy_Probe (Identity_Perspective_Transform) = 1.0,
         "both synthetic overloads execute");
   end Probe;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create ("Policy synthetic additive overloads", Probe'Access));
      return Result'Access;
   end Suite;
end Policy_Probe_Tests;
"""


def replace_once(text, before, after):
    require(text.count(before) == 1, "fixture insertion point is not unique")
    return text.replace(before, after, 1)


def expected(source):
    import json
    result = {}
    for name, fragment in (("src/opencv-geometry.ads", SPEC),
                           ("src/opencv-geometry.adb", BODY)):
        result[name] = replace_once(regular(source / name).decode(),
                                   "end OpenCV.Geometry;", fragment.lstrip("\n") + "end OpenCV.Geometry;")
    categories = json.loads(regular(source / "docs/api-categories.json"))
    group = next(g for g in categories["packages"][0]["categories"] if g["id"] == "transforms")
    group["declarations"].append(NAME)
    result["docs/api-categories.json"] = json.dumps(categories, indent=2) + "\n"
    example = replace_once(regular(source / EXAMPLE).decode(), "begin\n   pragma Assert",
        "begin\n   pragma Assert (Policy_Probe (7.0) (1, 3) = 7.0);\n"
        "   pragma Assert\n     (Policy_Probe (Identity_Perspective_Transform) = 1.0);\n"
        "   pragma Assert")
    result[EXAMPLE] = example
    guide = regular(source / GUIDE).decode()
    old_example = regular(source / EXAMPLE).decode().rstrip()
    require(old_example in guide, "guide does not contain the exact original example")
    guide = replace_once(guide, old_example, example.rstrip())
    result[GUIDE] = guide + ("\n## Disposable policy fixture\n\n"
        "The [first probe](api:Policy_Probe/1) and "
        "[second probe](api:Policy_Probe/2) exist only in this disposable test.\n")
    result["tests/src/policy_probe_tests.ads"] = TEST_SPEC
    result["tests/src/policy_probe_tests.adb"] = TEST_BODY
    result["tests/src/tests.adb"] = replace_once(
        replace_once(regular(source / "tests/src/tests.adb").decode(),
                     "with Versioned_Feature_Tests;",
                     "with Versioned_Feature_Tests;\nwith Policy_Probe_Tests;"),
        "   Suite.Add_Test (Versioned_Feature_Tests.Suite);",
        "   Suite.Add_Test (Versioned_Feature_Tests.Suite);\n"
        "   Suite.Add_Test (Policy_Probe_Tests.Suite);")
    return {name: text.encode() for name, text in result.items()}


def validate(candidate, policy):
    expected_files = expected(policy)
    policy_revision = git(policy, "rev-parse", "HEAD").decode().strip()
    names = git(candidate, "diff", "--name-only", policy_revision, "HEAD").decode().splitlines()
    require(set(names) == set(expected_files), "synthetic fixture contains non-fixture changes")
    for name, payload in expected_files.items():
        require(regular(candidate / name) == payload, "synthetic fixture changed: " + name)


def create(target, policy_revision):
    require(not target.exists() and not target.is_relative_to(ROOT), "fixture must be a new disposable path")
    subprocess.run(["git", "clone", "--no-hardlinks", str(ROOT), str(target)], check=True)
    subprocess.run(["git", "checkout", "--detach", policy_revision], cwd=target, check=True)
    for name, payload in expected(target).items():
        (target / name).write_bytes(payload)
    subprocess.run(["git", "add", "src", "tests/src", "docs"], cwd=target, check=True)
    subprocess.run(["git", "-c", "user.name=Policy fixture", "-c",
                    "user.email=fixture@invalid.example", "commit", "-m",
                    "Disposable additive policy fixture - not for release"], cwd=target, check=True)
    return git(target, "rev-parse", "HEAD").decode().strip()