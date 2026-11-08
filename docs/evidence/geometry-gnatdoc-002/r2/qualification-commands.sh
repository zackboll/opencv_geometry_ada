#!/bin/sh
# Reproduction only; not a policy selector or an authorization input.
set -eu
policy=$1
head=$2
workspace=$3
python=/home/zboll/git/geometry-gnatdoc-002-evidence/historical-tools/bin/python
cd "$policy"
test "$(git rev-parse HEAD)" = "$head"
test -z "$(git status --porcelain)"
"$python" -m unittest discover -s scripts -p test_gnatdoc_migration_policy.py -v
"$python" -m unittest discover -s scripts -p test_select_gnatdoc_policy.py -v
"$python" scripts/run_additive_gnatdoc_review.py \
  --workspace "$workspace" \
  --candidate-repository /home/zboll/git/opencv_geometry_ada \
  --candidate-revision "$head" \
  --enhancer /home/zboll/git/geometry-gnatdoc-002-evidence/historical-enhancer \
  --core /home/zboll/git/geometry-gnatdoc-001-evidence/core-0.5.0 \
  --gnatdoc-prefix /home/zboll/git/opencv_geometry_ada/.doc-tools/gnatdoc-26.0.0 \
  --playwright-module /home/zboll/git/geometry-gnatdoc-001-evidence/browser/node_modules/playwright \
  --chromium /home/zboll/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome \
  --policy-review
test -z "$(git status --porcelain)"