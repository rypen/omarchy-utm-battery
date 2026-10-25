#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
script="$root/mount-share"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "fail: $*" >&2
  exit 1
}

setup_device() {
  local name="$1" driver="$2" tag="$3"
  local dev="$tmp/sysfs/$name"
  mkdir -p "$dev" "$tmp/drivers"
  ln -s "$tmp/drivers/$driver" "$dev/driver"
  printf '%s\0' "$tag" > "$dev/mount_tag"
}

assert_eq() {
  local got="$1" want="$2" label="$3"
  [[ "$got" == "$want" ]] || fail "$label: got [$got] want [$want]"
}

run() {
  HOME="$tmp/home" MOUNT_SHARE_SYSFS="$tmp/sysfs" MOUNT_SHARE_MOUNTS="$tmp/mounts" "$@"
}

setup_device virtio4 9pnet_virtio share
mounted="$tmp/mounted"
mkdir -p "$mounted" "$tmp/home"
printf '{}\n' > "$mounted/omarchy-utm-battery.json"
printf 'TARGET="%s" FSTYPE="9p" SOURCE="share"\n' "$mounted" > "$tmp/mounts"

got=$(run "$script" status)
assert_eq "$got" "mounted $mounted" "reports a mounted share"

: > "$tmp/mounts"
got=$(run "$script" status)
assert_eq "$got" "unmounted 9p share" "reports an unmounted share"

log="$tmp/log"
got=$(run env MOUNT_SHARE_DRY=1 MOUNT_SHARE_LOG="$log" "$script" mount "$tmp/home/Mac")
assert_eq "$got" "mounted $tmp/home/Mac" "accepts a chosen directory"
assert_eq "$(cat "$log")" "9p share $tmp/home/Mac" "plans a 9p mount"

mkdir -p "$tmp/home/Mac"
printf 'keep\n' > "$tmp/home/Mac/notes"
if run "$script" mount "$tmp/home/Mac" >"$tmp/out" 2>"$tmp/err"; then
  fail "mounted a directory that already has files"
fi
[[ "$(cat "$tmp/err")" == *"not empty"* ]] || fail "missing not-empty error"

if run "$script" mount "/tmp/../etc" >"$tmp/out" 2>"$tmp/err"; then
  fail "accepted a directory with .."
fi

printf 'nope/tag\0' > "$tmp/sysfs/virtio4/mount_tag"
got=$(run "$script" status)
assert_eq "$got" "none" "rejects a tag with a slash"

echo "ok"
