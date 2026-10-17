# opencv_geometry 0.3.1 candidate qualification — GEOMETRY-REL-004

Disposition: **FINAL_HEAD_QUALIFICATION_PENDING**. This is release preparation only.
No merge, auto-merge, tag, GitHub Release or Alire index submission is
authorized. Final readiness requires independent source review.

## Refreshed starting state (2026-10-17)

| Source | Exact identity |
| --- | --- |
| Geometry verified `main`, PR #46 merge | `00752b8a90f1dcc4d025fb136f0b6d8a8b1560ff` |
| Geometry 0.3.0 source | `fa81e5140cbebf2aa41397a40c08ba194a5f6f73` |
| Geometry 0.3.0 annotated tag object | `e95e7b7c5d240ae99a1def526f88a91bc9e574c9` |
| Core 0.5.0 source | `f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f` |
| Core 0.5.1 source | `64d8a60b59acfe4334045280e430c4774b5cad89` |
| Core 0.5.1 annotated tag object | `4190bb68c0b089475db4fb385349bc6d2a62cb31` |

Origin and immutable tags were fetched before editing. The original source
checkout was clean and left untouched. All six post-merge workflows passed
on verified `main`; no source PR was open and no 0.3.1 tag existed.
Core index PR #2243 was OPEN, with 23/23 individual checks successful.
The official index contained Core 0.5.0 but returned HTTP 404 for 0.5.1:
**Core 0.5.1 public index resolution: INDEX_PENDING**.

## Production equivalence and change review

`git ls-tree 0.3.0 src cpp` and `git ls-tree origin/main src cpp` returned
the same actual Git tree objects:

- `src/`: `1c253e7947a1afe4133dc54804a3029793682a41`
- `cpp/`: `3dbd7c17dc58701d33905dcd36af2b493d8e3880`

`git diff --exit-code 0.3.0 origin/main -- src cpp` succeeded. The complete
diff since 0.3.0 is confined to cross tooling/qualification tests and
documentation/link validation. It includes runtime discovery, actual ALI
probes, the distinct 25.2 track, installed GPR configuration and target
ABI/provenance controls. No production public API or private ABI difference
was found. This release changes metadata, current-status documentation and
tooling qualification coverage only. Historical 0.3.0 evidence is unchanged.

## Candidate qualification gates

Every result must name the tested committed Geometry SHA and exact Core
source. A prior campaign or a passing parent commit is not candidate proof.

| Gate | Required result | Candidate disposition |
| --- | --- | --- |
| Debian 12 GNAT 12 / Core 0.5.0 | 542/542 in release, validation, development; native sanitizers/fault injection | PASS at preflight SHA below |
| Debian 12 GNAT 12 / Core 0.5.1 | Same, fresh separate workspace | PASS at preflight SHA below |
| Installed consumers / both Core versions | Ada and mixed Ada/C++, installed and relocated, independent environment | PASS at preflight SHA below |
| GNAT Pro 25.2 / Scarthgap / Core 0.5.1 | Fresh builds, install, ABI/provenance/ALI checks; consumers and 542/542 under QEMU | PASS at preflight SHA below |
| Debian AArch64 reference | Fresh cross builds, installed/relocated consumers, 542/542 under QEMU | PASS at preflight SHA below |
| OpenCV compatibility | Existing 4.x and 5.0 matrix, both Core versions | PASS at preflight SHA below |
| GNATdoc | 452/452, zero warnings, links/navigation/search, five guides/examples, deterministic generation | PASS at preflight SHA below |
| Alire | Fresh root, test actions, indexed Core 0.5.0 and temporary source-pinned consumers | PASS at preflight SHA below |
| Source archive | Exact committed source, inventory, archive and manifest hashes, no generated/private material | PASS at preflight SHA below; final archive required |
| Hosted PR CI | All applicable workflows pass on final PR HEAD | PENDING |
| Identity agreement | Tested local = remote branch = open non-draft PR HEAD | PENDING |

Private evidence root:
`/home/zboll/work/opencv-geometry-scarthgap/evidence/geometry-rel-004/`.
Existing compiler, SDK, OpenCV, containers and earlier evidence are retained.
No proprietary binary, raw private log or credential belongs in the source
archive or PR. **Target hardware remains NOT TESTED.** AdaCore GNAT 12
remains NOT TESTED; Debian GNAT 12 and GNAT Pro 25.2 are separate tracks.

No public semantic validation is duplicated in the C++ shim by this release.

## Fresh preflight evidence

Preflight source: `df7fd96376af0771660bb51ea59b9e2158634786`, version
0.3.1, clean dedicated clone. The later documentation-only reconciliation
does not retroactively change that identity. The final committed PR head
must be freshly qualified and recorded in the PR and external evidence;
this document cannot embed its own commit hash. No result below substitutes
for those final-head gates.

### Debian 12 native and installed consumers

Separate clean workspaces for each immutable Core source used GNAT/GCC/G++
12.2.0, matching GNAT Lib v12 runtime, OpenCV 4.6.0 (native imgproc/core),
and AUnit 26.0.0. `tests/gnat12/run_production.sh` passed release, validation
and development: 542 registered/executed/successful in each, zero failed
assertions, zero unexpected errors, no compiler warnings. All four native
ASan/UBSan tests passed, including allocation-failure injection. Object,
archive, ALI and dynamic dependency identities passed.

