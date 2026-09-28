#!/usr/bin/env bash
# Self-contained tests for the tag-derived semver resolvers.
#
# Runs with no network access: each case builds a disposable git repo under
# mktemp -d, tags it, invokes a resolver, and asserts on its tag/prev output.
#
# usage: bash scripts/release-version.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STABLE_RESOLVER="${SCRIPT_DIR}/resolve-release-version.sh"
RC_RESOLVER="${SCRIPT_DIR}/resolve-rc-version.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

pass=0
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass=$((pass + 1))
    printf 'ok   - %s\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL - %s\n      expected: [%s]\n      actual:   [%s]\n' \
      "$label" "$expected" "$actual"
  fi
}

# new_repo <name>: create an isolated git repo with one commit and a bot identity.
new_repo() {
  local name="$1"
  local dir="${tmp_root}/${name}"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "bot@example.com"
  git -C "$dir" config user.name "Release Bot"
  git -C "$dir" config commit.gpgsign false
  git -C "$dir" config tag.gpgsign false
  echo "$name" > "${dir}/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m "init"
  printf '%s' "$dir"
}

# run_resolver <resolver> <dir> <prefix> <changed>: echo the resolver's raw output.
run_resolver() {
  local resolver="$1" dir="$2" prefix="$3" changed="$4"
  ( cd "$dir" && bash "$resolver" "$prefix" "$changed" )
}

# field <key> <output>: extract "key=value" for <key> from resolver output.
field() {
  local key="$1" output="$2"
  printf '%s\n' "$output" | sed -n "s/^${key}=//p"
}

# --- stable resolver ---------------------------------------------------------

out="$(run_resolver "$STABLE_RESOLVER" "$(new_repo stable-unchanged)" server false)"
assert_eq "stable: unchanged artifact emits no tag" "" "$(field tag "$out")"
assert_eq "stable: unchanged artifact emits no prev" "" "$(field prev "$out")"

dir="$(new_repo stable-first)"
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: first ever release is v0.1.0" "server-v0.1.0" "$(field tag "$out")"
assert_eq "stable: first ever release has empty prev" "" "$(field prev "$out")"

dir="$(new_repo stable-bump)"
git -C "$dir" tag server-v1.4.2
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: patch bump from stable tag" "server-v1.4.3" "$(field tag "$out")"
assert_eq "stable: prev is the latest stable tag" "server-v1.4.2" "$(field prev "$out")"

dir="$(new_repo stable-promote)"
git -C "$dir" tag server-v0.2.0
git -C "$dir" tag server-v0.2.1-rc.1
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: unreleased RC promotes to stable" "server-v0.2.1" "$(field tag "$out")"
assert_eq "stable: promotion prev points at prior stable" "server-v0.2.0" "$(field prev "$out")"

dir="$(new_repo stable-consumed-rc)"
git -C "$dir" tag server-v0.1.0
git -C "$dir" tag server-v0.1.0-rc.1
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: consumed RC does not block next patch" "server-v0.1.1" "$(field tag "$out")"
assert_eq "stable: consumed RC keeps stable prev" "server-v0.1.0" "$(field prev "$out")"

dir="$(new_repo stable-existing)"
git -C "$dir" tag server-v0.1.0
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: existing tag emits empty tag (skip)" "" "$(field tag "$out")"

dir="$(new_repo stable-version-sort)"
git -C "$dir" tag server-v1.9.0
git -C "$dir" tag server-v1.10.0
out="$(run_resolver "$STABLE_RESOLVER" "$dir" server true)"
assert_eq "stable: version-aware sort picks v1.10.0" "server-v1.11.0" "$(field tag "$out")"
assert_eq "stable: version-aware sort reports v1.10.0 as prev" "server-v1.10.0" "$(field prev "$out")"

# --- rc resolver -------------------------------------------------------------

out="$(run_resolver "$RC_RESOLVER" "$(new_repo rc-unchanged)" server false)"
assert_eq "rc: unchanged artifact emits no tag" "" "$(field tag "$out")"
assert_eq "rc: unchanged artifact emits no prev" "" "$(field prev "$out")"

dir="$(new_repo rc-first)"
out="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
assert_eq "rc: first ever prerelease is rc.1" "server-v0.1.0-rc.1" "$(field tag "$out")"

dir="$(new_repo rc-bump)"
git -C "$dir" tag server-v1.4.2
out="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
assert_eq "rc: patch bump base from stable tag" "server-v1.4.3-rc.1" "$(field tag "$out")"
assert_eq "rc: prev is the latest stable tag" "server-v1.4.2" "$(field prev "$out")"

dir="$(new_repo rc-advance)"
git -C "$dir" tag server-v0.1.0
git -C "$dir" tag server-v0.1.1-rc.1
git -C "$dir" tag server-v0.1.1-rc.2
out="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
assert_eq "rc: numbering advances past highest RC" "server-v0.1.1-rc.3" "$(field tag "$out")"

dir="$(new_repo rc-existing)"
out="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
out2="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
assert_eq "rc: repeat run emits same tag on a clean line" "server-v0.1.0-rc.1" "$(field tag "$out2")"
git -C "$dir" tag "$(field tag "$out")"
out3="$(run_resolver "$RC_RESOLVER" "$dir" server true)"
assert_eq "rc: existing tag emits empty tag (skip)" "" "$(field tag "$out3")"

# --- prefix isolation --------------------------------------------------------

dir="$(new_repo prefix-isolation)"
git -C "$dir" tag server-v1.0.0
out="$(run_resolver "$STABLE_RESOLVER" "$dir" web true)"
assert_eq "isolation: server tag does not move the web line" "web-v0.1.0" "$(field tag "$out")"
assert_eq "isolation: web has no prev from the server line" "" "$(field prev "$out")"

dir="$(new_repo prefix-isolation-rc)"
git -C "$dir" tag server-v1.0.0
out="$(run_resolver "$RC_RESOLVER" "$dir" web true)"
assert_eq "isolation: rc resolver ignores the server line" "web-v0.1.0-rc.1" "$(field tag "$out")"

# --- summary -----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
