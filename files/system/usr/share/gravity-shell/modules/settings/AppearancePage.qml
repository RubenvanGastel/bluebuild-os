import QtQuick
import Quickshell
import qs.services

// Light or dark, the colours (the default, an accent colour or the wallpaper's, and
// matugen's scheme), and the wallpaper and its folder.
Column {
    id: root

    // The settings card, which closes for the wallpaper picker.
    required property var settings

    spacing: 22

    // Light or dark by hand, or picked by the wallpaper's brightness or the sun.
    Column {
        width: parent.width
        spacing: 12

        Choice {
            label: "Mode"
            description: "For the shell and every app: GNOME apps, GTK 3 apps, browsers and Flatpaks."
            options: [
                { value: true, label: "Light", icon: "\u{f0599}" },
                { value: false, label: "Dark", icon: "\u{f0594}" },
                { value: "wallpaper", label: "Wallpaper", icon: "\u{f0fc1}" },
                { value: "sun", label: "Sunrise & sunset", icon: "\u{f059a}" }
            ]
            value: Appearance.automatic ? Appearance.mode : Appearance.light
            onChosen: v => typeof v === "boolean" ? Appearance.choose(v) : Appearance.setMode(v)
        }

        Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: {
                const time = d => Qt.formatTime(d, Config.use24h ? "HH:mm" : "h:mm AP");
                if (Appearance.mode === "wallpaper")
                    return Appearance.wallpaperBrightness < 0 ? "Measuring the wallpaper…" : `The wallpaper is ${Math.round(Appearance.wallpaperBrightness * 100)}% bright, so it's ${Appearance.wallpaperBrightness > Appearance.brightThreshold ? "light" : "dark"}. Light above ${Math.round(Appearance.brightThreshold * 100)}%.`;
                if (Appearance.mode !== "sun")
                    return "";
                if (!Appearance.hasLocation)
                    return "Set your location below to follow the sun.";
                if (!Appearance.sunrise)
                    return Appearance.sunUp ? "The sun doesn't set today, so it stays light." : "The sun doesn't rise today, so it stays dark.";
                return `Sunrise ${time(Appearance.sunrise)}, sunset ${time(Appearance.sunset)}` + (Appearance.nextChange ? `: ${Appearance.sunUp ? "dark" : "light"} from ${time(Appearance.nextChange)}.` : ".");
            }
            color: Theme.gold
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Location {
            visible: Appearance.mode === "sun"
            width: parent.width
        }
    }

    Choice {
        label: "Colours"
        description: Theme.error !== "" && Config.colors !== "default" ? Theme.error + ", so the default colours are used." : "A whole palette is made from one colour, or picked from your wallpaper. GNOME apps take the nearest of their accents."
        options: [
            { value: "default", label: "Default", icon: "\u{f03d8}" },
            { value: "accent", label: "Accent colour", icon: "\u{f0266}" },
            { value: "wallpaper", label: "From wallpaper", icon: "\u{f02e9}" }
        ]
        value: Config.colors
        onChosen: v => Config.setColors(v)
    }

    // The accent: GNOME's colours as swatches, or any other.
    Column {
        visible: Config.colors === "accent"
        width: parent.width
        spacing: 12

        Flow {
            width: parent.width
            spacing: 10

            Repeater {
                model: Theme.accents

                Rectangle {
                    id: swatch

                    required property var modelData
                    readonly property bool selected: Config.accent === modelData.value

                    width: 44
                    height: 44
                    // The chosen one squares off a little, like the other choices.
                    radius: selected ? 14 : 22
                    color: modelData.value
                    border.width: selected ? 3 : 0
                    border.color: Theme.text
                    scale: swatchMouse.pressed ? 0.9 : swatchMouse.containsMouse ? 1.08 : 1

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Easing.OutBack
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.fast
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: swatch.selected
                        text: "\u{f012c}"
                        color: "white"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: swatchMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setAccent(swatch.modelData.value)
                    }
                }
            }
        }

        Field {
            id: hex

            placeholder: "Your own colour, e.g. #ff6f61"
            text: Theme.accents.some(a => a.value === Config.accent) ? "" : Config.accent
            error: input.text !== "" && !/^#?[0-9a-fA-F]{6}$/.test(input.text.trim()) ? "A colour is six hex digits, like #ff6f61." : ""
            onAccepted: t => {
                if (/^#?[0-9a-fA-F]{6}$/.test(t.trim()))
                    Config.setAccent(t);
            }
        }
    }

    Choice {
        visible: Config.colors !== "default"
        label: "Scheme"
        description: Config.colors === "accent" ? "How the palette is made from the colour." : "How the colours are taken from the wallpaper."
        wrap: true
        options: Theme.schemes.map(s => ({ value: s.id, label: s.label }))
        value: Config.colorScheme
        onChosen: v => Config.setColorScheme(v)
    }

    Section {
        title: "Wallpaper"

        Row {
            spacing: 8

            PillButton {
                accent: true
                icon: "\u{f02e9}"
                label: "Choose wallpaper"
                onClicked: {
                    root.settings.close();
                    Quickshell.execDetached(["gravity-shell", "wallpaper"]);
                }
            }
        }

        Field {
            label: "Wallpaper folder"
            description: "The picker lists the images and videos in it."
            placeholder: "Wallpapers in your Pictures folder"
            text: Config.wallpaperDir
            onAccepted: t => Config.set("wallpaperDir", t.trim())
        }
    }
}
