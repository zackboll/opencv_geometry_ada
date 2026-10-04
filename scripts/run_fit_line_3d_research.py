#!/usr/bin/env python3
"""Opt-in Task 020 research. No OpenCV is loaded into this controller.

build uses explicit include/library directories, not an inferred version.
run replays JSONL cases in isolated children; every result is fsync'd, and
resume checks executable and corpus hashes. Linux/Python 3.9+, stdlib only.
certificate proves subset-selection termination for the exact OpenCV RNG.
Timeouts are protection for research, never a proof or production contract.
"""
import argparse
import contextlib
import hashlib
import io
import json
import math
import os
from pathlib import Path
import random
import re
import resource
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
MODELS = ("L2", "L1", "L12", "Fair", "Welsch", "Huber")
MASK = (1 << 64) - 1
MAX_ROBUST_COUNT = ((1 << 31) - 1) // 2


def bits(x):
    return struct.pack('>f', x).hex()


def value(s):
    if not isinstance(s, str) or not re.fullmatch('[0-9a-fA-F]{8}', s):
        raise ValueError('expected exactly eight Float32 hex digits')
    return struct.unpack('>f', bytes.fromhex(s))[0]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate(c):
    required = {'id', 'depth', 'model', 'scalars', 'points'}
    if (not isinstance(c, dict) or not required <= c.keys()
        or c.keys() - required - {'expected', 'family'}):
        raise ValueError('case schema drift')
    if not isinstance(c['id'], str) or not c['id']:
        raise ValueError('bad id')
    if c['depth'] not in ('f32', 'i32') or c['model'] not in MODELS:
        raise ValueError('bad depth/model')
    if not isinstance(c['scalars'], list) or len(c['scalars']) != 3:
        raise ValueError('three scalar strings required')
    for s in c['scalars']:
        if not isinstance(s, str):
            raise ValueError('scalar must be a string')
        if not re.fullmatch(r'[+-]?(?:0x[0-9a-f]+(?:\.[0-9a-f]*)?p[+-]?[0-9]+|inf|nan)', s):
            raise ValueError('scalar must be canonical hex float or inf/nan')
        float.fromhex(s)
    if not isinstance(c['points'], list) or not 1 <= len(c['points']) <= 1000000:
        raise ValueError('probe count range')
    for pt in c['points']:
        if not isinstance(pt, list) or len(pt) != 3:
            raise ValueError('three coordinates required')
        for x in pt:
            if c['depth'] == 'f32':
                value(x)
            elif type(x) is not int or not -(1 << 31) <= x < (1 << 31):
                raise ValueError('bad signed integer')
    if 'expected' in c:
        e = c['expected']
        if len(e) != 3 or not all(math.isfinite(x) for x in e) or not any(e):
            raise ValueError('bad expected direction')


def serialize(c):
    validate(c)
    header = ['FL3D1', c['depth'], c['model'], *c['scalars'],
              str(len(c['points']))]
    return ' '.join(header) + '\n' + '\n'.join(
        ' '.join(map(str, pt)) for pt in c['points']) + '\n'


def candidate_pre_eigen(c):
    """Exploratory front-end envelope, NOT a complete accepted contract.

    gamma_(n+4) rounds the products/sums; n<=2**20 keeps gamma<0.067.
    The 2**120 aggregate budget leaves >200-fold FLT_MAX headroom but
    has NOT been propagated through all eigen backends. Float64 sums of
    positive terms need their own outward rounding in a future Ada proof.
    """
    pts = [[value(x) for x in p] if c['depth'] == 'f32'
           else [value(bits(x)) for x in p] for p in c['points']]
    n = len(pts)
    if n > 2**20 or not all(math.isfinite(x) for p in pts for x in p):
        return False
    sums = [sum(abs(p[j]) for p in pts) for j in range(3)]
    sums += [sum(p[j]*p[j] for p in pts) for j in range(3)]
    sums += [sum(abs(p[j]*p[k]) for p in pts) for j,k in ((0,1),(0,2),(1,2))]
    # This numerical budget is exploratory, not a certified eigen factor.
    if max(sums) > 2.**120:
        return False
    m = max(abs(x) for pt in pts for x in pt)
    if c['model'] != 'L2' and (16*m)**2 > 2.**120:
        return False
    s = [float.fromhex(x) for x in c['scalars']]
    if not all(math.isfinite(x) and 0 <= x <= value('7f7fffff') for x in s):
        return False
    p = value(bits(s[0]))
    if c['model'] in ('Fair','Welsch') and p != 0:
        # Conservatively bound d by 16*max-coordinate for experiments.
        # This bound assumes a normalized eigenvector; it is NOT a proof
        # of the eigenvector premise.
        d = 16*m
        reciprocal = 1/p
        if reciprocal > value('7f7fffff')/4:
            return False
        if c['model'] == 'Fair' and d*reciprocal > 2.**120:
            return False
        if c['model'] == 'Welsch' and d*d*max(1., reciprocal, reciprocal**2) > 2.**120:
            return False
    return True


