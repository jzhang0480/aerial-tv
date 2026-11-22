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
# Local invariants: the manifest and its authorities/account type must stay in place.
# The HOME category lives in the standard flavor's manifest, not in main.
grep -q 'android.intent.category.HOME' app/src/standard/AndroidManifest.xml || {
  echo "!! app/src/standard/AndroidManifest.xml no longer declares the HOME category"; fail=1; }
grep -q '\${applicationId}' app/src/main/AndroidManifest.xml || {
  echo "!! AndroidManifest.xml no longer uses \${applicationId} for the FileProvider"; fail=1; }
for f in app/src/main/res/xml/revival_account.xml app/src/main/res/xml/revival_sync.xml; do
  grep -q 'android:accountType="com.ts.launcher"' "$f" || {
    echo "!! $f accountType is not com.ts.launcher"; fail=1; }
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

# Check the built APK itself, not only the sources.
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
APK=app/build/outputs/apk/standard/release/app-standard-release.apk
AAPT2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)
APKSIGNER=$(ls "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$AAPT2" ]; then
  # Capture first: grep -q closes the pipe early, and pipefail would call that a failure.
  BADGING=$("$AAPT2" dump badging "$APK" 2>/dev/null || true)
  case "$BADGING" in
    *"package: name='com.ts.launcher'"*) ;;
    *) echo "!! built APK is not com.ts.launcher"; exit 1 ;;
  esac
  TREE=$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" 2>/dev/null || true)
  case "$TREE" in
    *android.intent.category.HOME*) ;;
    *) echo "!! built APK declares no HOME category"; exit 1 ;;
  esac
  echo "APK: package and HOME category OK"
else
  echo "aapt2 not found under $ANDROID_HOME; skipped the APK manifest check"
fi
if [ -n "$APKSIGNER" ]; then
  "$APKSIGNER" verify "$APK" >/dev/null 2>&1 || { echo "!! built APK is not signed"; exit 1; }
  echo "APK: signature OK"
fi

echo
echo "sync done. To keep it: git push origin HEAD"
