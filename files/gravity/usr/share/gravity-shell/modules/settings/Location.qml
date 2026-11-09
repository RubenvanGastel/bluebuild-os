import QtQuick
import Quickshell.Io
import qs.services

// Where you are, for sunrise and sunset (and later the weather): type a place, Enter, and
// pick it from Open-Meteo's place search (only what you type is sent). Its name and
// coordinates are kept in the config.
Column {
    id: root

    // Places found: [{ name, detail, latitude, longitude }].
    property var results: []
    property string error

    spacing: 8

    function search(text: string): void {
        const q = text.trim();
        error = "";
        results = [];
        if (q === "" || lookup.running)
            return;
        lookup.command = ["curl", "-sf", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search", "--data-urlencode", "name=" + q, "-d", "count=6", "-d", "language=" + I18n.code, "-d", "format=json"];
        lookup.running = true;
    }

    Field {
        id: field

        label: I18n.tr("Location")
        description: Config.locationName !== "" ? I18n.tr("Now %1. Search for another place to change it.", Config.locationName) : I18n.tr("Search for your city, then pick it.")
        placeholder: lookup.running ? I18n.tr("Searching…") : I18n.tr("City, then Enter")
        error: root.error
        onAccepted: t => root.search(t)
    }

    Repeater {
        model: root.results

        ListRow {
            required property var modelData

            icon: "\u{f034e}"
            title: modelData.name
            subtitle: modelData.detail
            onClicked: {
                Config.setLocation([modelData.name, modelData.detail].filter(s => s).join(", "), modelData.latitude, modelData.longitude);
                field.input.text = "";
                // Last: this destroys the row this handler belongs to.
                root.results = [];
            }
        }
    }

    Process {
        id: lookup

        stdout: StdioCollector {
            id: found
        }
        onExited: code => {
            if (code !== 0) {
                root.error = I18n.tr("Could not reach the place search; are you online?");
                return;
            }
            let places = [];
            try {
                places = JSON.parse(found.text).results ?? [];
            } catch (e) {}
            root.results = places.map(p => ({
                        name: p.name,
                        detail: [p.admin1, p.country].filter(s => s && s !== p.name).join(", "),
                        latitude: p.latitude,
                        longitude: p.longitude
                    }));
            if (root.results.length === 0)
                root.error = I18n.tr("No place by that name.");
        }
    }
}
