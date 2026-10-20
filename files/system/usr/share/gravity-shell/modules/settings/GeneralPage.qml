import QtQuick
import qs.services

// When the screen locks by itself, and how the clock reads.
Column {
    id: root

    required property var settings

    spacing: 22

    Choice {
        label: "Lock when idle"
        description: "The screen locks after this long without input."
        options: [
            { value: 0, label: "Never" },
            { value: 5, label: "5 min" },
            { value: 10, label: "10 min" },
            { value: 15, label: "15 min" },
            { value: 30, label: "30 min" }
        ]
        value: Config.idleLockMinutes
        onChosen: v => Config.set("idleLockMinutes", v)
    }

    Section {
        title: "Clock"

        Toggle {
            label: "24-hour time"
            checked: Config.use24h
            onToggled: on => Config.set("use24h", on)
        }

        Toggle {
            label: "Date in the bar"
            checked: Config.showDate
            onToggled: on => Config.set("showDate", on)
        }
    }
}
