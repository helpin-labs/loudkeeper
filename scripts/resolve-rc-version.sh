#!/usr/bin/env bash
# Print the next reachable RC tag for this single-image repository.
# usage: resolve-rc-version.sh
set -euo pipefail

head_sha=$(git rev-parse HEAD)
latest_stable=$(git tag --merged HEAD -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | grep -E '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' | head -n1 || true)
if [[ -n "$latest_stable" ]]; then
  IFS=. read -r major minor patch <<< "${latest_stable#v}"
  base="v${major}.${minor}.$((patch + 1))"
else
  base=v0.1.0
fi

latest_rc=$(git tag --merged HEAD -l "${base}-rc.*" --sort=-v:refname | grep -E "^${base//./\.}-rc\.(0|[1-9][0-9]*)$" | head -n1 || true)
if [[ -n "$latest_rc" && "$(git rev-list -n1 "refs/tags/$latest_rc")" == "$head_sha" ]]; then
  printf 'tag=\nprev=%s\n' "$latest_stable"
  exit 0
fi
if [[ -n "$latest_stable" && "$(git rev-list -n1 "refs/tags/$latest_stable")" == "$head_sha" ]]; then
  printf 'tag=\nprev=%s\n' "$latest_stable"
  exit 0
fi

next=1
if [[ -n "$latest_rc" ]]; then
  next=$(( ${latest_rc##*.} + 1 ))
fi
printf 'tag=%s-rc.%s\nprev=%s\n' "$base" "$next" "$latest_stable"
