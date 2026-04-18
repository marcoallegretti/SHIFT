# Shift

A fork of KDE Plasma Mobile that adds a desktop-class convergence mode.

Plasma Mobile is a phone shell. It doesn't try to be anything else.
Shift picks up where it leaves off: when you connect a monitor, keyboard,
or mouse, the same device should feel like a desktop. No second OS, no
separate session — one shell that adapts.

## What's different from upstream

The upstream `plasma-mobile` repo provides the phone experience: homescreens,
a swipe-based navigation panel, an action drawer, and a status bar. All of
that still works. Shift adds a **convergence mode** layer on top — toggled
via `plasmamobilerc` — that swaps in desktop-oriented behaviour without
replacing the phone UI underneath.

Key changes so far:

- **Unified dock** replacing the navigation panel in convergence mode,
  with running-app indicators, favourites, context menus, and hover
  tooltips.
- **App drawer** opening as a centered popup instead of a full-screen
  swipe.
- **Window management** — edge tiling, screen-edge maximize, close
  buttons, task context menus, Overview integration.
- **Status bar** gains a system tray, date display, and hover highlights.
- **Screen space reservation** for the dock via a layer-shell exclusive
  zone, so maximized windows don't overlap it.
- **Desktop niceties** — right-click wallpaper settings, minimize-all on
  home press, clickable page indicators, action drawer toggle on click.
- **Thumbnail previews** on dock icon hover via PipeWire screencasting.
- **Pin to dock** — right-click a running app to pin it to favourites;
  pinned apps get a "Remove from Dock" action.

## Upstream base

Forked from `plasma-mobile` at KDE's Plasma 6 branch. Upstream commits
(translations, silent fixes) are preserved in the early history.
