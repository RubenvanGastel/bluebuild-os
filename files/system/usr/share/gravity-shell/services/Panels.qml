pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which popup panels are open.
// `gravity-shell ipc call quickPanel toggle` opens the quick panel on the focused screen.
Singleton {
    id: root

    // Output the quick panel is open on; "" = closed.
    property string quick: ""
    // Height the open quick panel takes below the bar, so notifications can go under it.
    property real quickHeight: 0

    function toggleQuick(output: string): void {
        quick = quick === output ? "" : output;
    }

    function closeQuick(): void {
        quick = "";
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
}