def read_corpus(path):
    cases = [json.loads(s) for s in Path(path).read_text().splitlines() if s]
    for c in cases:
        validate(c)
    if len({c['id'] for c in cases}) != len(cases):
        raise ValueError('duplicate corpus id')
    return cases


def rng_outputs(n):
    state = MASK  # RNG((uint64)-1), not the default 0xffffffff
    result = []
    for _ in range(n):
        state = ((state & 0xffffffff) * 4164903690 + (state >> 32)) & MASK
        result.append(state & 0xffffffff)
    return result


def primes():
    # Differences of unsigned outputs are < 2**32; trial division needs
    # primes only through 65535. This is exact integer arithmetic.
    sieve = bytearray(b'\1') * 65536
    sieve[0:2] = b'\0\0'
    for p in range(2, 256):
        if sieve[p]:
            sieve[p*p::p] = b'\0' * len(sieve[p*p::p])
    return [i for i, yes in enumerate(sieve) if yes]


def divisors(n, ps):
    if n == 0:
        raise ValueError('equal outputs invalidate noncandidate argument')
    ds = [1]
    for p in ps:
        if p*p > n:
            break
        power, extra = 1, []
        while n % p == 0:
            n //= p
            power *= p
            extra.extend(d * power for d in ds)
        ds.extend(extra)
    if n > 1:
        ds += [d*n for d in ds]
    return ds


def selection_draws(n, outputs):
    index = 0
    for _ in range(20):
        seen = set()
        while len(seen) < min(n, 10):
            if index == len(outputs):
                raise ValueError(f'certificate prefix insufficient for N={n}')
            seen.add(outputs[index] % n)
            index += 1
    return index


def certificate():
    """Exhaustive divisibility reduction, NOT sampling the count domain.

    For a noncandidate N>=10 each successive 10-output block is distinct
    modulo N, hence twenty rounds consume exactly 200 outputs. Any N that
    can depart from that schedule divides a pair difference in one of those
    blocks, so is a candidate. Candidates (including N<10) are simulated
    through all twenty rounds on the same continuing RNG stream.
    """
    outputs = rng_outputs(4096)
    ps = primes()
    candidates = set(range(1, 10))
    for start in range(0, 200, 10):
        for i in range(start, start+10):
            for j in range(i+1, start+10):
                candidates.update(d for d in divisors(abs(outputs[i]-outputs[j]), ps)
                                  if d <= MAX_ROBUST_COUNT)
    worst = max((selection_draws(n, outputs), n) for n in candidates)
    return {'method': '20 disjoint ten-draw blocks; pair-difference divisors',
            'count_max': MAX_ROBUST_COUNT, 'candidate_count': len(candidates),
            'candidate_sha256': hashlib.sha256(','.join(map(str, sorted(candidates)))
                                               .encode()).hexdigest(),
            'prefix_sha256': hashlib.sha256(','.join(map(str, outputs))
                                            .encode()).hexdigest(),
            'total_draw_bound': max(200, worst[0]), 'worst_count': worst[1],
            'native_prefix': outputs[:16]}


