pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations. Text in the shell is written in English as I18n.tr("Charging"); a language
// file, i18n/<code>.json, maps each English text to its translation. Text missing from it
// stays English, so a language can be filled in bit by bit (i18n/check.py lists what is
// missing). Values go in as %1, %2, ... so a language can put them in its own order:
//     I18n.tr("Charging, full in %1", time)
// and I18n.trn() picks singular or plural, with %n for the number:
//     I18n.trn("%n cycle", "%n cycles", count)
// The language follows the system (LANGUAGE, LC_ALL, LC_MESSAGES, LANG) unless `language`
// is set in the config; changing either applies at once.
Singleton {
    id: root

    // Languages there is a file for, besides English, with their own names for the picker.
    readonly property var languages: [
        { code: "en", name: "English" },
        { code: "nl", name: "Nederlands" }
    ]

    // The system's language, e.g. "nl" from LANG=nl_NL.UTF-8.
    readonly property string systemLocale: {
        const env = (Quickshell.env("LANGUAGE") || "").split(":")[0] || Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        return env.replace(/[.@].*$/, "");
    }
    readonly property string wanted: Config.language !== "" ? Config.language : systemLocale.split(/[_-]/)[0]
    // The language in use: the wanted one when there is a file for it, else English.
    readonly property string code: languages.some(l => l.code === wanted) ? wanted : "en"

    // For dates, times and numbers: the system's own locale when it is in this language
    // (so its region still counts), else the language's.
    readonly property var locale: systemLocale.split(/[_-]/)[0] === code && systemLocale !== "" ? Qt.locale(systemLocale) : Qt.locale(code === "en" ? "en_GB" : code)

    // English text -> translation.
    property var table: ({})

    onCodeChanged: if (code === "en")
        table = {}

    FileView {
        path: root.code === "en" ? "" : Quickshell.shellPath("i18n/" + root.code + ".json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.table = JSON.parse(text());
            } catch (e) {
                console.warn("gravity: could not read", path, e);
                root.table = {};
            }
        }
        onLoadFailed: root.table = {}
    }

    function fill(text, args) {
        return text.replace(/%(\d+)/g, (m, i) => i >= 1 && i <= args.length ? String(args[i - 1]) : m);
    }

    // The translation of `text`, with %1, %2, ... filled in from the other arguments.
    function tr(text, ...args) {
        const t = root.table[text];
        return fill(typeof t === "string" && t !== "" ? t : text, args);
    }

    // `one` for 1, `other` for any other number (English and Dutch need no more), with %n
    // the number and %1, %2, ... the other arguments.
    function trn(one, other, n, ...args) {
        return tr(n === 1 ? one : other, ...args).replace(/%n/g, String(n));
    }

    // Dates and times in the language, as Qt.formatDateTime with the same format strings.
    function date(d, format) {
        return d.toLocaleString(locale, format);
    }
}
