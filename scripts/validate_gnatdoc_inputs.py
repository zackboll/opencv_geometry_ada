#!/usr/bin/env python3
"""Standard-library-only preflight, executed from the selected policy checkout.

No candidate module, package manager, executable action or pip input is loaded.
Authorization is reviewed policy bytes, not the candidate's Git snapshot.
"""
import argparse
from pathlib import Path
import re
import tomllib

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ("docs/requirements.txt", "alire.toml", "tests/alire.toml")
# PR #56 is the only reviewed version exception. This does not authorize
# another release, a downgrade, or any accompanying manifest setting change.
VERSION_TRANSITIONS = frozenset({("0.3.2", "0.3.3")})
VERSION = re.compile(rb'^version = "(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"\n', re.M)
PINS = {"alire.toml": "../core", "tests/alire.toml": "../../core"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def payload(root, name):
    path = root / name
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            "trusted build input is substituted: " + name)
    require(path.is_file(), "trusted build input missing: " + name)
    return path.read_bytes()


def version(data):
    try:
        parsed = tomllib.loads(data.decode("utf-8"))
    except (UnicodeError, tomllib.TOMLDecodeError) as error:
        raise ValueError("root manifest invalid TOML: " + str(error)) from error
    matches = list(VERSION.finditer(data))
    require(len(matches) == 1, "root manifest ambiguous version field")
    match = matches[0]
    value = b".".join(match.groups()).decode("ascii")
    require(parsed.get("version") == value, "root manifest ambiguous version field")
    return value, match


def compatible_root(reviewed, candidate):
    old, before = version(reviewed)
    new, after = version(candidate)
    require(new == old or (old, new) in VERSION_TRANSITIONS,
            "root manifest unreviewed version transition")
    normalized = candidate[:after.start()] + before.group() + candidate[after.end():]
    require(normalized == reviewed, "trusted build input changed: alire.toml")


def validate(candidate, policy=ROOT, qualification_pins=False):
    values = {}
    for name in INPUTS:
        reviewed = payload(policy, name)
        value = payload(candidate, name)
        if qualification_pins and name in PINS:
            suffix = ("\n[[pins]]\nopencv_core = { path='" + PINS[name] + "' }\n").encode()
            require(value.endswith(suffix), "qualification Core pin differs: " + name)
            value = value[:-len(suffix)]
        if name == "alire.toml":
            compatible_root(reviewed, value)
        else:
            require(value == reviewed, "trusted build input changed: " + name)
        values[name] = value
    return values


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    args = parser.parse_args()
    validate(args.candidate.absolute())
    print("Trusted build inputs verified before candidate installation/actions")