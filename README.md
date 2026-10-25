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

## Install the bar widget

```sh
omarchy plugin add https://github.com/rypen/omarchy-utm-battery.git --enable
```

The widget uses a UTM directory share that is already mounted. Otherwise it mounts one, usually at `~/Mac`, and may ask for an admin password once. If `~/Mac` already has other files, it uses `~/.local/state/omarchy-utm-battery/share` instead. The icon shows the percentage. Right-click hides it.
