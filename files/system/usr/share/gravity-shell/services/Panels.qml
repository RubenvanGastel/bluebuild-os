pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which popup panels are open.
// `gravity-shell ipc call quickPanel toggle` opens the quick panel on the focused screen,
// `... monitor toggle` the system monitor.
Singleton {
    id: root

    // Output the quick panel is open on; "" = closed.
    property string quick: ""
    // Height the open quick panel takes below the bar, so notifications can go under it.
    property real quickHeight: 0

    function toggleQuick(output: string): void {
        quick = quick === output ? "" : output;
        if (quick !== "") {
            closeTray();
            closeMonitor();
        }
    }

    function closeQuick(): void {
        quick = "";
    }

    // The open tray menu: output, the app's menu (QsMenuHandle) and where its right edge
    // goes, in screen coordinates. trayOutput "" = closed.
    property string trayOutput: ""
    property var trayMenu: null
    property real trayX: 0

    function openTray(output: string, menu: var, x: real): void {
        closeQuick();
        closeMonitor();
        trayMenu = menu;
        trayX = x;
        trayOutput = output;
    }

    function closeTray(): void {
        trayOutput = "";
    }

    // The system monitor panel: output ("" = closed) and the screen x it centres on, under
    // its pill in the bar (each bar tells where that is on its output).
    property string monitor: ""
    property real monitorX: 0
    property var monitorAnchors: ({})

    function setMonitorAnchor(output: string, x: real): void {
        monitorAnchors[output] = x;
    }

    function toggleMonitor(output: string): void {
        if (monitor === output) {
            closeMonitor();
            return;
        }
        closeQuick();
        closeTray();
        // Unknown (no bar there yet): at the right, kept clear of the screen edge.
        monitorX = monitorAnchors[output] ?? 1e6;
        monitor = output;
    }

    function closeMonitor(): void {
        monitor = "";
    }

    IpcHandler {
        target: "quickPanel"

        function toggle(): void {
            root.toggleQuick(Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? Quickshell.screens[0]?.name ?? "");
        }

        // Output it is open on; empty when closed.
        function get(): string {
            return root.quick;
        }
    }

    // `gravity-shell ipc call monitor toggle` (Mod+M), on the focused screen.
    IpcHandler {
        target: "monitor"

        function toggle(): void {
            root.toggleMonitor(Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? Quickshell.screens[0]?.name ?? "");
        }
    }
}
