#!/bin/sh
# Rebuild the shop model, price it to income x gap (a few passes), then simulate every bot.
# Run from the project root. Writes the prices into resources/upgrades/*.tres.
set -e
S=~/.claude/skills/incremental-progression/scripts
PASSES=${PASSES:-8}
i=0
while [ $i -lt $PASSES ]; do
  python docs/progression/build_shop.py > /dev/null
  node $S/run_sim.js docs/progression/shop.json --bot focused --out docs/progression/shop-report --quiet > /dev/null 2>&1 || true
  python docs/progression/price_shop.py ${BLEND:-0.6} | head -1
  i=$((i + 1))
done
python docs/progression/build_shop.py > /dev/null
node $S/run_sim.js docs/progression/shop.json --out docs/progression/shop-report --quiet > /dev/null 2>&1 || true
sed -n '/## Checks/,/## Bot: focused/p' docs/progression/shop-report/report.md
