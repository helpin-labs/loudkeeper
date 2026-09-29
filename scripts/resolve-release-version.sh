#!/usr/bin/env bash
# Print the next reachable stable tag for this single-image repository.
# usage: resolve-release-version.sh
set -euo pipefail

head_sha=$(git rev-parse HEAD)
latest_stable=$(git tag --merged HEAD -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | grep -E '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' | head -n1 || true)
if [[ -n "$latest_stable" && "$(git rev-list -n1 "refs/tags/$latest_stable")" == "$head_sha" ]]; then
  printf 'tag=\nprev=%s\n' "$latest_stable"
  exit 0
fi
if [[ -n "$latest_stable" ]]; then
  IFS=. read -r major minor patch <<< "${latest_stable#v}"
  tag="v${major}.${minor}.$((patch + 1))"
else
  tag=v0.1.0
fi
printf 'tag=%s\nprev=%s\n' "$tag" "$latest_stable"
