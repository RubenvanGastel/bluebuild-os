import QtQuick
import qs.services

// Which screen edge the bar runs along and what it shows.
Column {
    id: root

    required property var settings

    spacing: 22

    Choice {
        label: I18n.tr("Position")
        description: I18n.tr("Panels open out of the bar wherever it is; along a side it stacks its contents.")
        options: [
            { value: "top", label: I18n.tr("Top"), icon: "\u{f1513}" },
            { value: "bottom", label: I18n.tr("Bottom"), icon: "\u{f10a9}" },
            { value: "left", label: I18n.tr("Left"), icon: "\u{f10aa}" },
            { value: "right", label: I18n.tr("Right"), icon: "\u{f10ab}" }
        ]
        value: Theme.barEdge
        onChosen: v => Config.set("barPosition", v)
    }

    Choice {
        label: I18n.tr("Style")
        description: Theme.barStyle === "floating" ? I18n.tr("A rounded bar away from the edge; panels open as cards under it.") : Theme.barStyle === "frame" ? I18n.tr("A thin border around the rest of the screen, rounded on the inside.") : I18n.tr("Against the screen edge, curving into the screen at both ends.")
        options: [
            { value: "edge", label: I18n.tr("Edge"), icon: "\u{f1513}" },
            { value: "floating", label: I18n.tr("Floating"), icon: "\u{f0e5a}" },
            { value: "frame", label: I18n.tr("Frame"), icon: "\u{f05af}" }
        ]
        value: Theme.barStyle
        onChosen: v => Config.set("barStyle", v)
    }

    Section {
        title: I18n.tr("Show in the bar")

        Toggle {
            label: I18n.tr("Workspaces")
            checked: Config.barWorkspaces
            onToggled: on => Config.set("barWorkspaces", on)
        }

        Toggle {
            label: I18n.tr("Window title")
            description: Theme.barVertical ? I18n.tr("Not shown while the bar is along a side.") : ""
            checked: Config.barTitle
            onToggled: on => Config.set("barTitle", on)
        }

        Toggle {
            label: I18n.tr("Clock")
            checked: Config.barClock
            onToggled: on => Config.set("barClock", on)
        }

        Toggle {
            label: I18n.tr("System monitor")
            description: I18n.tr("CPU and memory; opens the monitor panel (also Mod+M).")
            checked: Config.barStats
            onToggled: on => Config.set("barStats", on)
        }

        Toggle {
            label: I18n.tr("Tray")
            checked: Config.barTray
            onToggled: on => Config.set("barTray", on)
        }

        Toggle {
            label: I18n.tr("Battery")
            description: I18n.tr("Only on laptops; opens the battery panel.")
            checked: Config.barBattery
            onToggled: on => Config.set("barBattery", on)
        }

        Toggle {
            label: I18n.tr("Network, Bluetooth and volume")
            description: I18n.tr("Opens the quick panel. Without it, the quick panel still opens with gravity-shell ipc call quickPanel toggle.")
            checked: Config.barStatus
            onToggled: on => Config.set("barStatus", on)
        }
    }
}
