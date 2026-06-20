# NotchShelf

A native macOS menu-bar app that turns the MacBook notch into a **drag-and-drop
file shelf** with a **now-playing** strip and **system status** — a lightweight,
open-source take on the "dynamic island for Mac" idea.

Move your cursor to the notch and it expands downward; move away and it collapses.

## Features

- **File shelf** — drag files onto the notch to hold them, then drag them back out
  to Finder or any app. Dropped files are copied into private storage, so they
  survive even if the original is moved or deleted, and persist across relaunches.
- **Now playing** — track, artist, artwork, and transport controls for the active
  media app (best-effort via the system MediaRemote service).
- **System status** — battery level / charging state and a clock.
- **Hover to expand** — spring-animated dynamic-island-style open/close.
- **Background agent** — no Dock icon, lives in the menu bar; optional launch at
  login.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ (built and tested with Xcode 26)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```bash
./build.sh run     # generate project, build, and launch
./build.sh         # build only
```

Or manually:

```bash
xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf \
  -configuration Debug -derivedDataPath ./build build
open ./build/Build/Products/Debug/NotchShelf.app
```

The app has no window of its own — look for the notch panel at the top of the
screen and the `▭` icon in the menu bar. On Macs without a physical notch, the
panel anchors to a synthetic band at the top-center of the main display.

## Project layout

```
Sources/
  App/      @main entry, AppDelegate, launch-at-login
  Notch/    panel window, geometry, shape, root view + view model
  Shelf/    file model + draggable cells (drop in / drag out)
  Media/    now-playing model + view
  Status/   battery/clock model + view
  Resources/Info.plist, asset catalog
```

The Xcode project is generated from `project.yml` and git-ignored — edit the YAML,
not the `.xcodeproj`.

## Notes & limitations

- **Now Playing** uses the private MediaRemote framework loaded at runtime. Apple
  has tightened access to it on recent macOS versions; if no data is returned the
  strip shows an idle state. Nothing private is linked at build time.
- The app is **not sandboxed** — this is what lets files drag back out to Finder
  reliably (the same approach NotchDrop uses). Sandboxing would require an
  `NSFilePromiseProvider` drag source instead.

## Prior art & references

Studied while building this: [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)
(MIT), [NotchDrop](https://github.com/Lakr233/NotchDrop) (MIT),
[boring.notch](https://github.com/TheBoredTeam/boring.notch) (GPL-3.0),
[Notchmeister](https://github.com/chockenberry/Notchmeister) (BSD-3). NotchShelf
is an independent implementation; see `LICENSE` (MIT).
