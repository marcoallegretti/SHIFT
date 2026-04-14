# Hacking on Shift

Shift is a convergent Plasma Mobile shell.  This guide covers
building and testing it locally without polluting your host system.

The approach: keep every build dependency inside a **distrobox** container
(openSUSE Tumbleweed), and preview the shell in a **nested KWin** window
that runs on your host.

---

## 1. Host prerequisites

You need three things installed on your host (outside the container):

| Tool               | Why                                        |
| ------------------ | ------------------------------------------ |
| `podman`           | Container runtime used by distrobox.       |
| `distrobox`        | Manages the build container.               |
| `kwin_wayland`     | Launches a nested Wayland compositor for preview. |
| `dbus-run-session` | Provides a private D-Bus session to kwin.  |

On Plasma desktops, `kwin_wayland` and `dbus-run-session` are already
present.  For distrobox and podman, install them through your host
package manager.

---

## 2. Create the build container

Shift builds against the latest KDE Frameworks 6, Plasma 6, and Qt 6.
openSUSE Tumbleweed tracks them closely and makes a good base.

### 2a. Work around missing `/etc/zypp/zypp.conf`

As of April 2026, the Tumbleweed container image ships without
`/etc/zypp/zypp.conf`, which causes `distrobox create` to fail during
init (zypper refuses to run without it).  Create a patched image first:

```bash
podman run --name tw-fix registry.opensuse.org/opensuse/tumbleweed:latest \
    bash -c 'mkdir -p /etc/zypp && echo "## zypp.conf" > /etc/zypp/zypp.conf'
podman commit tw-fix localhost/tw-fixed:latest
podman rm tw-fix
```

> **Note:**  If a future Tumbleweed image ships with the file already
> present, you can skip this step and use the upstream image directly.

### 2b. Create and initialise the distrobox

```bash
distrobox create --name shift-tw --image localhost/tw-fixed:latest
distrobox enter shift-tw -- echo "init ok"
```

Wait for the `Container Setup Complete!` message.  The container's home
directory is transparently mapped to your real `$HOME`, so the source
tree is shared between host and container.

---

## 3. Install build dependencies

All `zypper` commands run inside the container.  Either prefix them with
`distrobox enter shift-tw --` or open an interactive shell first with
`distrobox enter shift-tw`.

### Build tools and libraries

```bash
sudo zypper install --no-confirm \
    cmake gcc-c++ ninja kf6-extra-cmake-modules \
    qt6-core-devel qt6-gui-devel qt6-qml-devel qt6-quick-devel \
    qt6-sensors-devel qt6-waylandclient-devel \
    qt6-waylandclient-private-devel qt6-wayland-private-devel \
    kf6-ki18n-devel kf6-kglobalaccel-devel kf6-kio-devel \
    kf6-kconfig-devel kf6-kdbusaddons-devel kf6-kitemmodels-devel \
    kf6-kservice-devel kf6-knotifications-devel kf6-kcmutils-devel \
    kf6-kpackage-devel kf6-kjobwidgets-devel kf6-kwindowsystem-devel \
    kf6-kauth-devel kf6-kirigami-devel kf6-ksvg-devel \
    kf6-modemmanager-qt-devel kf6-networkmanager-qt-devel \
    kirigami-addons6-devel libplasma6-devel plasma6-activities-devel \
    libkscreen6-devel kwayland6-devel kpipewire6-devel \
    kwin6-devel layer-shell-qt6-devel plasma6-workspace-devel \
    plasma-wayland-protocols qcoro-qt6-devel \
    libepoxy-devel libxcb-devel wayland-devel systemd-devel
```

### Runtime dependencies (needed for preview, not for compilation)

The nested preview runs the system `plasmashell` binary.  It needs a
complete Plasma Mobile runtime so all QML imports resolve:

```bash
sudo zypper install --no-confirm \
    plasma6-mobile plasma6-workspace plasma6-nano plasma6-nm plasma6-pa \
    layer-shell-qt6-imports kf6-bluez-qt-imports \
    kf6-networkmanager-qt-imports \
    breeze6-wallpapers plasma6-workspace-wallpapers
```

---

## 4. Configure and build

All build commands run inside the container.  The source tree lives on
the host filesystem (e.g. `~/Projects/Shift`); distrobox maps it
automatically.

### Configure (first time or after CMakeLists.txt changes)

```bash
distrobox enter shift-tw -- bash -c '
    cd ~/Projects/Shift
    cmake -S . -B build-clean -G Ninja \
        -DCMAKE_INSTALL_PREFIX=$PWD/.prefix \
        -DCMAKE_BUILD_TYPE=Debug \
        -DPLASMA_MOBILE_LOCAL_KAUTH_INSTALL=ON
'
```

