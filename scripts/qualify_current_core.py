#!/usr/bin/env python3
"""Qualify Geometry's native Core links using Imgproc PR #81's current publisher gate.

Source authority remains exact Core 0.5.0. Current publisher discovery, deployment/
workflow/job/history binding, authenticated safe artifacts, complete public source
profiles, native declaration anchors, exact live HTTPS bytes and race rejection
are reused from Imgproc. No policy approval or production enablement is emitted.
"""
import argparse
import html
import io
import json
from pathlib import Path
import re
import stat
import subprocess
import tarfile
import tempfile
import zipfile

from highlight_gnatdoc_ada import strip_highlighting
from link_gnatdoc_types import CORE_PACKAGES, SECTION, plain
from qualify_production_core_links import (
    BASE_URL, fetch, git, public_model, source_native_types, digest, require,
    command, safe_path, write,
)

CORE = "f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f"
TYPE_INPUT = "docs/evidence/gnatdoc009b/core-0.5.0-types.json"
TYPE_SHA = "70fa9a9e5de8ad038bf0bc4bdf6c76ec8ecbe5f201027d18554275f7d9ed7f7f"
REFERENCED_TYPES = frozenset({
    "opencv.angle_unit", "opencv.core.mat", "opencv.float32_point",
    "opencv.float32_value", "opencv.float64_value", "opencv.point_array",
    "opencv.rect", "opencv.rotated_rect",
})


REPO = 'zackboll/opencv_core_ada'
REPOSITORY_API = 'https://api.github.com/repos/' + REPO
CORE_GIT = 'https://github.com/' + REPO + '.git'
WORKFLOW_PATH = '.github/workflows/documentation.yml'
ROOT = Path(__file__).resolve().parents[1]
# Both pages are derived from the approved authority and must equal this set.
REFERENCED_PAGES = frozenset({
    'api/ea2ebcbc108269c77d7c6d44d2dabdfb5f6d0179ad5622b1be3cbceaee5c44aa.html',
    'api/6913f2e7169ad4fb9224d4d93fd20e50615a317c7374a7e469bab89cdd6bb7e9.html',
})
SUFFIXES = frozenset({'.html', '.css', '.js', '.json'})
MEMBER_LIMIT = 8_000_000
TOTAL_LIMIT = 32_000_000
MAX_MEMBERS = 4096
SKIPPED_STATES = frozenset({'failure', 'error'})   # never published content
SHA = re.compile(r'[0-9a-f]{40}')
DIGEST = re.compile(r'sha256:([0-9a-f]{64})')
LOG_URL = re.compile(r'https://github\.com/zackboll/opencv_core_ada/actions/runs/'
                     r'([0-9]+)/job/([0-9]+)')

class GitHubCore:
    """Production transport: authenticated gh API, gh artifact download, git, HTTPS.

    Every byte obtained here is still verified by the caller; this class
    selects nothing and authorizes nothing.
    """

    def __init__(self, witness):
        self.witness = witness
        self.fetched = set()

    def api(self, path):
        return json.loads(command(['gh', 'api', f'repos/{REPO}/{path}']))

    def artifact(self, identifier):
        return command(['gh', 'api', f'repos/{REPO}/actions/artifacts/{identifier}/zip'])

    def _fetched(self, sha):
        require(SHA.fullmatch(sha) is not None, 'invalid Core commit identity')
        if sha not in self.fetched:
            if not (self.witness / '.git').exists():
                subprocess.run(['git', 'init', '--quiet', str(self.witness)], check=True, timeout=30)
            subprocess.run(['git', '-C', str(self.witness), '-c', 'http.followRedirects=false',
                            'fetch', '--quiet', '--no-tags', '--depth=1', CORE_GIT, sha],
                           check=True, timeout=120)
            require(git(self.witness, 'rev-parse', sha + '^{commit}').decode().strip() == sha,
                    'CORE_SOURCE_HISTORY: fetched commit identity differs')
            self.fetched.add(sha)

    def commit_file(self, sha, relative):
        self._fetched(sha)
        return git(self.witness, 'show', sha + ':' + relative)

    def commit_tree(self, sha):
        self._fetched(sha)
        return git(self.witness, 'rev-parse', sha + '^{tree}').decode().strip()

    def fetch(self, relative):
        return fetch(relative)


