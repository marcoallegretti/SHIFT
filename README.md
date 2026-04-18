# Shift

 SHIFT is an open source shell built on KDE Plasma Mobile, designed to adapt fluidly to your computing needs across devices

### Desktop demos

![Desktop overview](screenshots/quick_DesktopDemo.webm)
![Docked mode](screenshots/quick_DesktopDemo_docked.webm)
![Tiling](screenshots/quick_DesktopDemo_tiling.webm)

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
cmake -B build -DPLASMA_MOBILE_LOCAL_KAUTH_INSTALL=ON
cmake --build build
cmake --install build
```

### Disclaimer

SHIFT is an independent project based on KDE Plasma Mobile.

It is **not affiliated with or endorsed by** KDE or the KDE community.

Some visual elements (such as icons or graphical assets) may originate from KDE Plasma Mobile and are used in accordance with their respective licenses. These elements may be replaced in future versions as the project evolves.

All trademarks, including KDE, belong to their respective owners.

---

### Upstream Relationship

SHIFT is not intended as a direct contribution to KDE Plasma Mobile.

However, if parts of this project are considered useful, contributions or ideas may be proposed upstream in a collaborative manner.


See [pm_README.md](pm_README.md) for the original Plasma Mobile README.

---

### License

SHIFT-specific code is licensed under the [European Union Public Licence 1.2](LICENSES/EUPL-1.2.txt).

Upstream files retain their original licenses (GPL-2.0-or-later, LGPL-2.1-or-later, etc.).
See individual file headers and the [.reuse/dep5](.reuse/dep5) manifest for details.
