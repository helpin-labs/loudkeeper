#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$(cd "$(dirname "$0")" && pwd)
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

assert_tag() {
  local expected=$1 script=$2
  local actual
  actual=$("$scripts_dir/$script" | sed -n 's/^tag=//p')
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected %s, got %s from %s\n' "$expected" "$actual" "$script" >&2
    exit 1
  fi
}
commit() {
  printf '%s\n' "$1" >> file
  git add file
  git commit -qm "$1"
}

cd "$tmp_root"
git init -q
git config user.email test@example.com
git config user.name 'Version Test'
commit first
assert_tag v0.1.0-rc.1 resolve-rc-version.sh
assert_tag v0.1.0 resolve-release-version.sh
git tag v0.1.0-rc.1
assert_tag '' resolve-rc-version.sh
commit second
assert_tag v0.1.0-rc.2 resolve-rc-version.sh
git tag v0.1.0-rc.2
assert_tag v0.1.0 resolve-release-version.sh
git tag v0.1.0
assert_tag '' resolve-release-version.sh
assert_tag '' resolve-rc-version.sh
commit third
assert_tag v0.1.1-rc.1 resolve-rc-version.sh
assert_tag v0.1.1 resolve-release-version.sh
git tag v0.1.1-rc.1
commit fourth
assert_tag v0.1.1-rc.2 resolve-rc-version.sh
# Unreachable tags must not advance the current branch.
git branch other
git checkout -q -b isolated HEAD~1
commit isolated
git tag v99.0.0
git checkout -q other
assert_tag v0.1.1-rc.2 resolve-rc-version.sh
printf 'version resolver tests passed\n'