def ordered(items):
    return sorted(items, key=lambda item: item['id'], reverse=True)


def select_deployment(source):
    """Newest settled successful Pages deployment; never skip an unsettled one."""
    deployments = source.api('deployments?environment=github-pages&per_page=30')
    require(isinstance(deployments, list) and deployments, 'CORE_DEPLOYMENT_UNAVAILABLE: no Pages deployment')
    for deployment in ordered(deployments):
        require(deployment.get('environment') == 'github-pages' and
                deployment.get('task') == 'deploy' and
                deployment.get('repository_url') == REPOSITORY_API,
                'CORE_DEPLOYMENT_IDENTITY: deployment does not belong to the Core Pages environment')
        statuses = source.api(f"deployments/{deployment['id']}/statuses")
        require(isinstance(statuses, list) and statuses,
                'CORE_DEPLOYMENT_UNSETTLED: deployment has no status')
        status = ordered(statuses)[0]
        if status.get('state') in SKIPPED_STATES:
            continue
        require(status.get('state') == 'success',
                'CORE_DEPLOYMENT_UNSETTLED: newest Core Pages deployment is ' + str(status.get('state')))
        return deployment, status
    raise ValueError('CORE_DEPLOYMENT_UNAVAILABLE: no successful Core Pages deployment')


def artifact_identity(record, name, run, sha):
    match = DIGEST.fullmatch(str(record.get('digest')))
    require(record.get('name') == name and record.get('expired') is False and match is not None and
            record.get('workflow_run', {}).get('id') == run['id'] and
            record['workflow_run'].get('head_sha') == sha and
            record['workflow_run'].get('head_branch') == 'main' and
            record['workflow_run'].get('repository_id') == run['repository']['id'] and
            record['workflow_run'].get('head_repository_id') == run['repository']['id'],
            'CORE_ARTIFACT_PROVENANCE: artifact does not belong to the deployed run/source: ' + name)
    return {'id': record['id'], 'name': name, 'sha256': match[1],
            'size_in_bytes': record.get('size_in_bytes'), 'expires_at': record.get('expires_at')}


def provenance(source):
    """Reconstruct the complete current Core publication identity from the API."""
    deployment, status = select_deployment(source)
    sha = deployment.get('sha')
    require(isinstance(sha, str) and SHA.fullmatch(sha) is not None and deployment.get('ref') == 'main',
            'CORE_DEPLOYMENT_IDENTITY: deployment is not an exact main commit')
    log = LOG_URL.fullmatch(str(status.get('log_url')))
    require(status.get('environment_url') == BASE_URL and log is not None,
            'CORE_DEPLOYMENT_IDENTITY: wrong Pages URL or deployment log')
    run_id, job_id = int(log[1]), int(log[2])
    run = source.api(f'actions/runs/{run_id}')
    require(run.get('id') == run_id and run.get('head_sha') == sha and
            run.get('head_branch') == 'main' and run.get('event') == 'push' and
            run.get('path') == WORKFLOW_PATH and run.get('status') == 'completed' and
            run.get('conclusion') == 'success' and
            run.get('repository', {}).get('full_name') == REPO and
            run.get('head_repository', {}).get('full_name') == REPO,
            'CORE_WORKFLOW_IDENTITY: not the successful push-to-main documentation run of the deployed commit')
    jobs = source.api(f'actions/runs/{run_id}/jobs?filter=latest&per_page=100')['jobs']
    found = {}
    for name in ('build', 'deploy'):
        matches = [j for j in jobs if j.get('name') == name]
        require(len(matches) == 1 and matches[0].get('conclusion') == 'success' and
                matches[0].get('run_id') == run_id and matches[0].get('head_sha') == sha,
                'CORE_WORKFLOW_IDENTITY: same-run job missing or unsuccessful: ' + name)
        found[name] = matches[0]['id']
    require(found['deploy'] == job_id, 'CORE_WORKFLOW_IDENTITY: deployment was not made by the deploy job')
    comparison = source.api(f'compare/{sha}...main')
    require(comparison.get('status') in ('identical', 'ahead') and comparison.get('behind_by') == 0,
            'CORE_SOURCE_HISTORY: deployed commit is not in Core main history')
    commit = source.api(f'git/commits/{sha}')
    tree = commit.get('tree', {}).get('sha')
    require(commit.get('sha') == sha and isinstance(tree, str) and SHA.fullmatch(tree) is not None,
            'CORE_SOURCE_HISTORY: commit/tree identity unavailable')
    records = source.api(f'actions/runs/{run_id}/artifacts?per_page=100')['artifacts']
    artifacts = {}
    for key, name in (('review', 'ada-api-' + sha), ('pages', 'github-pages')):
        matches = [a for a in records if a.get('name') == name]
        require(len(matches) == 1, 'CORE_ARTIFACT_PROVENANCE: missing or duplicate artifact: ' + name)
        artifacts[key] = artifact_identity(matches[0], name, run, sha)
    return {'repository': REPO,
            'deployment': {k: deployment.get(k) for k in ('id', 'sha', 'ref', 'environment', 'created_at')},
            'status': {k: status.get(k) for k in ('id', 'state', 'environment_url', 'log_url', 'created_at')},
            'run': {k: run.get(k) for k in ('id', 'run_attempt', 'workflow_id', 'head_sha', 'head_branch',
                                            'event', 'path', 'conclusion')},
            'jobs': found, 'source': sha, 'tree': tree, 'artifacts': artifacts}


