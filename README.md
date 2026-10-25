# omarchy-utm-battery

Shows a MacBook's battery on the bar of an Omarchy guest running in UTM.

This repository is the install page. Release archives live here. The program does not.

## Install

```sh
brew tap rypen/cli-tools
brew install omarchy-utm-battery
```

The tap formula downloads `omarchy-utm-battery-darwin-arm64.tar.gz` from this repository's releases and installs the single arm64 macOS binary inside it. The `v0.1.0` archive is not attached yet, so that install fails until the release and its checksum are published.

## Use

```sh
omarchy-utm-battery start ~/MacShare
omarchy-utm-battery stop ~/MacShare
```

Share that folder with the UTM guest and mount it at `~/Mac`. The command writes `omarchy-utm-battery.json` there. `start` keeps the file current. `stop` removes it.

On the guest:

```sh
omarchy plugin add https://origin.cursor.com/ryan-willis/omarchy-utm-battery.git --enable
```

The icon shows the percentage. Right-click hides it.
