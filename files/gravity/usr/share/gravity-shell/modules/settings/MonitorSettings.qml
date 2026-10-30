import QtQuick
import qs.services

// One monitor's settings (DisplayPage): resolution and refresh rate, scale, VRR, and its
// custom modes with one more to add.
Section {
    id: monitor

    required property var output
    readonly property var prefs: Displays.settingsOf(output)
    readonly property bool on: Displays.enabled(output)
    readonly property var custom: prefs.customModes ?? []
    // The mode it is set to: one of its own ("WxH@Hz"), a custom one ("custom:<n>"),
    // or its preferred one.
    readonly property string chosen: prefs.mode && (prefs.mode.startsWith("custom:") || output.modes.some(m => Displays.modeName(m) === prefs.mode)) ? prefs.mode : ""
    readonly property var current: chosen.startsWith("custom:") ? null : output.modes.find(m => Displays.modeName(m) === chosen) ?? output.modes[output.current_mode ?? -1] ?? output.modes.find(m => m.is_preferred) ?? output.modes[0]
    readonly property string size: current ? `${current.width}x${current.height}` : ""

    width: parent?.width ?? 0
    title: `${Displays.label(output)} · ${output.name}`

    Text {
        visible: !monitor.on
        width: parent.width
        wrapMode: Text.Wrap
        text: "Off while only the " + (Displays.isInternal(monitor.output.name) ? "external monitors are" : "built-in display is") + " used."
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Choice {
        label: "Resolution"
        description: (monitor.output.physical_size ? `${Math.round(Math.hypot(...monitor.output.physical_size) / 25.4)}″ · ` : "") + "Automatic is its preferred mode."
        wrap: true
        options: {
            const sizes = [];
            for (const m of monitor.output.modes) {
                const s = `${m.width}x${m.height}`;
                if (!sizes.includes(s))
                    sizes.push(s);
            }
            return [{ value: "", label: "Automatic" }].concat(sizes.map(s => ({ value: s, label: s.replace("x", "×") })), monitor.custom.map((c, i) => ({ value: "custom:" + i, label: `${c.width}×${c.height} @ ${c.refresh} Hz`, icon: "\u{f0493}" })));
        }
        value: monitor.chosen === "" || monitor.chosen.startsWith("custom:") ? monitor.chosen : monitor.size
        onChosen: v => {
            if (v === "" || v.startsWith("custom:")) {
                Displays.setDisplayRisky(monitor.output, { mode: v });
                return;
            }
            // The highest refresh rate at that size.
            const best = monitor.output.modes.filter(m => `${m.width}x${m.height}` === v).sort((a, b) => b.refresh_rate - a.refresh_rate)[0];
            Displays.setDisplayRisky(monitor.output, { mode: Displays.modeName(best) });
        }
    }

    Choice {
        // Shown with one rate too, so it's clear what it runs at.
        visible: monitor.current !== null && options.length > 0
        label: "Refresh rate"
        wrap: true
        options: monitor.output.modes.filter(m => `${m.width}x${m.height}` === monitor.size).sort((a, b) => b.refresh_rate - a.refresh_rate).map(m => ({
                    value: Displays.modeName(m),
                    label: (m.refresh_rate % 1000 ? (m.refresh_rate / 1000).toFixed(2) : m.refresh_rate / 1000) + " Hz"
                }))
        value: monitor.current ? Displays.modeName(monitor.current) : ""
        onChosen: v => Displays.setDisplayRisky(monitor.output, { mode: v })
    }

    Choice {
        label: "Scale"
        description: monitor.output.logical ? `Now ${Math.round(monitor.output.logical.scale * 100)}%, ${monitor.output.logical.width}×${monitor.output.logical.height} to lay out windows in.` : ""
        wrap: true
        // Below 100% fits more on a small screen (a CRT at 640×480, say), drawn smaller.
        options: {
            const c = monitor.custom[Number((/^custom:(\d+)$/.exec(monitor.chosen) ?? [])[1])];
            const auto = Displays.autoScale(monitor.output, c?.width ?? monitor.current?.width ?? 0, c?.height ?? monitor.current?.height ?? 0);
            return [{ value: 0, label: `Automatic (${Math.round(auto * 100)}%)` }].concat([0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3].map(s => ({ value: s, label: Math.round(s * 100) + "%" })));
        }
        value: monitor.prefs.scale ?? 0
        onChosen: v => Displays.setDisplayRisky(monitor.output, { scale: v })
    }

    Choice {
        visible: monitor.output.vrr_supported
        label: "Variable refresh rate"
        description: "FreeSync / G-Sync / Adaptive-Sync. On demand only while a window asks for it (niri's variable-refresh-rate window rule), which avoids flicker some monitors have."
        options: [
            { value: "off", label: "Off" },
            { value: "on", label: "On" },
            { value: "on-demand", label: "On demand" }
        ]
        value: monitor.prefs.vrr ?? "off"
        onChosen: v => Displays.setDisplay(monitor.output, { vrr: v })
    }

    // Custom modes: listed (the one in use filled), and one more to add.
    Repeater {
        model: monitor.custom

        ListRow {
            required property var modelData
            required property int index

            width: parent.width
            icon: "\u{f0379}"
            selected: monitor.chosen === "custom:" + index
            title: `${modelData.width}×${modelData.height} @ ${modelData.refresh} Hz`
            subtitle: modelData.timing === "gtf" ? "GTF timings (CRT)" : modelData.timing === "modeline" ? "Modeline: " + modelData.modeline : "CVT timings"
            actions: [{ id: "remove", icon: "\u{f0a7a}" }]
            onClicked: Displays.setDisplayRisky(monitor.output, { mode: "custom:" + index })
            onActed: id => Displays.removeCustomMode(monitor.output, index)
        }
    }

    CustomMode {
        output: monitor.output
    }
}
