#!/usr/bin/env bash
# Resolve the next prerelease (release candidate) version for one artifact.
#
# Git tags are the single source of truth, exactly as in the stable resolver.
# The `develop` lane calls this to publish `-rc.N` prereleases.
#
# usage: resolve-rc-version.sh <prefix> <changed>
#
#   <prefix>   artifact tag prefix, e.g. "server" -> server-v1.4.3-rc.2
#   <changed>  "true" when the workflow's path filter saw this artifact change
#
# Output (same contract as resolve-release-version.sh):
#   tag=<tag>    next prerelease tag, or empty when there is nothing to release
#   prev=<tag>   latest *stable* tag before the release, or empty
#
# An empty `tag=` is a "skip", not an error, so re-running is always safe.
set -euo pipefail

prefix="${1:?usage: resolve-rc-version.sh <prefix> <changed>}"
changed="${2:?usage: resolve-rc-version.sh <prefix> <changed>}"

if [ "$changed" != "true" ]; then
  echo "tag="
  echo "prev="
  exit 0
fi

# Latest stable tag on this artifact's line; prereleases are excluded so the RC
# base advances only when a stable release lands. Version-aware sort, never
# lexical.
prev_stable="$(git tag -l "${prefix}-v*" --sort=-v:refname | grep -vE '\-(rc|dev)\.' | head -n1 || true)"

# Next RC base: one patch above the latest stable, or the first release on the
# line when nothing stable exists yet.
if [ -n "$prev_stable" ]; then
  version="${prev_stable#${prefix}-v}"
  IFS='.' read -r major minor patch <<< "$version"
  major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
  base="${prefix}-v${major}.${minor}.$((patch + 1))"
else
  base="${prefix}-v0.1.0"
fi

# RC numbering is unbounded and advances past the highest existing RC for this
# base (rc.1, rc.2, ...). Version-aware sort picks the highest rc.N.
highest_rc="$(git tag -l "${base}-rc.*" --sort=-v:refname | head -n1 || true)"
if [ -n "$highest_rc" ]; then
  n="${highest_rc##*-rc.}"
  n=$((n + 1))
else
  n=1
fi

rc_tag="${base}-rc.${n}"

# Idempotency guard: a release that already exists is a no-op, not a failure.
if git rev-parse "$rc_tag" >/dev/null 2>&1; then
  echo "tag="
  echo "prev=$prev_stable"
  exit 0
fi

echo "tag=$rc_tag"
echo "prev=$prev_stable"
