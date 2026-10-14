pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri state from `niri msg --json event-stream`. niri does not implement ext-workspace,
// so Quickshell's generic WindowManager module sees nothing; we read niri's IPC instead.
Singleton {
    id: root

    readonly property bool available: !!Quickshell.env("NIRI_SOCKET")

    // id -> workspace / window objects, exactly as niri sends them.
    property var workspaces: ({})
    property var windows: ({})
    property var focusedWindowId: null
    property bool overviewOpen: false

    readonly property var focusedWindow: focusedWindowId !== null ? (windows[focusedWindowId] ?? null) : null

    // Workspace ids on one output, in niri's top-to-bottom order.
    function workspaceIdsOn(output: string): var {
        return Object.values(workspaces)
            .filter(w => w.output === output)
            .sort((a, b) => a.idx - b.idx)
            .map(w => w.id);
    }

    function windowCountOn(workspaceId: int): int {
        let n = 0;
        for (const w of Object.values(windows))
            if (w.workspace_id === workspaceId)
                n++;
        return n;
    }

    function action(args: var): void {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    function focusWorkspace(id: int): void {
        const ws = workspaces[id];
        if (!ws)
            return;
        const focused = Object.values(workspaces).find(w => w.is_focused);
        if (focused && focused.output !== ws.output)
            Quickshell.execDetached(["sh", "-c", `niri msg action focus-monitor '${ws.output}' && niri msg action focus-workspace ${ws.idx}`]);
        else
            action(["focus-workspace", String(ws.idx)]);
    }

    function handle(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }

        if (ev.WorkspacesChanged) {
            const map = {};
            for (const w of ev.WorkspacesChanged.workspaces)
                map[w.id] = w;
            workspaces = map;
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const target = workspaces[id];
            if (!target)
                return;
            const prev = Object.values(workspaces).find(w => w.output === target.output && w.is_active);
            const map = {};
            for (const w of Object.values(workspaces)) {
                const c = Object.assign({}, w);
                if (c.output === target.output)
                    c.is_active = c.id === id;
                if (focused)
                    c.is_focused = c.id === id;
                map[c.id] = c;
            }
            workspaces = map;
            // Moving down the strip feels like falling: the world swings up past you.
            if (focused && prev && prev.id !== id)
                Gravity.kick(0, target.idx > prev.idx ? -1 : 1, 1);
        } else if (ev.WorkspaceActiveWindowChanged) {
            const { workspace_id, active_window_id } = ev.WorkspaceActiveWindowChanged;
            if (workspaces[workspace_id]) {
                const c = Object.assign({}, workspaces[workspace_id], { active_window_id });
                workspaces = Object.assign({}, workspaces, { [workspace_id]: c });
            }
        } else if (ev.WindowsChanged) {
            const map = {};
            let focusedId = null;
            for (const w of ev.WindowsChanged.windows) {
                map[w.id] = w;
                if (w.is_focused)
                    focusedId = w.id;
            }
            windows = map;
            focusedWindowId = focusedId;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            windows = Object.assign({}, windows, { [w.id]: w });
            if (w.is_focused)
                focusedWindowId = w.id;
        } else if (ev.WindowClosed) {
            const map = Object.assign({}, windows);
            delete map[ev.WindowClosed.id];
            windows = map;
            if (focusedWindowId === ev.WindowClosed.id)
                focusedWindowId = null;
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            const before = focusedWindow;
            focusedWindowId = id;
            // Scrolling sideways through columns nudges the field sideways.
            const a = before?.layout?.pos_in_scrolling_layout;
            const b = windows[id]?.layout?.pos_in_scrolling_layout;
            if (a && b && a[0] !== b[0] && before.workspace_id === windows[id].workspace_id)
                Gravity.kick(b[0] > a[0] ? -0.6 : 0.6, 0, 1);
        } else if (ev.OverviewOpenedOrClosed) {
            overviewOpen = ev.OverviewOpenedOrClosed.is_open;
        }
    }

    Process {
        id: stream

        running: root.available
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: stream.running = root.available
    }
}
