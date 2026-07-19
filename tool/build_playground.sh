#!/usr/bin/env bash
# Rebuilds the browser playground under docs/playground/ from web/.
#
# The playground compiles the web-safe scorer (lib/skillscore_web.dart) to
# JavaScript, so the site scores SKILL.md files entirely client-side. Run this
# whenever the scorer or the playground UI changes, then commit the result;
# GitHub Pages serves docs/playground/ from the main branch.
set -euo pipefail

cd "$(dirname "$0")/.."

out="docs/playground"
mkdir -p "$out"

echo "Compiling web/main.dart -> $out/main.dart.js"
dart compile js web/main.dart -O2 -o "$out/main.dart.js"

# Keep only the runtime artifacts: drop the source map + deps, and the
# now-dangling sourceMappingURL comment.
rm -f "$out/main.dart.js.map" "$out/main.dart.js.deps"
grep -v '^//# sourceMappingURL=' "$out/main.dart.js" > "$out/main.dart.js.tmp"
mv "$out/main.dart.js.tmp" "$out/main.dart.js"

cp web/index.html "$out/index.html"

echo "Done. Playground built at $out/ ($(du -h "$out/main.dart.js" | cut -f1) JS)."
