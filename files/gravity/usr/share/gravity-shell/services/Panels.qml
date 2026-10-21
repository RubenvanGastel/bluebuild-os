pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which popup panels are open.
// `gravity-shell ipc call quickPanel toggle` opens the quick panel on the focused screen,
// `... monitor toggle` the system monitor, `... battery toggle` the battery panel.
Singleton {
    id: root

    // Output the quick panel is open on; "" = closed.
    property string quick: ""
    // Height the open quick panel takes below a top bar, so notifications can go under it.
    property real quickHeight: 0

    function toggleQuick(output: string): void {
        quick = quick === output ? "" : output;
        if (quick !== "") {
            closeTray();
            closeMonitor();
            closeBattery();
        }
    }

    function closeQuick(): void {
        quick = "";
    }

    // The open tray menu: output, the app's menu (QsMenuHandle) and where along the bar its
    // far end (right, or bottom along a side) goes, in screen coordinates. trayOutput "" =
    // closed.
    property string trayOutput: ""
    property var trayMenu: null
    property real trayAt: 0

    function openTray(output: string, menu: var, at: real): void {
        closeQuick();
        closeMonitor();
        closeBattery();
        trayMenu = menu;
        trayAt = at;
        trayOutput = output;
    }

    function closeTray(): void {
        trayOutput = "";
    }

    // The system monitor panel: output ("" = closed) and where along the bar it centres,
    // on its pill (each bar tells where that is on its output).
    property string monitor: ""
    property real monitorAt: 0
    property var monitorAnchors: ({})

    function setMonitorAnchor(output: string, at: real): void {
        monitorAnchors[output] = at;
    }

    function toggleMonitor(output: string): void {
        if (monitor === output) {
            closeMonitor();
            return;
        }
        closeQuick();
        closeTray();
        closeBattery();
        // Unknown (no bar there yet, or the pill is hidden): at the far end, kept clear of
        // the screen edge.
        monitorAt = monitorAnchors[output] ?? 1e6;
        monitor = output;
    }

    function closeMonitor(): void {
        monitor = "";
    }

    // The battery panel, as the system monitor: output ("" = closed) and where along the
    // bar it centres, on the battery pill.
    property string battery: ""
    property real batteryAt: 0
    property var batteryAnchors: ({})

    function setBatteryAnchor(output: string, at: real): void {
        batteryAnchors[output] = at;
    }

    function toggleBattery(output: string): void {
        if (battery === output) {
            closeBattery();
            return;
        }
        closeQuick();
        closeTray();
        closeMonitor();
        batteryAt = batteryAnchors[output] ?? 1e6;
        battery = output;
    }

    function closeBattery(): void {
        battery = "";
    }

    // Asks the settings card to open, on a page ("" = the one it was on last).
    signal settingsRequested(string page)

    function openSettings(page: string): void {
        settingsRequested(page);
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

    // `gravity-shell ipc call battery toggle`, on the focused screen.
    IpcHandler {
        target: "battery"

        function toggle(): void {
            root.toggleBattery(Object.values(Niri.workspaces).find(w => w.is_focused)?.output ?? Quickshell.screens[0]?.name ?? "");
        }
    }
}
