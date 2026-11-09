import QtQuick
import qs.services

// The music visualisers: whether the bar shows one, how they look and how smoothly they move.
Column {
    id: root

    required property var settings

    spacing: 22

    Section {
        title: I18n.tr("Visualiser")

        Toggle {
            label: I18n.tr("In the bar")
            description: I18n.tr("Beside the clock while a media player is open; opens the media panel.")
            checked: Config.barMedia
            onToggled: on => Config.set("barMedia", on)
        }
    }

    Choice {
        label: I18n.tr("Style")
        description: I18n.tr("For the visualisers in the bar and the media panel.")
        options: [
            { value: "bars", label: I18n.tr("Bars"), icon: "\u{f0128}" },
            { value: "wave", label: I18n.tr("Wave"), icon: "\u{f095b}" },
            { value: "dots", label: I18n.tr("Dots"), icon: "\u{f15fc}" }
        ]
        value: Config.visualizerStyle
        onChosen: v => Config.set("visualizerStyle", v)
    }

    Choice {
        label: I18n.tr("Visualiser frame rate")
        description: I18n.tr("Frames a second for the visualisers in the bar and the media panel. Higher is smoother and uses a little more CPU.")
        options: [
            { value: 30, label: "30" },
            { value: 60, label: "60" },
            { value: 90, label: "90" },
            { value: 120, label: "120" },
            { value: 144, label: "144" },
            { value: 165, label: "165" },
            { value: 240, label: "240" }
        ]
        value: Config.cavaFps
        onChosen: v => Config.set("cavaFps", v)
    }
}