def check_member(name, size, total, members):
    name = safe_path(name)
    require(name not in members, 'CORE_ARTIFACT_UNSAFE: duplicate member ' + name)
    require(Path(name).suffix in SUFFIXES, 'CORE_ARTIFACT_UNSAFE: unexpected file type ' + name)
    require(0 <= size <= MEMBER_LIMIT and total + size <= TOTAL_LIMIT and len(members) < MAX_MEMBERS,
            'CORE_ARTIFACT_UNSAFE: oversized member or inventory')
    return name


def authenticated(data, identity):
    require(digest(data) == identity['sha256'],
            'CORE_ARTIFACT_DIGEST: downloaded bytes differ from GitHub artifact digest: ' + identity['name'])


def review_members(data, identity):
    """Upload-artifact ZIP: regular files only, no links, directories or traversal."""
    authenticated(data, identity)
    members, total = {}, 0
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for item in archive.infolist():
            require(not item.is_dir() and not item.flag_bits & 1 and
                    stat.S_IFMT(item.external_attr >> 16) in (0, stat.S_IFREG),
                    'CORE_ARTIFACT_UNSAFE: non-regular or encrypted review member')
            name = check_member(item.filename, item.file_size, total, members)
            total += item.file_size
            members[name] = archive.read(item)
            require(len(members[name]) == item.file_size, 'CORE_ARTIFACT_UNSAFE: member size mismatch')
    return members


def pages_members(data, identity):
    """upload-pages-artifact ZIP containing one tar; never extracts to disk."""
    authenticated(data, identity)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        require(archive.namelist() == ['artifact.tar'], 'CORE_ARTIFACT_UNSAFE: unexpected Pages ZIP inventory')
        entry = archive.getinfo('artifact.tar')
        require(not entry.flag_bits & 1 and entry.file_size <= TOTAL_LIMIT * 2,
                'CORE_ARTIFACT_UNSAFE: Pages tar exceeds limit')
        tar_data = archive.read(entry)
    members, total, directories = {}, 0, set()
    with tarfile.open(fileobj=io.BytesIO(tar_data), mode='r:') as archive:
        for number, entry in enumerate(archive):
            require(number < MAX_MEMBERS * 2, 'CORE_ARTIFACT_UNSAFE: too many Pages tar entries')
            require(entry.isfile() or entry.isdir(), 'CORE_ARTIFACT_UNSAFE: Pages tar link/special file')
            raw = entry.name.removeprefix('./').rstrip('/')
            if entry.isdir():
                if raw not in ('', '.'):
                    name = safe_path(raw)
                    require(name not in directories and name not in members,
                            'CORE_ARTIFACT_UNSAFE: duplicate Pages directory')
                    directories.add(name)
                continue
            name = check_member(raw, entry.size, total, members)
            require(name not in directories, 'CORE_ARTIFACT_UNSAFE: file/directory collision')
            total += entry.size
            with archive.extractfile(entry) as stream:
                members[name] = stream.read(MEMBER_LIMIT + 1)
            require(len(members[name]) == entry.size, 'CORE_ARTIFACT_UNSAFE: member size mismatch')
    return members