`-DCMAKE_INSTALL_PREFIX=$PWD/.prefix` tells cmake to install into a
local directory instead of `/usr`.
`-DPLASMA_MOBILE_LOCAL_KAUTH_INSTALL=ON` redirects KAuth helper
executables and polkit policy files into the local prefix so that
`cmake --install` works without root.  During configure, ECM auto-generates
`build-clean/prefix.sh` — a shell snippet that prepends `.prefix` paths
to `QT_PLUGIN_PATH`, `QML2_IMPORT_PATH`, `XDG_DATA_DIRS`, etc.  The
preview script sources this file so the system `plasmashell` finds our
custom-built plugins first and falls back to system ones for everything
else.

### Build everything

```bash
distrobox enter shift-tw -- cmake --build ~/Projects/Shift/build-clean
```

Or build only the homescreen applet for a faster cycle:

```bash
distrobox enter shift-tw -- cmake --build ~/Projects/Shift/build-clean \
    --target org.kde.plasma.mobile.homescreen.folio
```

### Install

```bash
distrobox enter shift-tw -- cmake --install ~/Projects/Shift/build-clean
```

This populates `.prefix/`.  There is no need to install to `~/.local`
unless you also want to use the shell outside the preview window (e.g.
in a full mobile session).

---

## 5. Preview in a nested KWin window

The preview launches a **host** `kwin_wayland` compositor with its own
Wayland socket, then starts `plasmashell` **inside the container**
connected to that socket.  The end result is a self-contained window
showing the mobile shell — no need to log out or switch sessions.

### The preview script

Create `preview.sh` in the project root:

```bash
#!/usr/bin/env bash
# Launch Shift in a nested KWin window for testing.
#
# kwin_wayland runs on the host (needs direct GPU access) with the project
# prefix paths so it can load the convergentwindows KWin script and resolve
# its QML imports.  plasmashell runs inside the distrobox container.
#
# Usage:  ./preview.sh [WIDTHxHEIGHT]
#   e.g.  ./preview.sh              # 1280x720
#         ./preview.sh 1920x1080

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIZE="${1:-1280x720}"
WIDTH="${SIZE%%x*}"
HEIGHT="${SIZE##*x}"

PREFIX="$SCRIPT_DIR/.prefix"

# Write an ephemeral inner launcher (kwin needs a single executable path)
INNER=$(mktemp /tmp/shift-inner.XXXXXX.sh)
chmod +x "$INNER"
trap 'rm -f "$INNER"' EXIT

cat > "$INNER" << ENDSCRIPT
#!/usr/bin/env bash
exec distrobox enter shift-tw -- bash -c '
cd "$SCRIPT_DIR"
. ./build-clean/prefix.sh
export WAYLAND_DISPLAY=shift-kwin
export QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORMTHEME=KDE
export EGL_PLATFORM=wayland
export QT_QUICK_CONTROLS_STYLE=org.kde.breeze
export QT_QUICK_CONTROLS_MOBILE=true
export PLASMA_PLATFORM=phone:handset
export PLASMA_DEFAULT_SHELL=org.kde.plasma.mobileshell
export QT_FORCE_STDERR_LOGGING=1
exec plasmashell --replace -p org.kde.plasma.mobileshell
'
ENDSCRIPT

# Expose the project prefix to the host kwin_wayland so it can find
# KWin scripts (convergentwindows) and their QML dependencies.
# Also overlay ~/.config/plasma-mobile so KWin reads the mobile kwinrc
# (envmanager writes convergentwindowsEnabled, Placement, etc. there).
export XDG_DATA_DIRS="$PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_DIRS="$HOME/.config/plasma-mobile:${XDG_CONFIG_DIRS:-/etc/xdg}"
export QT_PLUGIN_PATH="$PREFIX/lib64/plugins:${QT_PLUGIN_PATH:-}"
export QML2_IMPORT_PATH="$PREFIX/lib64/qml:${QML2_IMPORT_PATH:-}"

exec dbus-run-session \
    kwin_wayland --xwayland \
        --socket shift-kwin \
        --width "$WIDTH" \
        --height "$HEIGHT" \
        --exit-with-session "$INNER"
```

Make it executable: `chmod +x preview.sh`.

### How it works

1. `dbus-run-session` spins up an isolated D-Bus session so the nested
   compositor doesn't clash with your running desktop.
2. Four environment exports give the **host** `kwin_wayland` access to
   the project's `.prefix` (KWin scripts, QML plugins) and to
   `~/.config/plasma-mobile` (where envmanager writes convergence
   settings like `convergentwindowsEnabled`, `Placement`, etc.).
3. `kwin_wayland` opens a window on your current desktop and creates a
   Wayland socket named `shift-kwin`.  Because of the exports it can
   load the `convergentwindows` script, which handles maximising
   windows on undock and restoring decorations on dock.
4. The inner script enters the distrobox, sources `prefix.sh` to put
   the custom build first in all search paths, then starts
   `plasmashell` from the container's `/usr/bin/plasmashell` — but with
   our plugins loaded from `.prefix`.
5. `--exit-with-session` makes kwin close when plasmashell exits, and
   vice versa.

### Running it

```bash
./preview.sh              # 1280×720 (default)
./preview.sh 1920x1080    # Full-HD
./preview.sh 360x720      # Narrow phone
```

