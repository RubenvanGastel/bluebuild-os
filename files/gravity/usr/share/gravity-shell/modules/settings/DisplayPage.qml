import QtQuick
import qs.services

// The monitors (services/Displays.qml): how they are used together, where they stand, and
// for the monitor picked (MonitorSettings) its resolution and refresh rate, scale, VRR and custom modes (for CRTs, with
// GTF timings or a modeline of your own). Mode, scale and how they are used are tried
// first: they go back after a while unless kept (DisplayConfirm asks, on every screen).
Column {
    id: root

    required property var settings

    // Connector of the monitor whose settings are shown; the built-in one at first.
    property string selected
    readonly property var shown: Displays.list.find(o => o.name === selected) ?? Displays.list[0] ?? null

    spacing: 22

    Choice {
        visible: Displays.both
        label: "Use"
        description: Displays.mode === "mirror" && !Displays.hasMirror ? "Mirroring needs wl-mirror, which isn't installed; the monitors extend meanwhile." : "Remembered for these monitors together. Monitors connected for the first time extend the desktop."
        wrap: true
        options: [
            { value: "extend", label: "Extend", icon: "\u{f037a}" },
            { value: "mirror", label: "Mirror", icon: "\u{f11fd}" },
            { value: "internal", label: "Only built-in", icon: "\u{f0322}" },
            { value: "external", label: "Only external", icon: "\u{f0379}" }
        ]
        value: Displays.mode
        onChosen: v => Displays.setMode(v)
    }

    Text {
        visible: !Displays.both
        width: parent.width
        wrapMode: Text.Wrap
        text: Displays.list.length === 0 ? "No monitors found." : "Connect another monitor to extend or mirror; it starts in its preferred mode, next to this one."
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Column {
        visible: Displays.mode === "extend" && arrangement.rects.length > 1
        width: parent.width
        spacing: 8

        Text {
            text: "Arrangement"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Drag the monitors to where they stand; the pointer moves between them where they touch. Click one for its settings."
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Arrangement {
            id: arrangement

            selected: root.shown?.name ?? ""
            anchor: root.settings.targetScreen?.name ?? ""
            onPicked: name => root.selected = name
        }
    }

    // Its settings: picked here or by clicking it in the arrangement.
    Choice {
        visible: Displays.list.length > 1
        label: "Monitor"
        wrap: true
        options: Displays.list.map(o => ({ value: o.name, label: Displays.label(o), icon: Displays.isInternal(o.name) ? "\u{f0322}" : "\u{f0379}" }))
        value: root.shown?.name ?? ""
        onChosen: v => root.selected = v
    }

    MonitorSettings {
        visible: root.shown !== null
        output: root.shown ?? ({ name: "", modes: [] })
    }

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "HDR isn't available: niri doesn't support it yet."
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}