def deployed_declarations(source, sha, approved, scratch):
    """Exact public declarations in the deployed commit, compared with indexed 0.5.2."""
    result = {}
    for identity, proof in sorted(approved['types'].items()):
        owner = proof['owner']
        require(proof['source_file'] == 'src/' + CORE_PACKAGES[owner][0],
                'CORE_SOURCE_CHANGED: approved owner/source mapping differs: ' + identity)
        path = scratch / proof['source_file']
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(source.commit_file(sha, proof['source_file']))
        model = public_model(path)
        require(model.package == owner, 'CORE_SOURCE_CHANGED: wrong owner package: ' + identity)
        found = [d for d in model.top if d['scope'].lower() == identity]
        require(len(found) == 1, 'CORE_SOURCE_CHANGED: missing, private or ambiguous declaration: ' + identity)
        declaration = found[0]
        text = '\n'.join(model.lines[declaration['start'] - 1:declaration['end']])
        require(declaration['signature'] == proof['declaration']['signature'] and
                declaration['signature'].split()[0] == proof['kind'] and
                text == proof['source_declaration_text'],
                'CORE_SOURCE_CHANGED: complete declaration/profile differs: ' + identity)
        result[identity] = {'model': model, 'declaration': declaration,
                            'source_sha256': digest(path.read_bytes())}
    return result


def native_destination(page, proof, model, declaration):
    """One genuine section per approved anchor, bound to the exact declaration."""
    anchor = proof['native_anchor']
    headings = re.findall(r'<h1>([^<]+)</h1>', page)
    require(len(headings) == 1 and headings[0].lower() == proof['owner'],
            'CORE_LINK_COMPATIBILITY_BLOCKED: wrong or ambiguous native owner page: ' + proof['identity'])
    require(page.count('id=' + anchor + '>') == 1 and page.count('id="' + anchor + '"') == 0 and
            page.count("id='" + anchor + "'") == 0,
            'CORE_LINK_COMPATIBILITY_BLOCKED: missing or duplicate native anchor: ' + proof['identity'])
    sections = [s for s in SECTION.finditer(page) if s[1] == anchor]
    require(len(sections) == 1, 'CORE_LINK_COMPATIBILITY_BLOCKED: anchor is not a declaration: ' + proof['identity'])
    section = sections[0]
    raw = plain(strip_highlighting(section[3]))
    snippet = html.unescape(raw)
    require(section[2] == proof['identity'].rpartition('.')[2] and snippet == proof['native_snippet'],
            'CORE_LINK_COMPATIBILITY_BLOCKED: substituted native declaration: ' + proof['identity'])
    matched = model.match(raw)
    require(matched['scope'].lower() == proof['identity'].lower() and
            (matched['start'], matched['end']) == (declaration['start'], declaration['end']),
            'CORE_LINK_COMPATIBILITY_BLOCKED: native snippet does not denote the approved declaration: ' +
            proof['identity'])
    return snippet


