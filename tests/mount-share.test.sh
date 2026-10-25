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

setup_device virtio4 9pnet_virtio share
mounted="$tmp/mounted"
mkdir -p "$mounted"
printf '{}\n' > "$mounted/omarchy-utm-battery.json"
printf 'TARGET="%s" FSTYPE="9p" SOURCE="share"\n' "$mounted" > "$tmp/mounts"

got=$(HOME="$tmp/home" MOUNT_SHARE_SYSFS="$tmp/sysfs" MOUNT_SHARE_MOUNTS="$tmp/mounts" "$script")
assert_eq "$got" "$mounted" "uses the share that is already mounted"

rm -f "$tmp/mounts"
mkdir -p "$tmp/home"
log="$tmp/log"
got=$(HOME="$tmp/home" MOUNT_SHARE_SYSFS="$tmp/sysfs" MOUNT_SHARE_MOUNTS="$tmp/mounts" MOUNT_SHARE_DRY=1 MOUNT_SHARE_LOG="$log" "$script")
assert_eq "$got" "$tmp/home/Mac" "mounts an absent share at ~/Mac"
assert_eq "$(cat "$log")" "9p share $tmp/home/Mac" "plans a 9p mount"

mkdir -p "$tmp/home/Mac"
printf 'keep\n' > "$tmp/home/Mac/notes"
: > "$log"
got=$(HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" MOUNT_SHARE_SYSFS="$tmp/sysfs" MOUNT_SHARE_MOUNTS="$tmp/empty-mounts" MOUNT_SHARE_DRY=1 MOUNT_SHARE_LOG="$log" "$script")
assert_eq "$got" "$tmp/state/omarchy-utm-battery/share" "picks another directory when ~/Mac is in use"
assert_eq "$(cat "$log")" "9p share $tmp/state/omarchy-utm-battery/share" "plans the fallback mount"

printf 'nope/tag\0' > "$tmp/sysfs/virtio4/mount_tag"
: > "$log"
if HOME="$tmp/home2" MOUNT_SHARE_SYSFS="$tmp/sysfs" MOUNT_SHARE_MOUNTS="$tmp/empty-mounts" MOUNT_SHARE_DRY=1 MOUNT_SHARE_LOG="$log" "$script" >"$tmp/out" 2>"$tmp/err"; then
  fail "accepted a tag with a slash"
fi
[[ ! -s "$log" ]] || fail "planned a mount for a bad tag"

echo "ok"