Close the KWin window to stop the preview.

### Convergence mode

Shift's convergence mode (desktop-style dock, auto-hide, etc.) requires
this in `~/.config/plasmamobilerc`:

```ini
[General]
convergenceModeEnabled=true
```

This file lives on the host (shared home), so just create or edit it
before running the preview.

---

## 6. Edit – build – preview cycle

The fast loop:

```bash
# 1.  Edit source files on the host with your editor.
# 2.  Build the changed target (runs inside the container):
distrobox enter shift-tw -- cmake --build ~/Projects/Shift/build-clean \
    --target org.kde.plasma.mobile.homescreen.folio

# 3.  Install:
distrobox enter shift-tw -- cmake --install ~/Projects/Shift/build-clean

# 4.  Preview:
./preview.sh
```

> **Tip:** QML files installed to `.prefix/share/` or
> `.prefix/lib64/qml/` are read at runtime.  For pure-QML changes you
> can skip the build step and just re-run `cmake --install` then
> restart the preview.  For C++ changes you need the full build.

### Key build targets

| Target | What it builds |
| ------ | -------------- |
| *(none — full build)* | Everything: all applets, QML plugins, KCMs, quicksettings, initial-start modules. |
| `org.kde.plasma.mobile.homescreen.folio` | Folio homescreen applet (app grid, dock, folders). |
| `org.kde.plasma.mobile.panel`            | Top status bar (clock, indicators). |
| `org.kde.plasma.mobile.taskpanel`        | Bottom navigation / gesture panel. |
| `org.kde.plasma.mobile.homescreen.halcyon` | Halcyon homescreen (alternative to Folio). |

---

## 7. Troubleshooting

### `plasmashell: not found`

The container needs the full `plasma6-workspace` package (which provides
`/usr/bin/plasmashell`), not just `plasma6-workspace-devel`.  Install it
with `sudo zypper install plasma6-workspace`.

### `module "org.kde.foo" is not installed`

A QML import is missing.  The error names the module; find the package
that provides it:

```bash
# Inside the container:
zypper se -x $(echo org.kde.foo | tr . /)   # crude guess
# Or search file contents:
zypper wp /usr/lib64/qt6/qml/org/kde/foo/qmldir
```

Common culprits:

| Module | Package |
| ------ | ------- |
| `org.kde.bluezqt` | `kf6-bluez-qt-imports` |
| `org.kde.plasma.networkmanagement` | `plasma6-nm` |
| `org.kde.plasma.private.volume` | `plasma6-pa` |
| `org.kde.plasma.private.nanoshell` | `plasma6-nano` |
| `org.kde.layershell` | `layer-shell-qt6-imports` |

### `Could not set containment property on rootObject`

This means the Desktop.qml failed to load, almost always due to a
missing QML module — look for the preceding `module "…" is not
installed` line.

### `FATAL ERROR: could not add wayland socket shift-kwin`

A previous preview didn't exit cleanly.  Remove the stale lock:

```bash
rm -f /run/user/$UID/shift-kwin.lock
pkill -f 'kwin_wayland.*shift-kwin'
```

### `distrobox create` hangs or zypper crashes during init

Likely the missing `/etc/zypp/zypp.conf` bug.  See
[2a. Work around missing zypp.conf](#2a-work-around-missing-etczyppzyppconf).

### Harmless warnings you can ignore

These appear in the preview output and are not errors:

- `fusermount3: failed to access mountpoint` — FUSE is restricted
  inside the nested session.
- `qt.qpa.services: Failed to register with host portal` — Portal
  registration unsupported in nested compositors.
- `kf.solid.backends.udisks2: Failed to fetch all devices` — No
  udisks2 in the isolated D-Bus session.
- `TypeError: Cannot read property 'volume' of null` — PulseAudio /
  PipeWire is not running in the sandbox.
- `Could not load a session backend` — systemd --user is not running in
  the nested D-Bus session.

---

## 8. Project layout (quick reference)

```
Shift/
├── CMakeLists.txt                  # Top-level build file
├── build-clean/                    # Out-of-source build directory
│   └── prefix.sh                   # Auto-generated by ECM; sources .prefix paths
├── .prefix/                        # Local install tree (not committed)
├── preview.sh                      # Nested KWin launcher (see §5)
├── shell/                          # Shell package (Desktop.qml, Panel.qml, applet overrides)
├── components/
│   └── mobileshell/                # QML & C++ for the mobile shell runtime plugin
├── containments/
│   ├── homescreens/folio/          # Folio homescreen applet
│   ├── panel/                      # Status bar
│   └── taskpanel/                  # Navigation bar / gesture panel
├── envmanager/                     # Applies KWin/KDE config on convergence mode changes
├── quicksettings/                  # Action drawer quick-setting tiles
├── kcms/                           # System Settings modules
└── kwin/
    ├── mobiletaskswitcher/         # KWin task-switcher plugin
    └── scripts/convergentwindows/  # KWin script: maximize on undock, restore borders on dock
```