def child(command, text, timeout, memory_mb=0):
    def limits():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_FSIZE, (64 << 20, 64 << 20))
        if memory_mb:
            resource.setrlimit(resource.RLIMIT_AS, (memory_mb << 20, memory_mb << 20))
    env = dict(os.environ)
    env.pop('LD_PRELOAD', None)
    env.pop('LD_LIBRARY_PATH', None)
    env['ASAN_OPTIONS'] = 'detect_leaks=0:abort_on_error=1'
    env['UBSAN_OPTIONS'] = 'halt_on_error=1:print_stacktrace=1'
    start = time.monotonic()
    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=out, stderr=err,
                             start_new_session=True, preexec_fn=limits, env=env)
        timed_out = False
        try:
            p.communicate(text.encode(), timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(p.pid, signal.SIGKILL)
            p.communicate()
        out.seek(0)
        err.seek(0)
        stdout, stderr = out.read().decode(errors='replace'), err.read().decode(errors='replace')
    if timed_out:
        kind = 'timeout'
    elif 'AddressSanitizer' in stderr or 'runtime error:' in stderr:
        kind = 'sanitizer'
    elif p.returncode < 0:
        kind = 'signal'
    else:
        kind = {0: 'return', 10: 'cv_exception', 11: 'std_exception',
                12: 'other_exception', 65: 'malformed'}.get(p.returncode, 'probe_error')
    return {'exit': kind, 'returncode': p.returncode, 'wall_seconds': time.monotonic()-start,
            'stdout': stdout, 'stderr': stderr}


def build(args):
    out = Path(args.output).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    flags = ['-std=c++17', '-O1', '-g', '-Wall', '-Wextra', '-Wpedantic', '-Werror',
             '-D_GLIBCXX_ASSERTIONS']
    if args.sanitize:
        flags += ['-fsanitize=address,undefined', '-fno-omit-frame-pointer', '-no-pie']
    subprocess.run([args.cxx, *flags, '-I'+args.include,
                    str(ROOT / 'tests/native/research/fit_line_3d_probe.cpp'),
                    '-L'+args.lib, '-Wl,-rpath,'+str(Path(args.lib).resolve()),
                    '-lopencv_'+args.backend, '-lopencv_core', '-ldl', '-o', str(out)], check=True)
    manifest = {'probe_sha256': digest(out), 'source_sha256': digest(
        ROOT / 'tests/native/research/fit_line_3d_probe.cpp'), 'include': args.include,
        'lib': args.lib, 'backend': args.backend, 'probe_sanitized': args.sanitize,
        'note': 'Library instrumentation must be established independently.'}
    Path(str(out)+'.json').write_text(json.dumps(manifest, indent=2)+'\n')


def run(args):
    probe = str(Path(args.probe).resolve())
    cases = read_corpus(args.corpus)
    header = {'kind': 'campaign', 'protocol': 'FL3D1', 'probe_sha256': digest(probe),
              'corpus_sha256': digest(args.corpus), 'version': args.version,
              'object_prefix': str(Path(args.object_prefix).resolve())}
    report = Path(args.report)
    done = set()
    if report.exists():
        records = [json.loads(s) for s in report.read_text().splitlines()]
        if not records or records[0] != header:
            raise ValueError('resume identity/corpus mismatch')
        done = {r['case']['id'] for r in records[1:]}
        if len(done) != len(records)-1 or not done <= {c['id'] for c in cases}:
            raise ValueError('resume duplicate/unknown case record')
        if any(r['result']['exit'] == 'protocol_error' for r in records[1:]):
            raise ValueError('previous protocol error; inspect report before retry')
    with report.open('a') as f:
        def save(record):
            f.write(json.dumps(record, allow_nan=False, sort_keys=True)+'\n')
            f.flush()
            os.fsync(f.fileno())
        if not done and report.stat().st_size == 0:
            save(header)
        for c in cases:
            if c['id'] in done:
                continue
            result = child([probe], serialize(c), args.timeout, args.memory_mb)
            records = []
            try:
                records = [json.loads(s) for s in result['stdout'].splitlines()]
                if not records or records[0]['kind'] != 'input':
                    raise ValueError('missing input identity')
                ident = records[0]
                if (ident['protocol'] != 'FL3D1' or ident['depth'] != c['depth']
                    or ident['count'] != len(c['points']) or ident['model'] != c['model']
                    or ident['scalars'] != c['scalars']
                    or ident['points'] != ([[x.lower() for x in pt] for pt in c['points']]
                                           if c['depth'] == 'f32' else c['points'])):
                    raise ValueError('input echo/serialization drift')
                obj = Path(ident['object']).resolve()
                if (ident['runtime'] != args.version or ident['compile'] != args.version
                    or Path(args.object_prefix).resolve() not in obj.parents):
                    raise ValueError('wrong runtime/compile/object identity')
                result['object_sha256'] = digest(obj)
                if result['exit'] == 'return':
                    r = records[-1]
                    if (r['kind'] != 'result' or r['type'] != 5 or r['rows'] != 6
                        or r['cols'] != 1 or len(r['bits']) != 6):
                        raise ValueError('result format drift')
                    vals = [value(b) for b in r['bits']]
                    if r['finite'] != all(math.isfinite(x) for x in vals):
                        raise ValueError('finite flag/bits mismatch')
                    norm = math.sqrt(sum(x*x for x in vals[:3]))
                    if not all(math.isfinite(x) for x in vals):
                        result['exit'] = 'nonfinite'
                    elif not 0.99 <= norm <= 1.01:
                        result['exit'] = 'invalid_direction'
                    if all(math.isfinite(x) for x in vals) and norm and 'expected' in c:
                        expected = c['expected']
                        dot = abs(sum(x*y for x, y in zip(vals[:3], expected)))
                        dot /= norm * math.sqrt(sum(x*x for x in expected))
                        result['abs_dot'] = min(1., dot)
                        result['angle_degrees'] = math.degrees(math.acos(min(1., dot)))
            except (ValueError, KeyError, IndexError, TypeError) as e:
                # Preserve signals/timeouts even if the child never flushed identity.
                if result['exit'] in ('return', 'cv_exception', 'std_exception', 'other_exception'):
                    result['exit'] = 'protocol_error'
                result['protocol_error'] = str(e)
            save({'kind': 'case', 'case': c, 'result': result, 'records': records})
            if result['exit'] == 'protocol_error':
                raise ValueError('probe protocol/identity drift; outcome saved')
    print(json.dumps(summary(report), sort_keys=True))


def summary(path):
    counts = {}
    bad_angles = []
    for s in Path(path).read_text().splitlines()[1:]:
        r = json.loads(s)
        kind = r['result']['exit']
        counts[kind] = counts.get(kind, 0)+1
        if r['result'].get('angle_degrees', 0) > 45:
            bad_angles.append([r['case']['id'], r['result']['angle_degrees']])
    return {'counts': counts, 'angle_over_45': bad_angles[:20]}


def analyze(args):
    """Read-only report comparison, with optional durable compact evidence."""
    reports = []
    evidence = {'campaigns': {}, 'divergences': [], 'reproducers': []}
    evidence['campaign_order'] = [Path(path).name for path in args.reports]
    frozen = {}
    for path in args.reports:
        rows = [json.loads(s) for s in Path(path).read_text().splitlines()]
        by_id = {r['case']['id']: r for r in rows[1:]}
        reports.append(by_id)
        families = {}
        objects = {}
        examples = {}
        candidate_counts = {}
        for r in rows[1:]:
            result, c = r['result'], r['case']
            family = c.get('family', 'fixture')
            if candidate_pre_eigen(c):
                candidate_counts[result['exit']] = candidate_counts.get(result['exit'], 0)+1
            counts = families.setdefault(family, {})
            counts[result['exit']] = counts.get(result['exit'], 0)+1
            if r['records']:
                ident = r['records'][0]
                objects[ident['object']] = result.get('object_sha256')
            if family == 'fixture':
                examples[c['id']] = {'exit': result['exit'],
                                      'result': r['records'][-1] if r['records'] else None}
            if (result.get('angle_degrees', 0) > 60 and family == 'accuracy'
                and len(c['points']) == 2 and 'offset16' in c['id']):
                frozen[c['id']] = c
            if family in ('scalar', 'parameter_boundary') and 'tiny' in c['id']:
                frozen[c['id']] = c
        evidence['campaigns'][Path(path).name] = {
            'header': rows[0], 'report_sha256': digest(path), 'cases': len(rows)-1,
            'families': families, 'objects': objects, 'fixtures': examples,
            'exploratory_pre_eigen_counts': candidate_counts}
    ids = set.union(*(set(r) for r in reports))
    for name in sorted(ids):
        rows = [r[name] for r in reports if name in r]
        exits = [r['result']['exit'] for r in rows]
        directions = []
        for r in rows:
            if r['result']['exit'] == 'return':
                v = [value(b) for b in r['records'][-1]['bits'][:3]]
                norm = math.sqrt(sum(x*x for x in v))
                directions.append([x/norm for x in v])
        worst_dot = min([abs(sum(a*b for a,b in zip(v,w)))
                         for v in directions for w in directions] or [1.])
        if len(set(exits)) > 1 or worst_dot < .99:
            evidence['divergences'].append({'id': name, 'exits': exits, 'min_abs_dot': worst_dot})
    evidence['reproducer_results'] = {
        name: [{'campaign': str(index), 'exit': report[name]['result']['exit'],
                'abs_dot': report[name]['result'].get('abs_dot'),
                'runtime': report[name]['records'][0]['runtime'],
                'object': report[name]['records'][0]['object'],
                'output': report[name]['records'][-1]}
               for index, report in enumerate(reports) if name in report]
        for name in sorted(frozen)}
    evidence['reproducers'] = sorted(frozen)
    evidence['certificate'] = certificate()
    print(json.dumps({k: {'cases': v['cases'], 'families': v['families'], 'objects':v['objects']}
                      for k,v in evidence['campaigns'].items()}, indent=2))
    print('cross-report divergences:', len(evidence['divergences']))
    if args.output:
        Path(args.output).write_text(json.dumps(evidence, indent=2, sort_keys=True)+'\n')
    if args.freeze:
        Path(args.freeze).write_text(''.join(json.dumps(c, sort_keys=True)+'\n'
                                           for _,c in sorted(frozen.items())))


def generate(args):
    """Deterministic stored corpus; generation never invokes OpenCV."""
    cases = []
    def add(name, pts, depth='f32', expected=None, scalars=None, family='fixture'):
        for model in MODELS:
            c = {'id': name+'-'+depth+'-'+model, 'depth': depth, 'model': model,
                 'scalars': scalars or ['0x0p+0', '0x1.47ae147ae147bp-7', '0x1.47ae147ae147bp-7'],
                 'points': [[bits(x) for x in p] for p in pts] if depth == 'f32' else pts,
                 'family': family}
            if expected:
                c['expected'] = expected
            cases.append(c)
    for name, pts in [('one', [[0,0,0]]), ('identical2', [[2,3,4]]*2),
                      ('distinct2', [[0,0,0],[1,2,3]]), ('identical32', [[2,3,4]]*32),
                      ('zeros', [[0,0,0]]*32), ('duplicates', [[0,0,0]]*30+[[1,2,3]]*2)]:
        add(name, pts)
    for depth in ('f32', 'i32'):
        for n in (2, 16, 128):
            for exp in (0, 10, 16, 20, 24, 28):
                for direction in ([1,0,0], [0,1,0], [0,0,1], [1,2,3]):
                    pts = [[(1 << exp)+i*d for d in direction] for i in range(n)]
                    add(f'line-n{n}-offset{exp}-d{direction}', pts, depth, direction, family='accuracy')
    for component in range(3):
        for special in (float('nan'), float('inf'), -float('inf')):
            pts = [[0.,0.,0.], [1.,2.,3.]]
            pts[0][component] = special
            add(f'nonfinite-{component}-{special}', pts, family='nonfinite')
    for p in ('0x1p-149', '0x1p-128', '0x1p-126', '0x1p-60', '0x1p+127', 'inf', 'nan', '-0x1p+0'):
        add('param-'+p, [[0,0,0],[1,2,3],[3,1,2],[0,0,0]],
            scalars=[p, '0x1p-7', '0x1p-7'], family='scalar')
    for field in (1, 2):
        for p in ('inf', 'nan', '0x1p+1023', '0x1p-1074'):
            scalars = ['0x0p+0', '0x1p-7', '0x1p-7']
            scalars[field] = p
            add(f'scalar-{field}-{p}', [[0,0,0],[1,2,3],[3,1,2]], scalars=scalars, family='scalar')
    for exp in (-120, -40, 0, 30, 60, 63, 64, 100, 126):
        add(f'scale-{exp}', [[math.ldexp(x, exp) for x in p]
                            for p in [[0,0,0],[1,2,3],[3,1,2],[-1,2,-3]]], family='boundary')
    # Relative aggregate-boundary cases, exact powers of two with controlled
    # count. Also probe just either side of reciprocal and Welsch boundaries.
    for n in (16, 1024, 16384):
        for shift in (-1, 0, 1):
            exp = (120 - int(math.log2(n)))//2 + shift
            pts = [[math.ldexp(1., exp), math.ldexp((-1.)**j, exp-1), 0.]
                   for j in range(n)]
            add(f'aggregate-n{n}-shift{shift}', pts, family='aggregate_boundary')
    for p in ('0x1p-126','0x1p-127','0x1p-128','0x1p-60','0x1p+60','0x1p+127'):
        add('tiny-reweight-'+p, [[0,0,0],[1,2,3],[3,1,2],[1e5,-1e5,0]],
            scalars=[p,'0x1p-7','0x1p-7'], family='parameter_boundary')
    for p in ('0x1p-128','0x1p-149'):
        pts = [[0,0,0]]*10+[[1,0,0],[0,1,0],[0,0,1]]
        add('zero-distance-tiny-'+p, pts, scalars=[p,'0x1p-7','0x1p-7'], family='parameter_boundary')
    for spread in (1, 4, 16):
        add(f'collapsed-spread{spread}', [[(1<<28)+i*spread,1<<28,1<<28]
                                        for i in range(16)], 'i32', [1,0,0], family='integer')
    rng = random.Random(args.seed)
    for i in range(args.seeds):
        n = rng.choice([3,10,11,31,100,1024])
        scale = math.ldexp(1., rng.randrange(-20, 45))
        offset = scale*rng.choice([0, 1, 1024, 1048576])
        direction = [rng.uniform(-1,1) for _ in range(3)]
        pts = []
        for j in range(n):
            t = rng.uniform(-1,1)*scale
            noise = scale * (1e-4 if i % 3 else 1)
            p = [offset+t*d+rng.uniform(-noise,noise) for d in direction]
            if j and i % 5 == 0:
                p = pts[-1]
            pts.append(p)
        add(f'fuzz-{args.seed}-{i}', pts, expected=direction if i%3 else None, family='fuzz')
    for c in cases:
        validate(c)
    if args.family:
        cases = [c for c in cases if c['family'] in args.family]
    Path(args.output).write_text(''.join(json.dumps(c, allow_nan=False, sort_keys=True)+'\n' for c in cases))
    print(f'wrote {len(cases)} cases')


class SelfTests(unittest.TestCase):
    def test_bits(self):
        self.assertEqual(bits(1.), '3f800000')
        self.assertEqual(value('80000000'), -0.)
        self.assertTrue(math.isnan(value('7fc00001')))
        for s in ('0', '3f8000000', 'zz000000'):
            with self.assertRaises(ValueError):
                value(s)
        with self.assertRaises(ValueError):
            validate(None)

    def test_corpus(self):
        c = {'id':'test', 'depth':'f32', 'model':'L2', 'scalars':['0x0p+0']*3,
             'points':[['00000000','3f800000','80000000']]}
        self.assertIn('00000000 3f800000 80000000', serialize(c))
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'corpus'
            p.write_text(json.dumps(c)+'\n')
            self.assertEqual(read_corpus(p), [c])
        c['points'][0][0] = 'invalid'
        with self.assertRaises(ValueError):
            serialize(c)
        c['points'][0][0] = '00000000'
        c['scalars'][0] = '0.1'
        with self.assertRaises(ValueError):
            serialize(c)

    def test_timeout(self):
        self.assertEqual(child([sys.executable,'-c','import time; time.sleep(5)'],
                               '', .05)['exit'], 'timeout')

    def test_cli(self):
        self.assertEqual(parser().parse_args(['certificate']).command, 'certificate')
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                parser().parse_args(['run'])

    def test_report_comparison(self):
        # Differing corpora must not erase every comparison via an empty
        # intersection. Compare the union, matching only present cases.
        c = {'id':'shared', 'depth':'f32', 'model':'L2', 'scalars':['0x0p+0']*3,
             'points':[['00000000']*3]}
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for i, direction in enumerate(([1.,0.,0.], [0.,1.,0.])):
                path = Path(d)/str(i)
                row = {'case':c, 'result':{'exit':'return'}, 'records':[
                    {'object':'test'}, {'bits':[bits(x) for x in direction]+[bits(0.)]*3}]}
                path.write_text(json.dumps({'kind':'campaign'})+'\n'+json.dumps(row)+'\n')
                paths.append(str(path))
            out = Path(d)/'analysis'
            with contextlib.redirect_stdout(io.StringIO()):
                analyze(argparse.Namespace(reports=paths, output=str(out), freeze=None))
            self.assertEqual(json.loads(out.read_text())['divergences'][0]['min_abs_dot'], 0.)

    def test_rng(self):
        # The native --rng comparison is also required in each environment.
        self.assertEqual(rng_outputs(3), [130063605, 3133359004, 2578348940])
        ps = primes()
        self.assertEqual(sorted(divisors(60, ps)), [1,2,3,4,5,6,10,12,15,20,30,60])
        self.assertEqual(selection_draws(1, rng_outputs(20)), 20)

    def test_certificate(self):
        c = certificate()
        self.assertEqual(c['total_draw_bound'], 599)
        self.assertEqual(c['candidate_count'], 13135)
        self.assertEqual(c['candidate_sha256'],
                         'ed72b735437e721a211103082ed5e9b93df4bfefffabddda6cbc37b5e78a43f0')

    def test_count_arithmetic(self):
        self.assertEqual(MAX_ROBUST_COUNT*2, 2147483646)
        self.assertGreater((MAX_ROBUST_COUNT+1)*2, 2147483647)
        # An independent buffer byte-size/addressability constraint is
        # necessary even when signed count*2 itself fits.
        self.assertGreater(MAX_ROBUST_COUNT*2*4, (1 << 32)-1)


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build')
    for flag in ('include', 'lib', 'output'):
        b.add_argument('--'+flag, required=True)
    b.add_argument('--backend', choices=['imgproc','geometry'], required=True)
    b.add_argument('--cxx', default='g++')
    b.add_argument('--sanitize', action='store_true')
    r = sub.add_parser('run')
    for flag in ('probe','corpus','report','version','object-prefix'):
        r.add_argument('--'+flag, required=True)
    r.add_argument('--timeout', type=float, default=3.)
    r.add_argument('--memory-mb', type=int, default=0)
    g = sub.add_parser('generate')
    g.add_argument('--output', required=True)
    g.add_argument('--seed', type=int, default=2020)
    g.add_argument('--seeds', type=int, default=100)
    g.add_argument('--family', action='append')
    sub.add_parser('certificate')
    a = sub.add_parser('analyze')
    a.add_argument('reports', nargs='+')
    a.add_argument('--output')
    a.add_argument('--freeze')
    s = sub.add_parser('self-test')
    s.add_argument('--probe')
    return p


def main():
    args = parser().parse_args()
    if args.command == 'build':
        build(args)
    elif args.command == 'run':
        if not math.isfinite(args.timeout) or args.timeout <= 0 or args.memory_mb < 0:
            raise ValueError('positive timeout/nonnegative memory limit required')
        run(args)
    elif args.command == 'generate':
        generate(args)
    elif args.command == 'certificate':
        print(json.dumps(certificate(), indent=2, sort_keys=True))
    elif args.command == 'analyze':
        analyze(args)
    else:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(SelfTests))
        if not result.wasSuccessful():
            return 1
        if args.probe:
            native = child([str(Path(args.probe).resolve()), '--rng'], '', 3.)
            if native['exit'] != 'return' or json.loads(native['stdout']) != rng_outputs(16):
                raise ValueError('native RNG model mismatch')
            if child([str(Path(args.probe).resolve())], 'bad input', 3.)['exit'] != 'malformed':
                raise ValueError('native malformed-input rejection drift')
            c = {'id':'native-replay', 'depth':'f32', 'model':'L2',
                 'scalars':['0x0p+0']*3, 'points':[['00000000']*3, ['3f800000']*3]}
            first = child([str(Path(args.probe).resolve())], serialize(c), 3.)
            second = child([str(Path(args.probe).resolve())], serialize(c), 3.)
            a = [json.loads(s) for s in first['stdout'].splitlines()]
            b = [json.loads(s) for s in second['stdout'].splitlines()]
            if (first['exit'] != 'return' or second['exit'] != 'return'
                or a[0]['points'] != c['points'] or a[-1]['bits'] != b[-1]['bits']):
                raise ValueError('native corpus replay/serialization mismatch')
            with tempfile.TemporaryDirectory() as d:
                corpus, report = Path(d)/'corpus', Path(d)/'report'
                corpus.write_text(json.dumps(c)+'\n')
                opts = argparse.Namespace(probe=args.probe, corpus=str(corpus),
                    report=str(report), version=a[0]['runtime'],
                    object_prefix=str(Path(a[0]['object']).resolve().parent),
                    timeout=3., memory_mb=0)
                with contextlib.redirect_stdout(io.StringIO()):
                    run(opts)
                    before = report.read_bytes()
                    run(opts)
                if report.read_bytes() != before:
                    raise ValueError('resume replay duplicated/lost records')
        print('self-test passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as e:
        print(f'error: {e}', file=sys.stderr)
        sys.exit(1)