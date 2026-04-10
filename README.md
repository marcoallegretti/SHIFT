# Shift

Convergence mode for Plasma Mobile. One shell that works as a phone and
adapts to a desktop when you connect a monitor, keyboard, or mouse.

Shift is a fork of [plasma-mobile](https://invent.kde.org/plasma/plasma-mobile).
The upstream phone UI is untouched; convergence adds a layer on top.

### What convergence mode changes

* Navigation panel replaced by a dock with running-app indicators,
  favourites, context menus, and hover tooltips
* App drawer opens as a floating popup above the dock
* Window management: edge tiling, edge maximize, close buttons, task
  context menus, Overview integration
* Status bar gains a system tray, date display, and hover highlights
* Screen space reserved for the dock via layer-shell exclusive zone
* Desktop niceties: right-click wallpaper settings, minimize-all on
  home press, clickable page indicators

### Locations

* [components/mobileshell](components/mobileshell) - private shell component library
* [containments](containments) - shell panels (homescreens, status bar, task panel)
* [envmanager](envmanager) - convergence mode environment manager (kwinrc, etc.)
* [kwin/scripts](kwin/scripts) - KWin scripts for convergence window behaviour
* [kcms](kcms) - settings modules
* [look-and-feel](look-and-feel/contents) - Plasma look-and-feel packages
* [shell](shell) - Plasma shell package
* [quicksettings](quicksettings) - quick settings for the action drawer

### Building

```
cmake -B build
cmake --build build
cmake --install build
```

### Upstream

See [pm_README.md](pm_README.md) for the original Plasma Mobile README.
