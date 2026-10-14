#!/usr/bin/env python3
"""Tests for the comment-only qualification check."""

import subprocess
import tempfile
import unittest
from pathlib import Path

from check_comment_only import compare, strip_comments

SPEC = (
    "package Demo is\n"
    "   pragma Preelaborate;\n"
    "   --  Documentation.\n"
    "   Label : constant String := \"a -- b\";\n"
    "   Dash  : constant Character := '-';\n"
    "   Big   : constant := 2**31 - 1;\n"
    "   procedure Run (Value : Integer := 1);  --  trailing\n"
    "   function Last (Values : Vector) return Natural\n"
    "   with Post => Last'Result <= Values'Length;\n"
    "end Demo;\n"
)


class StripCommentsTest(unittest.TestCase):
    def test_comments_and_layout_are_ignored(self):
        edited = SPEC.replace("   --  Documentation.\n",
                              "   --  New text.\n   --  @param Value Rewritten.\n")
        edited = edited.replace("(Value : Integer := 1);  --  trailing",
                                "\n     (Value : Integer := 1);")
        self.assertEqual(strip_comments(SPEC), strip_comments(edited))

    def test_string_contents_are_code(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace('"a -- b"', '"a -- c"')))

    def test_character_literal_is_code(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace("'-'", "'+'")))

    def test_declaration_change_is_detected(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace(":= 1", ":= 2")))

    def test_numeric_literal_change_is_detected(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace("2**31 - 1", "2**31 - 2")))

    def test_pragma_change_is_detected(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace("pragma Preelaborate;\n", "")))

    def test_contract_change_is_detected(self):
        self.assertNotEqual(strip_comments(SPEC),
                            strip_comments(SPEC.replace("<= Values'Length",
                                                        "< Values'Length")))

    def test_commented_out_contract_is_detected(self):
        self.assertNotEqual(
            strip_comments(SPEC),
            strip_comments(SPEC.replace("   with Post", "   --  with Post")))


class RepositoryCompareTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for directory in ("src", "cpp", "docs", "tests"):
            (self.root / directory).mkdir()
        self.spec = self.root / "src/demo.ads"
        self.spec.write_text(SPEC, encoding="utf-8")
        (self.root / "cpp/shim.cpp").write_text("int f() { return 1; }\n",
                                                encoding="utf-8")
        (self.root / "tests/test.adb").write_text("procedure Test is begin null; "
                                                  "end Test;\n", encoding="utf-8")
        (self.root / "alire.toml").write_text('name = "demo"\n', encoding="utf-8")
        (self.root / "docs/notes.md").write_text("Notes.\n", encoding="utf-8")
        self.git("init", "-q")
        self.commit("base")

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *arguments):
        subprocess.run(["git", "-C", str(self.root), *arguments], check=True,
                       capture_output=True)

    def commit(self, message):
        self.git("add", "-A")
        self.git("-c", "user.name=t", "-c", "user.email=t@example.com",
                 "commit", "-q", "--allow-empty", "-m", message)

    def write(self, name, text):
        (self.root / name).write_text(text, encoding="utf-8")

    def test_comment_edit_passes_and_code_edit_fails(self):
        self.spec.write_text(SPEC.replace("Documentation.", "Better words."),
                             encoding="utf-8")
        self.commit("comments")
        self.assertEqual(compare("HEAD~1", "HEAD", self.root), [])
        self.spec.write_text(SPEC.replace("Integer := 1", "Natural := 1"),
                             encoding="utf-8")
        self.commit("code")
        self.assertEqual(compare("HEAD~2", "HEAD", self.root),
                         ["code changed: src/demo.ads"])

    def test_added_source_is_reported(self):
        self.write("src/extra.ads", "package Extra is\nend Extra;\n")
        self.commit("extra")
        self.assertEqual(compare("HEAD~1", "HEAD", self.root),
                         ["added: src/extra.ads"])

    def test_removed_source_is_reported(self):
        self.spec.unlink()
        self.commit("remove")
        self.assertEqual(compare("HEAD~1", "HEAD", self.root),
                         ["removed: src/demo.ads"])

    def test_shim_manifest_and_test_changes_are_reported(self):
        self.write("cpp/shim.cpp", "int f() { return 2; }\n")
        self.write("alire.toml", 'name = "demo"\n\n[[pins]]\n')
        (self.root / "tests/test.adb").unlink()
        self.commit("production")
        self.assertEqual(compare("HEAD~1", "HEAD", self.root), [
            "production file changed: alire.toml",
            "production file changed: cpp/shim.cpp",
            "production file changed: tests/test.adb",
        ])

    def test_documentation_and_new_tooling_are_allowed(self):
        self.write("docs/notes.md", "Rewritten notes.\n")
        self.write("docs/guide.md", "Guide.\n")
        self.write("README.md", "Readme.\n")
        (self.root / "scripts").mkdir()
        self.write("scripts/check.py", "print('ok')\n")
        self.commit("documentation")
        self.assertEqual(compare("HEAD~1", "HEAD", self.root), [])

    def test_uncommitted_changes_do_not_affect_the_comparison(self):
        self.write("alire.toml", 'name = "demo"\n\n[[pins]]\n')
        self.spec.write_text(SPEC.replace("Integer := 1", "Natural := 1"),
                             encoding="utf-8")
        self.assertEqual(compare("HEAD", "HEAD", self.root), [])


if __name__ == "__main__":
    unittest.main()
