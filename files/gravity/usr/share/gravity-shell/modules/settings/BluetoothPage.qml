import QtQuick
import Quickshell.Bluetooth
import qs.services

// Bluetooth on or off and visible to others, your paired devices (click to connect or
// disconnect; the cog unfolds renaming, trusting and forgetting one) and the devices nearby
// (searched for while the page is open; click to pair and connect).
Column {
    id: root

    required property var settings

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    // Connected first, then by name.
    readonly property var paired: devices.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // New ones with a real name (not just their address).
    readonly property var nearby: devices.filter(d => !d.paired && !d.connected && d.name !== "" && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name)).sort((a, b) => a.name.localeCompare(b.name))

    // The device whose settings are unfolded.
    property var editing: null
    // Devices being paired from here: connect once pairing is done.
    property var pairing: []

    spacing: 22

    Binding {
        target: root.adapter
        property: "discovering"
        value: true
        when: root.adapter !== null && root.on && root.visible
    }

    function icon(name: string): string {
        if (/headset|headphone/.test(name))
            return "\u{f02cb}";
        if (/audio|speaker/.test(name))
            return "\u{f04c3}";
        if (/keyboard/.test(name))
            return "\u{f030c}";
        if (/mouse/.test(name))
            return "\u{f037d}";
        if (/gaming|joystick/.test(name))
            return "\u{f0297}";
        if (/phone/.test(name))
            return "\u{f011c}";
        if (/computer/.test(name))
            return "\u{f0322}";
        return "\u{f00af}";
    }

    function describe(d: var): string {
        if (d.pairing)
            return I18n.tr("Pairing…");
        switch (d.state) {
        case BluetoothDeviceState.Connecting:
            return I18n.tr("Connecting…");
        case BluetoothDeviceState.Disconnecting:
            return I18n.tr("Disconnecting…");
        }
        const parts = [d.connected ? I18n.tr("Connected") : d.paired ? I18n.tr("Paired") : I18n.tr("Not paired")];
        if (d.batteryAvailable)
            parts.push(I18n.tr("%1% battery", Math.round(d.battery * 100)));
        return parts.join(" · ");
    }

    function pair(d: var): void {
        d.trusted = true;
        pairing = [...pairing, d];
        d.pair();
    }

    Toggle {
        label: "Bluetooth"
        description: root.adapter === null ? I18n.tr("No Bluetooth adapter found.") : root.adapter.state === BluetoothAdapterState.Blocked ? I18n.tr("Switched off by a hardware switch or airplane mode.") : ""
        enabled: root.adapter !== null && root.adapter.state !== BluetoothAdapterState.Blocked
        checked: root.on
        onToggled: on => root.adapter.enabled = on
    }

    Toggle {
        visible: root.on
        label: I18n.tr("Visible to other devices")
        description: I18n.tr("Shows up as “%1” so a phone or another computer can pair with it.", root.adapter?.name ?? "")
        checked: root.adapter?.discoverable ?? false
        onToggled: on => root.adapter.discoverable = on
    }

    // --- paired -----------------------------------------------------------------------------
    Section {
        visible: root.on && root.paired.length > 0
        title: I18n.tr("Your devices")

        Repeater {
            model: root.paired

            ListRow {
                id: dev

                required property var modelData

                selected: modelData.connected
                expanded: root.editing === modelData
                icon: root.icon(modelData.icon)
                title: modelData.name
                subtitle: root.describe(modelData)
                actions: [{ id: "settings", icon: "\u{f0493}" }]
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                onActed: root.editing = root.editing === modelData ? null : modelData

                Column {
                    width: parent.width
                    spacing: 8

                    Field {
                        placeholder: I18n.tr("Name")
                        text: dev.modelData.name
                        onAccepted: t => {
                            if (t.trim() !== "")
                                dev.modelData.name = t.trim();
                        }
                    }

                    Toggle {
                        label: I18n.tr("Trusted")
                        description: I18n.tr("Connects by itself, without asking.")
                        checked: dev.modelData.trusted
                        onToggled: on => dev.modelData.trusted = on
                    }

                    PillButton {
                        danger: true
                        icon: "\u{f09e7}"
                        label: I18n.tr("Forget")
                        onClicked: {
                            root.editing = null;
                            dev.modelData.forget();
                        }
                    }
                }
            }
        }
    }

    // --- nearby ------------------------------------------------------------------------------
    Section {
        visible: root.on
        title: root.nearby.length > 0 ? I18n.tr("Nearby") : I18n.tr("Looking for devices…")

        Repeater {
            model: root.nearby

            ListRow {
                id: found

                required property var modelData

                icon: root.icon(modelData.icon)
                title: modelData.name
                subtitle: root.describe(modelData)
                onClicked: if (!modelData.pairing)
                    root.pair(modelData)
            }
        }
    }

    // Paired from here: connect straight away.
    Repeater {
        model: root.pairing

        Item {
            required property var modelData

            Connections {
                target: modelData

                function onPairedChanged(): void {
                    if (!modelData.paired)
                        return;
                    root.pairing = root.pairing.filter(d => d !== modelData);
                    modelData.connect();
                }
            }
        }
    }
}
