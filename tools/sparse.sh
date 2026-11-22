#!/usr/bin/env bash
# Keep only what this fork works on in the local checkout; the rest stays in git.
#
#   tools/sparse.sh          # apply the narrow view (idempotent)
#   tools/sparse.sh off      # restore the full checkout
#   tools/sparse.sh status   # show the patterns and the working tree
#
# The files left out remain in git history and in upstream, so merges, builds
# (lite/ is kept) and pushes are unaffected. New clones run this once.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-apply}" in
  apply)
    git sparse-checkout init --no-cone
    git sparse-checkout set --no-cone \
      '/*' \
      '!/site/' \
      '!/docs/HANDOFF.md' \
      '!/docs/LITE.md' \
      '!/docs/devices/*' \
      '/docs/devices/xiaomi-mitv-astr0.md'
    echo "narrow view applied; left out of the working tree:"
    echo "  site/  docs/HANDOFF.md  docs/LITE.md  docs/devices/* (except xiaomi-mitv-astr0.md)"
    ;;
  off|all)
    git sparse-checkout disable
    echo "full checkout restored"
    ;;
  status)
    git sparse-checkout list
    echo "---"
    git status --short
    ;;
  *)
    echo "usage: $0 [apply|off|status]" >&2
    exit 1
    ;;
esac
