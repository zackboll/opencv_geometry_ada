#!/usr/bin/env python3
"""Prove that documentation edits changed only Ada comments.

Two committed revisions are compared, so uncommitted local state (such as
the temporary opencv_core pin in `alire.toml`) can never hide or create a
difference:

- Every Ada source under `src/` must have the same code at both revisions
  after removing comments and normalizing whitespace. String and character
  literals are kept verbatim, so a changed literal, declaration, default,
  pragma, aspect or contract is reported, as is an added or removed file.
- Every other file tracked at the base revision must be byte-identical and
  still present, except documentation (`docs/`, `README.md`) and
  `.gitignore`: this covers the C++ shim, the tests, `alire.toml`, the
  production GPR projects, the build and configuration scripts and the
  cross-platform workflow. New files outside `src/`, such as documentation
  tooling, are allowed.

Used to qualify documentation-only changes; it is not a CI gate because
ordinary feature work legitimately changes declarations. Adapted from
opencv_imgproc_ada `main` 19ce3641.
"""

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADA_SUFFIXES = (".ads", ".adb")
DOCUMENTATION = ("docs/", "README.md", ".gitignore")


def strip_comments(text):
    """Return Ada code tokens with comments removed and literals preserved."""
    tokens = []
    for line in text.splitlines():
        code = []
        index = 0
        while index < len(line):
            if line.startswith("--", index):
                break
            character = line[index]
            if character == '"':
                end = index + 1
                while end < len(line):
                    if line[end] == '"':
                        if line.startswith('""', end):
                            end += 2
                            continue
                        break
                    end += 1
                code.append(line[index:end + 1])
                index = end + 1
                continue
            if (character == "'" and index + 2 < len(line) and line[index + 2] == "'"
                    and not (index and (line[index - 1].isalnum() or line[index - 1] in "_)"))):
                code.append(line[index:index + 3])
                index += 3
                continue
            code.append(character)
            index += 1
        tokens.extend("".join(code).split())
    return tokens


def _git(root, *arguments):
    return subprocess.run(["git", "-C", str(root), *arguments],
                          check=True, capture_output=True, text=True).stdout


def _documentation(name):
    return any(name == item or (item.endswith("/") and name.startswith(item))
               for item in DOCUMENTATION)


def compare(revision, target="HEAD", root=ROOT):
    """Return the differences that are not documentation-only."""
    def sources(commit):
        listed = _git(root, "ls-tree", "-r", "--name-only", commit, "src").split()
        return {name for name in listed if name.endswith(ADA_SUFFIXES)}

    before, after = sources(revision), sources(target)
    differences = [f"added: {name}" for name in sorted(after - before)]
    differences += [f"removed: {name}" for name in sorted(before - after)]
    for name in sorted(before & after):
        old = _git(root, "show", f"{revision}:{name}")
        new = _git(root, "show", f"{target}:{name}")
        if strip_comments(old) != strip_comments(new):
            differences.append(f"code changed: {name}")
    changed = _git(root, "diff", "--name-status", "--no-renames", revision, target)
    for line in changed.splitlines():
        status, name = line.split("\t", 1)
        if name.startswith("src/") or _documentation(name):
            continue
        if status == "A":
            continue
        differences.append(f"production file changed: {name}")
    return differences


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("revision", help="base Git revision")
    parser.add_argument("target", nargs="?", default="HEAD",
                        help="documentation revision to qualify (default HEAD)")
    args = parser.parse_args(argv)
    differences = compare(args.revision, args.target)
    for difference in differences:
        print(difference)
    if differences:
        return 1
    print(f"{args.target} differs from {args.revision} only in Ada comments, "
          "documentation and new documentation tooling")
    return 0


if __name__ == "__main__":
    sys.exit(main())
