#!/usr/bin/env bash
# One-step upstream sync: fetch, merge, verify the local package name, build.
#
# Usage:
#   tools/merge-upstream.sh           # merge + build standard + guard
#   LITE=1 tools/merge-upstream.sh    # additionally compile the lite module (full compile check)
#
# On conflict: stops and lists the conflicted files. Files we never customized take
# the upstream version; files we did customize keep com.ts.launcher (see the list
# below). This script never pushes; pushing to origin is the user's action.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

git fetch upstream
echo "upstream/main: $(git rev-parse --short upstream/main)"

if git merge --no-edit upstream/main; then
  echo "merge OK"
else
  echo
  echo "!! merge has conflicts; resolve manually:"
  git diff --name-only --diff-filter=U
  echo
  echo "Rules: files we never customized take the upstream version; files we did"
  echo "customize keep the local com.ts.launcher. Package-name-sensitive files:"
  echo "  app/build.gradle.kts (applicationId)"
  echo "  tools/install.sh  tools/restore.sh  tools/test_install.py  tools/test_restore.py"
  exit 1
fi

# Verify the package name was not reverted by the merge.
fail=0
grep -q 'applicationId = "com.ts.launcher"' app/build.gradle.kts || {
  echo "!! applicationId is not com.ts.launcher; check the merge result"; fail=1; }
for f in tools/install.sh tools/restore.sh tools/test_install.py tools/test_restore.py; do
  grep -q 'com.ts.launcher' "$f" || { echo "!! $f no longer mentions com.ts.launcher"; fail=1; }
done
if [ "$fail" != 0 ]; then
  exit 1
fi

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
echo "building standard + guard ..."
./gradlew assembleStandardRelease assembleGuardRelease
if [ "${LITE:-}" = "1" ]; then
  echo "building lite (full compile check) ..."
  ./gradlew :lite:assembleRelease
fi

echo
echo "sync done. To keep it: git push origin HEAD"
