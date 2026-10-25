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

Share that folder with the UTM guest and mount it at `~/Mac`. The command writes `omarchy-utm-battery.json` there. `start` keeps the file current. `stop` removes it.

## Install the bar widget

```sh
omarchy plugin add https://github.com/rypen/omarchy-utm-battery.git --enable
```

With no path set, the widget looks for the snapshot at `~/Mac/omarchy-utm-battery.json`, then `~/Shared`, `/mnt/utm`, and `/mnt/share`. The icon shows the percentage. Right-click hides it.
