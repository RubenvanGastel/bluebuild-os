import QtQuick
import qs.services

// The language, when the screen locks by itself, and how the clock reads.
Column {
    id: root

    required property var settings

    spacing: 22

    Choice {
        label: I18n.tr("Language")
        description: I18n.tr("For the shell. System follows the language of your account.")
        // Each language in its own name, so you can find yours whatever is set now.
        options: [{ value: "", label: I18n.tr("System") }].concat(I18n.languages.map(l => ({ value: l.code, label: l.name })))
        value: Config.language
        onChosen: v => Config.set("language", v)
    }

    Choice {
        label: I18n.tr("Lock when idle")
        description: I18n.tr("The screen locks after this long without input.")
        options: [
            { value: 0, label: I18n.tr("Never") },
            { value: 5, label: I18n.tr("5 min") },
            { value: 10, label: I18n.tr("10 min") },
            { value: 15, label: I18n.tr("15 min") },
            { value: 30, label: I18n.tr("30 min") }
        ]
        value: Config.idleLockMinutes
        onChosen: v => Config.set("idleLockMinutes", v)
    }

    Section {
        title: I18n.tr("Clock")

        Toggle {
            label: I18n.tr("24-hour time")
            checked: Config.use24h
            onToggled: on => Config.set("use24h", on)
        }

        Toggle {
            label: I18n.tr("Date in the bar")
            checked: Config.showDate
            onToggled: on => Config.set("showDate", on)
        }
    }
}
