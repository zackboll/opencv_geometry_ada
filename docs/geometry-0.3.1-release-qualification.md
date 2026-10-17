# opencv_geometry 0.3.1 candidate qualification — GEOMETRY-REL-004

Disposition: **QUALIFICATION_PENDING**. This is release preparation only.
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
| Debian 12 GNAT 12 / Core 0.5.0 | 542/542 in release, validation, development; native sanitizers/fault injection | PENDING |
| Debian 12 GNAT 12 / Core 0.5.1 | Same, fresh separate workspace | PENDING |
| Installed consumers / both Core versions | Ada and mixed Ada/C++, installed and relocated, independent environment | PENDING |
| GNAT Pro 25.2 / Scarthgap / Core 0.5.1 | Fresh builds, install, ABI/provenance/ALI checks; consumers and 542/542 under QEMU | PENDING |
| Debian AArch64 reference | Fresh cross builds, installed/relocated consumers, 542/542 under QEMU | PENDING |
| OpenCV compatibility | Existing 4.x and 5.0 matrix, both Core versions | PENDING |
| GNATdoc | 452/452, zero warnings, links/navigation/search, five guides/examples, deterministic generation | PENDING |
| Alire | Fresh root, test actions, indexed Core 0.5.0 and temporary source-pinned consumers | PENDING |
| Source archive | Exact committed source, inventory, archive and manifest hashes, no generated/private material | PENDING |
| Hosted PR CI | All applicable workflows pass on final PR HEAD | PENDING |
| Identity agreement | Tested local = remote branch = open non-draft PR HEAD | PENDING |

Private evidence root:
`/home/zboll/work/opencv-geometry-scarthgap/evidence/geometry-rel-004/`.
Existing compiler, SDK, OpenCV, containers and earlier evidence are retained.
No proprietary binary, raw private log or credential belongs in the source
archive or PR. **Target hardware remains NOT TESTED.** AdaCore GNAT 12
remains NOT TESTED; Debian GNAT 12 and GNAT Pro 25.2 are separate tracks.

No public semantic validation is duplicated in the C++ shim by this release.