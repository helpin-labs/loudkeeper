#!/usr/bin/env bash
# Resolve the next stable release version for one artifact's tag line.
#
# Git tags are the single source of truth: nothing in the working tree stores
# the current version. The next stable version is derived from the existing
# tags at CI time.
#
# usage: resolve-release-version.sh <prefix> <changed>
#
#   <prefix>   artifact tag prefix, e.g. "server" -> server-v1.4.2
#   <changed>  "true" when the workflow's path filter saw this artifact change
#
# Output (stable contract, consumed by parsing stdout in CI):
#   tag=<tag>    next stable tag, or empty when there is nothing to release
#   prev=<tag>   latest *stable* tag before the release, or empty
#
# An empty `tag=` is a "skip", not an error: it means the artifact did not
# change or the computed release already exists. Callers must treat it that way
# so re-running a release workflow is always safe (idempotent).
set -euo pipefail

prefix="${1:?usage: resolve-release-version.sh <prefix> <changed>}"
changed="${2:?usage: resolve-release-version.sh <prefix> <changed>}"

if [ "$changed" != "true" ]; then
  echo "tag="
  echo "prev="
  exit 0
fi

# Latest stable tag on this artifact's line (prereleases excluded). Version-aware
# sort, never lexical: v1.10.0 must beat v1.9.0.
prev_stable="$(git tag -l "${prefix}-v*" --sort=-v:refname | grep -vE '\-(rc|dev)\.' | head -n1 || true)"
release_tag=""

# Stable publication promotes an unreleased RC: the highest RC tag whose
# matching stable tag does not exist yet becomes the stable tag.
while IFS= read -r rc_tag; do
  [ -z "$rc_tag" ] && continue
  candidate="$(echo "$rc_tag" | sed 's/-rc\.[0-9]*$//')"
  if ! git rev-parse "$candidate" >/dev/null 2>&1; then
    release_tag="$candidate"
    break
  fi
done < <(git tag -l "${prefix}-v*-rc.*" --sort=-v:refname)

# No unreleased RC to promote: bump patch from the latest stable, or start the
# line at v0.1.0 when this artifact has never been released.
if [ -z "$release_tag" ]; then
  if [ -n "$prev_stable" ]; then
    version="${prev_stable#${prefix}-v}"
    IFS='.' read -r major minor patch <<< "$version"
    major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
    patch=$((patch + 1))
    release_tag="${prefix}-v${major}.${minor}.${patch}"
  else
    release_tag="${prefix}-v0.1.0"
  fi
fi

# Idempotency guard: a release that already exists is a no-op, not a failure.
if git rev-parse "$release_tag" >/dev/null 2>&1; then
  echo "tag="
  echo "prev=$prev_stable"
  exit 0
fi

echo "tag=$release_tag"
echo "prev=$prev_stable"