def verify_publication(source, record, approved, scratch):
    sha = record['source']
    require(source.commit_tree(sha) == record['tree'], 'CORE_SOURCE_HISTORY: fetched tree differs from API tree')
    review = review_members(source.artifact(record['artifacts']['review']['id']), record['artifacts']['review'])
    pages = pages_members(source.artifact(record['artifacts']['pages']['id']), record['artifacts']['pages'])
    require(review == pages, 'CORE_ARTIFACT_INVENTORY: review and Pages artifacts differ')
    referenced = {proof['native_page'] for proof in approved['types'].values()}
    require(referenced == REFERENCED_PAGES and referenced <= set(review),
            'CORE_LINK_COMPATIBILITY_BLOCKED: referenced native page missing from authenticated publication')
    declarations = deployed_declarations(source, sha, approved, scratch)
    proofs = {}
    for identity, proof in sorted(approved['types'].items()):
        page = review[proof['native_page']]
        found = declarations[identity]
        snippet = native_destination(page.decode('utf-8'), proof, found['model'], found['declaration'])
        proofs[identity] = dict(proof, url=BASE_URL + proof['native_page'] + '#' + proof['native_anchor'],
                                hosted_page_sha256=digest(page), hosted_source_sha256=found['source_sha256'],
                                hosted_source_declaration=found['declaration'], hosted_snippet=snippet,
                                hosted_revision=sha)
    hosted = {}
    for name in sorted(REFERENCED_PAGES):
        live = source.fetch(name)
        require(live == review[name], 'CORE_LIVE_STALE: public HTTPS bytes differ from authenticated artifact: ' + name)
        hosted[name] = digest(live)
    inventory = {name: digest(data) for name, data in sorted(review.items())}
    return proofs, hosted, inventory


def authority(core, native):
    """Reconstruct from the existing immutable Core 0.5.0 source/native ledger."""
    path = ROOT / TYPE_INPUT
    require(not path.is_symlink() and digest(path.read_bytes()) == TYPE_SHA,
            'SOURCE_AUTHORITY_CHANGED: Core 0.5.0 ledger differs')
    record = json.loads(path.read_text())
    require(record['revision'] == CORE and
            git(core, 'rev-parse', 'HEAD').decode().strip() == CORE and
            not git(core, 'status', '--porcelain', '--untracked-files=no'),
            'SOURCE_AUTHORITY_CHANGED: Core witness is not clean exact 0.5.0')
    for name, expected in record['source_sha256'].items():
        source = core / safe_path(name)
        require(not any(p.is_symlink() for p in (source, *source.parents)) and
                digest(source.read_bytes()) == expected,
                'SOURCE_AUTHORITY_CHANGED: Core source differs: ' + name)
    actual = {p.relative_to(native).as_posix(): digest(p.read_bytes())
              for p in native.rglob('*') if p.is_file()}
    require(not any(p.is_symlink() for p in native.rglob('*')) and
            actual == record['native_sha256'], 'SOURCE_AUTHORITY_CHANGED: Core native differs')
    types = source_native_types(core, native, REFERENCED_TYPES)
    for identity, proof in types.items():
        expected = record['types'][identity]
        require((proof['native_page'], proof['native_anchor'], proof['native_snippet_sha256']) ==
                ('api/' + expected['page'], expected['anchor'], expected['native_declaration_sha256']),
                'SOURCE_AUTHORITY_CHANGED: Core declaration differs: ' + identity)
    return {'types': types}


def qualify(args, source=None):
    output = args.output.absolute()
    require(not output.exists(), 'Core evidence directory must be new')
    approved = authority(args.core, args.native)
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='geometry-core-') as tmp:
        source = source or GitHubCore(Path(tmp) / 'witness')
        before = provenance(source)
        if getattr(args, 'expect', None) is not None:
            require(before == json.loads(args.expect.read_text()),
                    'CORE_DEPLOYMENT_RACE: Core publication changed during this build')
        write(output / 'provenance-before.json', before)
        proofs, hosted, inventory = verify_publication(
            source, before, approved, Path(tmp) / 'deployed-source')
        try:
            after = provenance(source)
        except ValueError as error:
            raise ValueError('CORE_DEPLOYMENT_RACE: ' + str(error)) from error
        require(before == after, 'CORE_DEPLOYMENT_RACE: Core deployment changed during qualification')
    for name, data in (('referenced-types', proofs), ('hosted-sha256', hosted),
                       ('publication-inventory', inventory), ('provenance-after', after)):
        write(output / (name + '.json'), data)
    return after


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('core', 'native', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--expect', type=Path)
    qualify(parser.parse_args())
