# omarchy-utm-battery

Shows a MacBook's battery on the bar of an Omarchy guest running in UTM.

This repository is the bar widget. The Mac command is attached to releases as an arm64 binary. Its source is not here.

## Install the Mac command

```sh
brew tap rypen/cli-tools
brew install omarchy-utm-battery
```

The tap formula downloads `omarchy-utm-battery-darwin-arm64.tar.gz` from this repository's releases and installs the binary inside it. The `v0.1.0` archive is not attached yet, so that install fails until the release and its checksum are published.

```sh
omarchy-utm-battery start ~/MacShare
omarchy-utm-battery stop ~/MacShare
```

The command writes `omarchy-utm-battery.json` in that folder. `start` keeps the file current. `stop` removes it. Share the folder from the virtual machine's settings.

## Mount the share

Mount that folder at `~/Mac`. UTM tags a directory share `share`.

Apple Virtualization:

```sh
mkdir -p ~/Mac
sudo mount -t virtiofs share ~/Mac
```

QEMU:

```sh
mkdir -p ~/Mac
sudo mount -t 9p -o trans=virtio,version=9p2000.L share ~/Mac
```

## Install the bar widget

```sh
omarchy plugin add https://github.com/rypen/omarchy-utm-battery.git --enable
```

The widget reads `~/Mac/omarchy-utm-battery.json`. If that file is missing, it also checks `~/Shared`, `/mnt/utm`, and `/mnt/share`. The icon shows the percentage. Right-click hides it.
