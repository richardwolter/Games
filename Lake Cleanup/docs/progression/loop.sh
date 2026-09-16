#!/bin/sh
# Rebuild, price to income x gap (a few passes), simulate and check the tree. Run from the project root.
set -e
S=~/.claude/skills/incremental-progression/scripts
python docs/progression/build_tree.py
for pass in 1 2 3 4 5 6 7 8; do
  node $S/run_sim.js docs/progression/lake-tree.json --bot focused --out docs/progression/tree-report > /dev/null 2>&1 || true
  python docs/progression/price_by_income.py
done
for pass in 1 2 3; do
  node $S/run_sim.js docs/progression/lake-tree.json --bot focused --out docs/progression/tree-report > /dev/null 2>&1 || true
  python docs/progression/price_by_income.py spend
done
node $S/run_sim.js docs/progression/lake-tree.json --out docs/progression/tree-report > /dev/null 2>&1 || true
sed -n '/## Checks/,/## Bot: focused/p' docs/progression/tree-report/report.md
python docs/progression/check_tree.py