`tests/installed_consumers/prepare.sh` built and installed fresh Ada and C++
artifacts for both Core cases. `consume.sh` passed each case in an offline
container mounting only the installed payload: independent Ada-only and
mixed Ada/C++ consumers, rebuilt and rerun after prefix relocation, GPR
resolution and independent dynamic dependency checks. No source checkout
or Alire executable was on the consumer search path.

The first consumer attempts intentionally failed closed because the reused
image exposed Alire. Their logs remain. Successful attempts use
`PATH=/usr/bin:/bin` in separate containers, excluding `/usr/local/bin/alr`;
the checker and installed metadata are unchanged. This is command-environment
isolation, not a library correction.

### GNAT Pro 25.2 / Yocto Scarthgap

The existing offline rootless qualification container and prerequisites were
reused, without rebuilding/downloading the SDK, compiler or OpenCV.
`tests/cross/qualify_adacore25_yocto.sh` passed with Core 0.5.1, GNAT Pro
25.2, GCC/G++ 13.3.1, actual probe ALI `V "GNAT Lib v25"`, Scarthgap 5.0,
OpenCV 4.9.0 and QEMU AArch64 6.2.0. It authenticated compiler and official
SDK provenance, built both libraries/shims from fresh exports, installed
them, linked and ran both independent consumer kinds before/after relocation,
and verified ELF AArch64, target loader/dependency closure, symbol versions,
compiler/runtime identities and absence of host/foreign-target libraries.

Full Geometry AUnit result under QEMU: **542 registered, 542 executed,
542 successful, 0 failed assertions, 0 unexpected errors; exit status 0**.
Disposition: `ADACORE_GNAT_PRO_25_2_CROSS_QUALIFIED` and
`YOCTO_SCARTHGAP_CROSS_QUALIFIED`. Hardware remains NOT TESTED.

### Separate Debian AArch64 reference

`tests/cross/qualify_debian_aarch64_reference.sh` passed with immutable
Core 0.5.0, real Debian target GNAT 12/runtime and arm64 packages. Both Ada
libraries and C++ shims were freshly cross-built/installed; independent
Ada/mixed consumers linked and ran installed and relocated. The full suite
passed 542/542 under user-mode QEMU, zero failures/errors, exit 0. Real-data
negative controls rejected AdaCore/Yocto claims about Debian inputs.
This is not GNAT Pro 25.2 or Scarthgap evidence.

### Native OpenCV compatibility

The established Linux matrix runner passed all **14 cells** at the preflight
SHA: OpenCV 4.6.0, 4.10.0, 4.11.0, 4.12.0, 4.13.0, 4.14.0 and 5.0.0,
each against immutable Core 0.5.0 and 0.5.1. Every cell passed 542/542 in
release and validation, four native sanitizer/fault tests, exact loaded
OpenCV library checks, zero sanitizer reports, and release-profile restoration.
OpenCV 4 selected native imgproc; OpenCV 5 selected native geometry, without
loading imgproc. No tolerance, validity check or ownership policy changed.

### Documentation and Alire

GNATdoc 26.0.0, GNAT 16.1.0, GPRbuild Alire release 26.0.1 and immutable
Core 0.5.0: 452/452 documented public items, zero GNATdoc warnings, all
anchors/type links validated; all five guides and the landing-page example
compiled and executed. Two fresh regenerations were byte-identical; the
224 Python documentation tests passed both before and after generation.
Chromium/Playwright checks passed desktop/mobile, theme/JavaScript guide
variants, navigation/search, and real cross-repository Core declaration
links (immutable documentation-only Core fixture `ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae`).
Additional read-only site validation against Core 0.5.1 passed; the Core
0.5.0 generation fixture and empty warning/coverage baselines are unchanged.

Initial documentation harness failures (missing sibling Core fixture and
reuse of a snapshot directory) are retained; corrected layout and a fresh
snapshot passed, without source or validator changes.

Alire 2.1.1 used the existing GNAT 16.1.0/GPRbuild 26.0.1 defaults. A fresh
root resolved indexed Core 0.5.0, built, ran the existing test action and
542/542 AUnit tests. A clean independent consumer resolved indexed Core
0.5.0 without a Core source pin. A second isolated consumer passed with a
temporary path pin to immutable Core 0.5.1. Neither pin enters the production
manifest. Existing actions, dependency constraints and Windows metadata
are unchanged. Core 0.5.1 unpinned public resolution remains INDEX_PENDING.

### Archive preflight

`git archive` of the preflight commit contains Ada/C++ sources and headers,
GPR files, configuration scripts, native/qualification tests, LICENSE,
THIRD_PARTY_NOTICES, Alire metadata and both release documents. Inventory
inspection found no objects/ALIs, build outputs, private logs, SDK/compiler
binaries or credentials. Private evidence is outside the repository.

- Preflight tar.gz SHA-256:
  `ddc0ba3c043d563938f068fd8b7b73d2888b8b3d8fdc973547c440a0a7b8cc7f`.
- Production `alire.toml` SHA-256:
  `5b16b268ed7ada514020e87dc1d520b68dd8d4f7b32c7f87c4a587fa53a8777b`.

The final archive must be regenerated from the final committed PR head and
its hash recorded externally. Optional `alr publish` was not used; no
publisher manifest was submitted. Publication and index submission remain
outside this task.