# omarchy-utm-battery

Shows a MacBook's battery on the bar of an Omarchy guest running in UTM.

This repository is the bar widget. The Mac command is attached to releases as arm64 and Intel binaries. Its source is not here.

## Install the Mac command

```sh
brew tap rypen/cli-tools
brew install omarchy-utm-battery
```

The `v0.1.0` release is not published yet, so that install fails until it is.

```sh
omarchy-utm-battery set share ~/MacShare
brew services start omarchy-utm-battery
```

That starts the publisher at login and writes `omarchy-utm-battery.json` in the saved folder. `brew services stop omarchy-utm-battery` stops it. Share the folder from the virtual machine's settings.

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
