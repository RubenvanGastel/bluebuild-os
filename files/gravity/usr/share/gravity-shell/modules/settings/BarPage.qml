import QtQuick
import qs.services

// Which screen edge the bar runs along and what it shows.
Column {
    id: root

    required property var settings

    spacing: 22

    Choice {
        label: "Position"
        description: "Panels open out of the bar wherever it is; along a side it stacks its contents."
        options: [
            { value: "top", label: "Top", icon: "\u{f1513}" },
            { value: "bottom", label: "Bottom", icon: "\u{f10a9}" },
            { value: "left", label: "Left", icon: "\u{f10aa}" },
            { value: "right", label: "Right", icon: "\u{f10ab}" }
        ]
        value: Theme.barEdge
        onChosen: v => Config.set("barPosition", v)
    }

    Section {
        title: "Show in the bar"

        Toggle {
            label: "Workspaces"
            checked: Config.barWorkspaces
            onToggled: on => Config.set("barWorkspaces", on)
        }

        Toggle {
            label: "Window title"
            description: Theme.barVertical ? "Not shown while the bar is along a side." : ""
            checked: Config.barTitle
            onToggled: on => Config.set("barTitle", on)
        }

        Toggle {
            label: "Clock"
            checked: Config.barClock
            onToggled: on => Config.set("barClock", on)
        }

        Toggle {
            label: "System monitor"
            description: "CPU and memory; opens the monitor panel (also Mod+M)."
            checked: Config.barStats
            onToggled: on => Config.set("barStats", on)
        }

        Toggle {
            label: "Tray"
            checked: Config.barTray
            onToggled: on => Config.set("barTray", on)
        }

        Toggle {
            label: "Volume and battery"
            description: "Opens the quick panel. Without it, the quick panel still opens with gravity-shell ipc call quickPanel toggle."
            checked: Config.barStatus
            onToggled: on => Config.set("barStatus", on)
        }
    }
}
