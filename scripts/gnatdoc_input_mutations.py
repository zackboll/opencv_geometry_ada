"""Controlled trusted-input attacks shared by focused and full qualification.

These are observations, never candidate exceptions or authorization inputs.
"""
import hashlib

from validate_gnatdoc_inputs import INPUTS, require


def replace(old, new):
    def mutate(data):
        require(data.count(old) == 1, "attack fixture is not unique")
        return data.replace(old, new, 1)
    return mutate


ATTACKS = (
    ("markdown_version", "docs/requirements.txt", replace(b"3.0.0", b"3.0.1")),
    ("markdown_added", "docs/requirements.txt", lambda b: b + b"unexpected==1.0\n"),
    ("markdown_deleted", "docs/requirements.txt", replace(b"mdurl==0.1.2\n", b"")),
    ("pip_index", "docs/requirements.txt", lambda b: b + b"--extra-index-url https://untrusted.invalid/\n"),
    ("pip_editable", "docs/requirements.txt", lambda b: b + b"-e https://untrusted.invalid/project.git\n"),
    ("pip_url", "docs/requirements.txt", lambda b: b + b"name @ https://untrusted.invalid/pkg.whl\n"),
    ("pip_option", "docs/requirements.txt", lambda b: b + b"--trusted-host untrusted.invalid\n"),
    ("requirements_missing", "docs/requirements.txt", lambda b: None),
    ("requirements_crlf", "docs/requirements.txt", lambda b: b.replace(b"\n", b"\r\n")),
    ("core_constraint", "alire.toml", replace(b">=0.5.0 & <0.6.0", b">=0.5.1 & <0.6.0")),
    ("alire_dependency", "alire.toml", lambda b: b + b'\n[[depends-on]]\nunexpected = "*"\n'),
    ("prebuild_action", "alire.toml", replace(b"scripts/configure_opencv.sh", b"scripts/untrusted.sh")),
    ("unexpected_action", "alire.toml", lambda b: b + b'\n[[actions]]\ntype = "pre-build"\ncommand = ["false"]\n'),
    ("msys_environment", "alire.toml", replace(b"${CRATE_ROOT}/lib", b"${CRATE_ROOT}/untrusted")),
    ("unauthorized_pin", "alire.toml", lambda b: b + b"\n[[pins]]\nopencv_core = { path='/untrusted' }\n"),
    ("aunit_dependency", "tests/alire.toml", replace(b'^26.0.0', b'^25.0.0')),
    ("gnatprove_dependency", "tests/alire.toml", replace(b'^16.1.0', b'^15.1.0')),
    ("gnatcov_dependency", "tests/alire.toml", replace(b'^26.2.1', b'^25.2.1')),
    ("unknown_manifest_key", "alire.toml", lambda b: b'unknown = "unreviewed"\n' + b),
    ("duplicate_version", "alire.toml", lambda b: b'version = "0.3.3"\n' + b),
    ("unreviewed_version", "alire.toml", replace(b'0.3.3', b'0.3.4')),
    ("tests_manifest_missing", "tests/alire.toml", lambda b: None),
    ("root_manifest_missing", "alire.toml", lambda b: None),
    ("manifest_crlf", "alire.toml", lambda b: b.replace(b"\n", b"\r\n")),
)


def observe(candidate, validate, attack):
    """Require a valid before/after and a mutation-specific ValueError only."""
    name, relative, change = attack
    originals = {n: (candidate / n).read_bytes() for n in INPUTS}
    before = validate()
    path = candidate / relative
    replacement = change(originals[relative])
    require(replacement != originals[relative], "unobserved trusted-input attack")
    reason = None
    try:
        if replacement is None:
            path.unlink()
        else:
            path.write_bytes(replacement)
            require(path.read_bytes() == replacement, "trusted-input mutation not installed")
        try:
            validate()
        except ValueError as error:
            reason = str(error)
            expected = ("root manifest", "trusted build input changed: alire.toml") if relative == "alire.toml" else (
                "trusted build input changed: " + relative, "trusted build input missing: " + relative)
            if replacement is None:
                expected = ("trusted build input missing: " + relative,)
            require(any(text in reason for text in expected),
                    "unrelated trusted-input rejection: " + reason)
        else:
            raise AssertionError("trusted-input mutation accepted: " + name)
    finally:
        path.write_bytes(originals[relative])
        require(all((candidate / n).read_bytes() == data for n, data in originals.items()),
                "trusted-input restoration bytes differ")
    require(validate() == before, "trusted-input restored validation differs")
    return {"name": "trusted_input_" + name, "observed": True, "rejection": reason,
            "mutated_sha256": hashlib.sha256(replacement).hexdigest() if replacement is not None else None,
            "original_sha256": hashlib.sha256(originals[relative]).hexdigest(),
            "restored_and_verified": True}