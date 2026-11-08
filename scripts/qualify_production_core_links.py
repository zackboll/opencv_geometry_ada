#!/usr/bin/env python3
"""Imgproc native Core declaration matching and bounded transport, adapted for Geometry.

Reused from opencv_imgproc_ada main a777f331 (PR #81 implementation).
No historical publication identities or candidate-selected destinations.
"""
import hashlib
import html
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time
import urllib.request

from link_gnatdoc_types import CORE_PACKAGES, SECTION, Package, plain, visible_declarations

BASE_URL = "https://zackboll.github.io/opencv_core_ada/"
TOTAL_LIMIT = 32 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")


class CommandError(ValueError):
    """Safe external-command diagnostics; never include arguments or raw output."""

    def __init__(self, classification, stdout_bytes, stderr_bytes, status=None):
        self.classification = classification
        self.status = status
        super().__init__(f'external command {classification}: status={status}, '
                         f'stdout_bytes={stdout_bytes}, stderr_bytes={stderr_bytes}')


def command(args, cwd=None, limit=TOTAL_LIMIT, timeout=120):
    """POSIX bounded capture: one deadline for both pipes AND process exit.

    Stderr is drained but not retained: raw tool diagnostics/arguments can contain
    credentials. No temporary output file can grow without bound. A new session
    lets failure cleanup kill descendants that inherited a pipe, even if their
    immediate parent exited. Only a successful exit with complete EOF is returned.
    """
    require(type(limit) is int and 0 <= limit <= TOTAL_LIMIT, 'invalid command output limit')
    require(isinstance(timeout, (int, float)) and 0 < timeout <= 120,
            'invalid command deadline')
    deadline = time.monotonic() + timeout
    data, stderr_bytes = bytearray(), 0
    with subprocess.Popen(args, cwd=cwd, stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          start_new_session=True) as process:
        succeeded = False

        def failure(classification, status=None):
            return CommandError(classification, len(data), stderr_bytes, status)

        def remaining():
            seconds = deadline - time.monotonic()
            if seconds <= 0:
                raise failure('timeout')
            return seconds

        try:
            with selectors.DefaultSelector() as selector:
                for stream in (process.stdout, process.stderr):
                    os.set_blocking(stream.fileno(), False)
                    selector.register(stream, selectors.EVENT_READ)
                while selector.get_map():
                    for key, _ in selector.select(remaining()):
                        remaining()
                        stream = key.fileobj
                        allowance = limit - len(data) if stream is process.stdout else 65536 - stderr_bytes
                        try:
                            chunk = os.read(stream.fileno(), min(65536, allowance + 1))
                        except BlockingIOError:
                            continue
                        if not chunk:
                            selector.unregister(stream)
                        elif stream is process.stdout:
                            data.extend(chunk)
                            if len(data) > limit:
                                raise failure('oversized_output')
                        else:
                            stderr_bytes += len(chunk)
                            if stderr_bytes > 65536:
                                raise failure('oversized_output')
            try:
                status = process.wait(timeout=remaining())
            except subprocess.TimeoutExpired:
                raise failure('timeout') from None
            remaining()
            if status != 0:
                raise failure('nonzero_status', status)
            succeeded = True
            return bytes(data)
        finally:
            if not succeeded:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()  # Reap after SIGKILL; never wait on a live child.


def safe_path(name):
    require(isinstance(name, str) and re.fullmatch(r'[A-Za-z0-9_.\-/]+', name)
            and all(p not in ('', '.', '..') for p in name.split('/')),
            f'unsafe repository path: {name}')
    return name


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Core hosting redirect rejected: " + newurl)


def fetch(relative):
    require(re.fullmatch(r"(?:(?:api|guides)/)?[A-Za-z0-9_-]+\.(?:html|css|js|json)", relative) is not None,
            "unexpected hosted artifact path")
    url = BASE_URL + relative
    with urllib.request.build_opener(NoRedirect).open(url, timeout=90) as response:
        require(response.status == 200 and response.url == url, "Core hosting identity changed")
        data = response.read(8_000_001)
        require(len(data) <= 8_000_000, "oversized Core hosted file")
        length = response.headers.get("Content-Length")
        require(length is None or len(data) == int(length), "incomplete Core hosted file")
        return data


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True).stdout


def public_model(spec):
    package, lines, declarations = visible_declarations(spec)
    source = Package.__new__(Package)
    source.package, source.lines, source.declarations = package, lines, declarations
    source.top = [d for d in declarations if d["scope"].lower() ==
                  package + "." + d["name"].lower()]
    return source


def source_native_types(core, native, wanted):
    """Find genuine type sections, matching full source profiles, not names only."""
    models = {owner: public_model(core / "src" / filename)
              for owner, (filename, _) in CORE_PACKAGES.items()}
    pages = {}
    for path in sorted((native / "api").glob("*.html")):
        headings = re.findall(r"<h1>([^<]+)</h1>", path.read_text())
        if headings and headings[0].lower() in models:
            owner = headings[0].lower()
            require(owner not in pages and len(headings) == 1, "ambiguous Core package")
            pages[owner] = path
    require(set(pages) == set(models), "missing Core owner package")
    result = {}
    for owner, model in models.items():
        text = pages[owner].read_text()
        for section in SECTION.finditer(text):
            identity = owner + "." + section[2].lower()
            if identity not in wanted:
                continue
            declaration = model.match(section[3])
            require(declaration["scope"].lower() == identity and
                    declaration["signature"].split()[0] in {"type", "subtype"},
                    "Core target is not an exact visible type/subtype")
            require(identity not in result, "ambiguous Core declaration")
            filename = CORE_PACKAGES[owner][0]
            path = core / "src" / filename
            content = "\n".join(model.lines[declaration["start"] - 1:declaration["end"]])
            result[identity] = {
                "identity": declaration["scope"], "owner": owner,
                "kind": declaration["signature"].split()[0], "source_file": "src/" + filename,
                "source_file_sha256": digest(path.read_bytes()), "declaration": declaration,
                "source_declaration_text": content, "source_declaration_sha256": digest(content.encode()),
                "native_page": "api/" + pages[owner].name,
                "native_page_sha256": digest(pages[owner].read_bytes()),
                "native_anchor": section[1], "native_anchor_sha256": digest(section[1].encode()),
                "native_snippet": html.unescape(section[3]),
                "native_snippet_sha256": digest(html.unescape(section[3]).encode())}
    require(set(result) == set(wanted), "Core source/native target census incomplete")
    return result

