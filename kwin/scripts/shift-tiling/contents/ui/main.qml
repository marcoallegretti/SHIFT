// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2
//
// SHIFT Dynamic Tiling — KWin declarative script
//
// Architecture:
//   - One ScreenState per output, keyed by output.name
//   - Each ScreenState holds an ordered list of TileNodes
//   - A TileNode is { win, rect } where rect is absolute in-screen coordinates
//   - On any change (add/remove/resize) the layout is recomputed from scratch
//     for the affected screen using a BSP algorithm
//   - Drag detection uses interactiveMoveResizeStarted/Stepped/Finished
//   - Snap zones are the 6 screen-edge regions (left/right/top/corners)
//   - Gap: outer 8px on screen edges, inner 8px between tiles (4px each side)

import QtQuick
import org.kde.kwin as KWinComponents
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

Item {
    id: root

    // ── Configuration ───────────────────────────────────────────────────────
    readonly property int outerGap: 8
    readonly property int innerGap: 8    // half applied to each edge → 4px per tile

    // ── State ───────────────────────────────────────────────────────────────

    // Per-screen tile list.  Key: output.name  Value: [{win, rect}]
    // rect is a Qt.rect in absolute screen coordinates.
    property var screenTiles: ({})

    // Windows the user has manually floated (by UUID string).
    property var floatedWindows: ({})

    // Whether tiling is globally enabled.
    property bool tilingEnabled: true

    // Drag state.
    //
    // Behaviour: dragging a tile and dropping it onto ANOTHER tile swaps
    // their positions in the BSP layout.  Dropping anywhere else does
    // nothing (the window will be re-tiled into its original slot on the
    // next layout pass, unless KWin's native quick-tile / electric border
    // takes over — which is fine; we don't fight it).
    property var draggingWindow: null
    property var swapOutlineActive: false

    // Reorder state — kept stable while dragging so the rest of the layout
    // doesn't shuffle under the cursor.
    property string dragSourceScreen: ""
    property int    dragSourceIndex:  -1
    property var    dragSwapTarget:   null   // {screen, index, rect} of tile under cursor

    // Deferred retile queue.
    // The dockSpaceReserver LayerShell exclusive zone needs one Wayland
    // roundtrip after setMaximize() before KWin updates MaximizeArea.
    // We queue output names and flush after 200 ms — same pattern as
    // convergentwindows constrainAfterRestoreTimer.
    property var pendingRetile: []

    Timer {
        id: retileTimer
        interval: 200
        repeat: false
        onTriggered: {
            const queue = root.pendingRetile.slice();
            root.pendingRetile = [];
            const done = {};
            for (let i = 0; i < queue.length; i++) {
                if (!done[queue[i]]) {
                    done[queue[i]] = true;
                    root.retileScreen(queue[i]);
                }
            }
        }
    }

    function scheduleRetile(outputName) {
        const q = root.pendingRetile.slice();
        if (q.indexOf(outputName) < 0) q.push(outputName);
        root.pendingRetile = q;
        retileTimer.restart();
    }

    // ── Tiling guard ────────────────────────────────────────────────────────

    // Active when convergence is on, gaming is off, AND the user has
    // dynamic tiling enabled in quick settings.  When this returns false
    // the script is fully inert and KWin's native quick-tile behaviour
    // owns window placement.
    function isConvergence() {
        return ShellSettings.Settings.convergenceModeEnabled &&
               !ShellSettings.Settings.gamingModeEnabled &&
               ShellSettings.Settings.dynamicTilingEnabled;
    }

    // Mirror the same guard used by convergentwindows: only normalWindow is
    // reliable in the KWin 6 declarative script API.  Add maximizable to
    // avoid calling setMaximize on layer-shell / panel surfaces.
    function shouldIgnore(win) {
        if (!win || win.deleted) return true;
        if (!win.normalWindow) return true;   // panels, dock, desktop, layer-shell
        if (!win.maximizable) return true;    // fixed/special surfaces
        if (win.fullScreen) return true;
        // Skip xwaylandvideobridge (same as convergentwindows)
        if (win.resourceClass === "xwaylandvideobridge") return true;
        return false;
    }

    function shouldFloat(win) {
        if (!win) return true;
        // Fixed-size windows (won't tile sensibly)
        const minW = win.minSize ? win.minSize.width  : 0;
        const maxW = win.maxSize ? win.maxSize.width  : 0;
        const minH = win.minSize ? win.minSize.height : 0;
        const maxH = win.maxSize ? win.maxSize.height : 0;
        if (minW > 0 && maxW > 0 && minW >= maxW) return true;
        if (minH > 0 && maxH > 0 && minH >= maxH) return true;
        // Manually floated
        if (floatedWindows[win.internalId]) return true;
        return false;
    }

    function isTileable(win) {
        if (!tilingEnabled) return false;
        if (!isConvergence()) return false;
        if (shouldIgnore(win)) return false;
        if (shouldFloat(win)) return false;
        return true;
    }

    // ── Layout engine ───────────────────────────────────────────────────────

    function workRect(win) {
        const output = win.output;
        const desktop = win.desktops[0];
        if (!output || !desktop) return null;
        return KWinComponents.Workspace.clientArea(
            KWinComponents.Workspace.MaximizeArea, output, desktop);
    }

    // Apply outer + inner gaps to a list of rects that together tile a screen.
    // outer: gap between screen edge and tile
    // inner: total gap between two adjacent tiles (split equally, so 4px each side)
    function applyGaps(rects, workArea) {
        if (!rects || rects.length === 0) return rects;
        const half = innerGap / 2;
        const result = [];
        for (let i = 0; i < rects.length; i++) {
            let r = rects[i];
            // Determine which edges touch the work area boundary
            const atLeft   = Math.abs(r.x - workArea.x) < 2;
            const atTop    = Math.abs(r.y - workArea.y) < 2;
            const atRight  = Math.abs((r.x + r.width)  - (workArea.x + workArea.width))  < 2;
            const atBottom = Math.abs((r.y + r.height) - (workArea.y + workArea.height)) < 2;

            const left   = atLeft   ? outerGap       : half;
            const top    = atTop    ? outerGap       : half;
            const right  = atRight  ? outerGap       : half;
            const bottom = atBottom ? outerGap       : half;

            result.push(Qt.rect(
                r.x + left,
                r.y + top,
                r.width  - left - right,
                r.height - top  - bottom
            ));
        }
        return result;
    }

    // Binary-space-partition layout.
    // Splits `area` recursively for `n` windows.
    // Returns an ordered array of Qt.rect (without gaps applied).
    function bspRects(area, n) {
        if (n <= 0) return [];
        if (n === 1) return [area];

        // Pick split axis: split the longer dimension
        const splitHorizontally = area.width >= area.height;
        const rects = [];

        if (splitHorizontally) {
            // Left half gets one window; right half gets (n-1)
            const leftW = Math.round(area.width / 2);
            const left  = Qt.rect(area.x, area.y, leftW, area.height);
            const right = Qt.rect(area.x + leftW, area.y, area.width - leftW, area.height);
            rects.push(left);
            const sub = bspRects(right, n - 1);
            for (let i = 0; i < sub.length; i++) rects.push(sub[i]);
        } else {
            // Top half gets one window; bottom half gets (n-1)
            const topH = Math.round(area.height / 2);
            const top    = Qt.rect(area.x, area.y, area.width, topH);
            const bottom = Qt.rect(area.x, area.y + topH, area.width, area.height - topH);
            rects.push(top);
            const sub = bspRects(bottom, n - 1);
            for (let i = 0; i < sub.length; i++) rects.push(sub[i]);
        }
        return rects;
    }

    // Recompute and apply layout for a single screen.
    function retileScreen(outputName) {
        const tiles = screenTiles[outputName];
        if (!tiles || tiles.length === 0) return;

        // Get work area from the first window's output
        let area = null;
        for (let i = 0; i < tiles.length; i++) {
            const r = workRect(tiles[i].win);
            if (r) { area = r; break; }
        }
        if (!area) return;

        const n = tiles.length;
        const rawRects = bspRects(area, n);
        const gappedRects = applyGaps(rawRects, area);

        for (let i = 0; i < tiles.length; i++) {
            const win = tiles[i].win;
            if (!win || win.deleted) continue;
            const r = gappedRects[i];
            tiles[i].rect = r;
            win.frameGeometry = r;
        }
        // Trigger a binding update
        screenTiles[outputName] = tiles.slice();
    }

    // Retile all screens.
    function retileAll() {
        for (const name in screenTiles) {
            retileScreen(name);
        }
    }

    // Add a window to its screen's tile list and retile.
    function addWindow(win) {
        if (!isTileable(win)) return;

        const output = win.output;
        if (!output) return;
        const name = output.name;

        if (!screenTiles[name]) {
            screenTiles[name] = [];
        }

        // Avoid duplicates
        const tiles = screenTiles[name];
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i].win.internalId === win.internalId) return;
        }

        tiles.push({ win: win, rect: Qt.rect(0, 0, 0, 0) });
        screenTiles[name] = tiles;

        // Un-maximize now so the exclusive-zone Wayland roundtrip begins;
        // retileScreen runs 200 ms later when MaximizeArea has settled.
        // (Same pattern as convergentwindows constrainAfterRestoreTimer.)
        if (win.maximizable) win.setMaximize(false, false);
        win.noBorder = false;
        scheduleRetile(name);
    }

    // Remove a window from its screen's tile list and retile.
    function removeWindow(win) {
        if (!win) return;
        const output = win.output;
        const name = output ? output.name : null;

        // Search all screens (window may have been moved)
        for (const sName in screenTiles) {
            const tiles = screenTiles[sName];
            for (let i = 0; i < tiles.length; i++) {
                if (tiles[i].win.internalId === win.internalId) {
                    tiles.splice(i, 1);
                    screenTiles[sName] = tiles;
                    retileScreen(sName);
                    return;
                }
            }
        }
    }

    // ── Keyboard navigation helpers ──────────────────────────────────────────

    function centreOf(rect) {
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    }

    // Find the tile on-screen whose centre is most in `direction` from `fromRect`.
    // direction: "left"|"right"|"up"|"down"
    function findNeighbour(fromWin, direction) {
        const outputName = fromWin.output ? fromWin.output.name : null;
        if (!outputName) return null;
        const tiles = screenTiles[outputName];
        if (!tiles) return null;

        const from = fromWin.frameGeometry;
        const fc = centreOf(from);
        let best = null;
        let bestScore = Infinity;

        for (let i = 0; i < tiles.length; i++) {
            const t = tiles[i];
            if (t.win.internalId === fromWin.internalId) continue;
            const tc = centreOf(t.rect);
            const dx = tc.x - fc.x;
            const dy = tc.y - fc.y;

            let inDirection = false;
            let primary = 0;
            let secondary = 0;
            switch (direction) {
            case "left":  inDirection = dx < -5; primary = -dx; secondary = Math.abs(dy); break;
            case "right": inDirection = dx >  5; primary =  dx; secondary = Math.abs(dy); break;
            case "up":    inDirection = dy < -5; primary = -dy; secondary = Math.abs(dx); break;
            case "down":  inDirection = dy >  5; primary =  dy; secondary = Math.abs(dx); break;
            }
            if (!inDirection) continue;
            // Score: penalise perpendicular distance lightly
            const score = primary + secondary * 0.3;
            if (score < bestScore) { bestScore = score; best = t.win; }
        }
        return best;
    }

    // ── Workspace connections ─────────────────────────────────────────────

    Connections {
        target: KWinComponents.Workspace

        function onWindowAdded(win) {
            if (isTileable(win)) {
                addWindow(win);
                win.interactiveMoveResizeStarted.connect(function() { root.onDragStart(win); });
                win.interactiveMoveResizeStepped.connect(function(geo) { root.onDragStep(win, geo); });
                win.interactiveMoveResizeFinished.connect(function() { root.onDragEnd(win); });
            }
        }

        function onWindowRemoved(win) {
            root.removeWindow(win);
        }
    }

    Connections {
        target: ShellSettings.Settings

        function onConvergenceModeEnabledChanged() {
            if (isConvergence()) {
                // Tile all existing normal windows
                const wins = KWinComponents.Workspace.windows;
                for (let i = 0; i < wins.length; i++) {
                    addWindow(wins[i]);
                }
            } else {
                // Clear all tiles — the convergentwindows script will re-maximize
                screenTiles = {};
            }
        }

        function onGamingModeEnabledChanged() {
            if (ShellSettings.Settings.gamingModeEnabled) {
                screenTiles = {};
            } else if (isConvergence()) {
                const wins = KWinComponents.Workspace.windows;
                for (let i = 0; i < wins.length; i++) {
                    addWindow(wins[i]);
                }
            }
        }

        function onDynamicTilingEnabledChanged() {
            if (isConvergence()) {
                const wins = KWinComponents.Workspace.windows;
                for (let i = 0; i < wins.length; i++) {
                    addWindow(wins[i]);
                }
            } else {
                // Tiling turned off — leave windows where they are.
                screenTiles = {};
            }
        }
    }

    // ── Drag handlers ─────────────────────────────────────────────────────

    // Find the (screen, index) of an existing tile holding this window.
    function findTileSlot(win) {
        for (const sName in screenTiles) {
            const tiles = screenTiles[sName];
            for (let i = 0; i < tiles.length; i++) {
                if (tiles[i].win && tiles[i].win.internalId === win.internalId) {
                    return { screen: sName, index: i };
                }
            }
        }
        return null;
    }

    // Find the tile under a cursor position, ignoring the dragged window.
    function findTileAtCursor(cursor, ignoreWin) {
        for (const sName in screenTiles) {
            const tiles = screenTiles[sName];
            for (let i = 0; i < tiles.length; i++) {
                const t = tiles[i];
                if (ignoreWin && t.win && t.win.internalId === ignoreWin.internalId) continue;
                const r = t.rect;
                if (!r || r.width <= 0 || r.height <= 0) continue;
                if (cursor.x >= r.x && cursor.x <= r.x + r.width &&
                    cursor.y >= r.y && cursor.y <= r.y + r.height) {
                    return { screen: sName, index: i, rect: r };
                }
            }
        }
        return null;
    }

    function onDragStart(win) {
        if (!isConvergence()) return;
        draggingWindow = win;
        swapOutlineActive = false;
        dragSwapTarget = null;

        // Remember the source slot so we can swap on drop.
        // The tile stays in screenTiles[] during the drag so the rest of
        // the layout doesn't shuffle.
        const slot = findTileSlot(win);
        if (slot) {
            dragSourceScreen = slot.screen;
            dragSourceIndex  = slot.index;
        } else {
            dragSourceScreen = "";
            dragSourceIndex  = -1;
        }
    }

    function onDragStep(win, geo) {
        if (!isConvergence()) return;
        if (draggingWindow !== win) return;

        // Only show an outline when the cursor is over another tile —
        // a clear visual hint that "drop here = swap".
        const cursor = KWinComponents.Workspace.cursorPos;
        const target = findTileAtCursor(cursor, win);

        if (target) {
            if (!dragSwapTarget ||
                dragSwapTarget.screen !== target.screen ||
                dragSwapTarget.index  !== target.index) {
                dragSwapTarget = target;
                KWinComponents.Workspace.showOutline(target.rect);
                swapOutlineActive = true;
            }
        } else {
            dragSwapTarget = null;
            if (swapOutlineActive) {
                KWinComponents.Workspace.hideOutline();
                swapOutlineActive = false;
            }
        }
    }

    function onDragEnd(win) {
        if (!isConvergence()) return;
        if (swapOutlineActive) {
            KWinComponents.Workspace.hideOutline();
            swapOutlineActive = false;
        }

        // Dropped on another tile → swap source/target slots.
        if (dragSwapTarget && dragSourceScreen && dragSourceIndex >= 0) {
            const sScreen = dragSourceScreen;
            const sIdx    = dragSourceIndex;
            const tScreen = dragSwapTarget.screen;
            const tIdx    = dragSwapTarget.index;

            const sTiles = screenTiles[sScreen];
            const tTiles = screenTiles[tScreen];
            if (sTiles && tTiles && sTiles[sIdx] && tTiles[tIdx]) {
                const a = sTiles[sIdx];
                const b = tTiles[tIdx];
                if (sScreen === tScreen) {
                    sTiles[sIdx] = b;
                    sTiles[tIdx] = a;
                    screenTiles[sScreen] = sTiles.slice();
                    retileScreen(sScreen);
                } else {
                    sTiles[sIdx] = b;
                    tTiles[tIdx] = a;
                    screenTiles[sScreen] = sTiles.slice();
                    screenTiles[tScreen] = tTiles.slice();
                    retileScreen(sScreen);
                    retileScreen(tScreen);
                }
            }
        }
        // Dropped elsewhere → restore the source tile to its original slot.
        // (KWin's native quick-tile may have moved the window; retileScreen
        // sets frameGeometry back to the BSP rect so the layout stays intact.)
        else if (dragSourceScreen && dragSourceIndex >= 0) {
            retileScreen(dragSourceScreen);
        }

        dragSwapTarget = null;
        dragSourceScreen = "";
        dragSourceIndex = -1;
        draggingWindow = null;
    }

    // ── Keyboard shortcuts ─────────────────────────────────────────────────

    // Focus navigation
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Focus Left"
        text: "SHIFT Tiling: Focus window to the left"
        sequence: "Meta+H"
        onActivated: {
            const win = KWinComponents.Workspace.activeWindow;
            if (!win) return;
            const target = root.findNeighbour(win, "left");
            if (target) KWinComponents.Workspace.activeWindow = target;
        }
    }
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Focus Right"
        text: "SHIFT Tiling: Focus window to the right"
        sequence: "Meta+L"
        onActivated: {
            const win = KWinComponents.Workspace.activeWindow;
            if (!win) return;
            const target = root.findNeighbour(win, "right");
            if (target) KWinComponents.Workspace.activeWindow = target;
        }
    }
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Focus Up"
        text: "SHIFT Tiling: Focus window above"
        sequence: "Meta+K"
        onActivated: {
            const win = KWinComponents.Workspace.activeWindow;
            if (!win) return;
            const target = root.findNeighbour(win, "up");
            if (target) KWinComponents.Workspace.activeWindow = target;
        }
    }
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Focus Down"
        text: "SHIFT Tiling: Focus window below"
        sequence: "Meta+J"
        onActivated: {
            const win = KWinComponents.Workspace.activeWindow;
            if (!win) return;
            const target = root.findNeighbour(win, "down");
            if (target) KWinComponents.Workspace.activeWindow = target;
        }
    }

    // Float toggle
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Float Toggle"
        text: "SHIFT Tiling: Toggle float for active window"
        sequence: "Meta+F"
        onActivated: {
            const win = KWinComponents.Workspace.activeWindow;
            if (!win) return;
            const id = win.internalId;
            if (root.floatedWindows[id]) {
                delete root.floatedWindows[id];
                root.addWindow(win);
            } else {
                root.floatedWindows[id] = true;
                root.removeWindow(win);
            }
        }
    }

    // Tiling on/off
    KWinComponents.ShortcutHandler {
        name: "SHIFT Tiling Toggle"
        text: "SHIFT Tiling: Toggle tiling on/off"
        sequence: "Meta+T"
        onActivated: {
            root.tilingEnabled = !root.tilingEnabled;
            if (root.tilingEnabled) {
                const wins = KWinComponents.Workspace.windows;
                for (let i = 0; i < wins.length; i++) root.addWindow(wins[i]);
            } else {
                root.screenTiles = {};
            }
        }
    }

    // ── Snap-assist hover trigger ─────────────────────────────────────────
    //
    // The decoration QML sandbox has no DBus / kglobalaccel access, so we
    // detect the maximize-button hover here in the script.  We poll the
    // cursor every 150 ms; when it stays in the top-right ~50×barHeight
    // strip of the active window for 500 ms (without dragging), we invoke
    // the SHIFT Snap Assist effect via kglobalaccel.
    //
    // Constants must match the decoration:
    //   barHeight 30, btnSize 16, btnSpacing 8, btnSideMargin 12.
    // Right-cluster width ≈ 12 (margin) + 3·(16+8) = ~84 px.  We use 90 px
    // to be forgiving.

    readonly property int hoverBarHeight:    30
    readonly property int hoverButtonStrip:  90
    property var  hoverWindowId: null
    property int  hoverTicks:    0

    Timer {
        id: snapHoverTimer
        interval: 150
        repeat: true
        running: root.tilingEnabled && root.isConvergence()

        onTriggered: {
            // Don't fire while dragging or while no window is focused.
            if (root.draggingWindow) { root.hoverTicks = 0; root.hoverWindowId = null; return; }
            const win = KWinComponents.Workspace.activeWindow;
            if (!win || !win.normalWindow || win.fullScreen) {
                root.hoverTicks = 0; root.hoverWindowId = null; return;
            }
            const cursor = KWinComponents.Workspace.cursorPos;
            const fg = win.frameGeometry;
            // Right-side titlebar strip in absolute coords.
            const stripX = fg.x + fg.width - root.hoverButtonStrip;
            const stripY = fg.y;
            if (cursor.x >= stripX && cursor.x <= fg.x + fg.width &&
                cursor.y >= stripY && cursor.y <= stripY + root.hoverBarHeight) {
                if (root.hoverWindowId === win.internalId) {
                    root.hoverTicks++;
                    // 500 ms ≈ 4 ticks at 150 ms (3 + 1 to be safe).
                    if (root.hoverTicks === 4) {
                        callDBus(
                            "org.kde.kglobalaccel",
                            "/component/kwin",
                            "org.kde.kglobalaccel.Component",
                            "invokeShortcut",
                            "SHIFT Snap Assist"
                        );
                    }
                } else {
                    root.hoverWindowId = win.internalId;
                    root.hoverTicks = 1;
                }
            } else {
                root.hoverTicks = 0;
                root.hoverWindowId = null;
            }
        }
    }

    // ── Right-click menu ──────────────────────────────────────────────────

    // Note: registerUserActionsMenu is a global function in KWin JS scripts.
    // In declarative QML scripts it is exposed via the KWin global object.
    // We wire it up after the component is complete.
    Component.onCompleted: {
        // Connect to existing windows
        const wins = KWinComponents.Workspace.windows;
        for (let i = 0; i < wins.length; i++) {
            const win = wins[i];
            if (isTileable(win)) {
                addWindow(win);
                win.interactiveMoveResizeStarted.connect(function() { root.onDragStart(win); });
                win.interactiveMoveResizeStepped.connect(function(geo) { root.onDragStep(win, geo); });
                win.interactiveMoveResizeFinished.connect(function() { root.onDragEnd(win); });
            }
        }
    }
}
