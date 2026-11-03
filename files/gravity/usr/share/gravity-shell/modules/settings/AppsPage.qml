import QtQuick
import qs.services

// Blur behind the shell and apps, and which toolkits and apps take the shell's colours.
Column {
    id: root

    required property var settings

    spacing: 22

    // See-through surfaces with niri's blur behind them; off makes everything solid again.
    Section {
        title: "Blur"

        Toggle {
            label: "Blur"
            description: "The bar, panels and cards turn see-through with the wallpaper blurred behind them, and so do Ghostty, Zen and (with their colours on) GTK apps and Vesktop. niri blurs the wallpaper once and shares it, so it costs little. New Ghostty windows take it, GTK apps and Zen when they restart, Vesktop once it has quit."
            checked: Config.blur
            onToggled: on => Config.set("blur", on)
        }

        Toggle {
            enabled: Config.blur
            label: "Blur windows too"
            description: "Blurs whatever is behind, other windows included, rather than only the wallpaper. Uses more power: niri redraws the blur whenever something behind moves."
            checked: Config.blurWindows
            onToggled: on => Config.set("blurWindows", on)
        }

        Slider {
            enabled: Config.blur
            label: "Blur strength"
            description: "How soft the blur behind the see-through surfaces is. The tick marks niri's default."
            value: Config.blurStrength
            defaultValue: Config.defaults.blurStrength
            onCommitted: v => Config.set("blurStrength", Math.round(v * 100) / 100)
        }
    }

    // Which apps take the shell's colours; off returns each to its own.
    Section {
        title: "Toolkit colours"

        Toggle {
            label: "GTK"
            description: "GNOME and GTK apps, Flatpaks too, get the whole palette, and the nearest GNOME accent for the rest. Open apps take it when they restart."
            checked: Config.themeGtk
            onToggled: on => Config.set("themeGtk", on)
        }

        Toggle {
            label: "Qt & KDE"
            description: "Qt apps get the whole palette through qt6ct, KDE apps through their colour scheme. Open apps take it when they restart."
            checked: Config.themeQt
            onToggled: on => Config.set("themeQt", on)
        }
    }

    Section {
        title: "App colours"

        Toggle {
            label: "Ghostty"
            description: "Background, text, cursor and terminal colours. Open windows change at once."
            checked: Config.themeGhostty
            onToggled: on => Config.set("themeGhostty", on)
        }

        Toggle {
            label: "Vesktop"
            description: "A Discord theme in the whole palette. Open windows change at once; it is switched on in Vesktop's themes once Vesktop has quit."
            checked: Config.themeVesktop
            onToggled: on => Config.set("themeVesktop", on)
        }

        Toggle {
            label: "Zen Browser"
            description: "Toolbars, sidebar, tabs and menus through userChrome.css. Zen takes it when it restarts."
            checked: Config.themeZen
            onToggled: on => Config.set("themeZen", on)
        }
    }
}
