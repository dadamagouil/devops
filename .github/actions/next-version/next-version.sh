#!/usr/bin/env bash
# Computes the next release version (vX.Y.Z).
#   usage: next-version.sh <patch|minor|major> [forced-version]
# The latest version is the highest existing tag vX.Y or vX.Y.Z (v1.14 counts as v1.14.0).
# Output: a line "new=vX.Y.Z" on stdout. Needs `gh` (GH_TOKEN) and must run inside the repository.
set -eu

bump=${1:-minor}
forced=${2:-}

if [ -n "$forced" ]; then
  if ! printf '%s' "$forced" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "::error::Invalid forced version: \"$forced\" (expected format: v1.15.0)." >&2
    exit 1
  fi
  echo "new=$forced"
  exit 0
fi

last=$(gh release list --limit 200 --json tagName --jq '.[].tagName' \
  | grep -E '^v[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -1 || true)
last=${last:-v0.0.0}
v=${last#v}
major=${v%%.*}; rest=${v#*.}
minor=${rest%%.*}
patch=0
[ "$rest" != "$minor" ] && patch=${rest#*.}

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *) echo "::error::Unknown bump type: $bump" >&2; exit 1 ;;
esac
echo "new=v$major.$minor.$patch"
