import QtQuick
import Quickshell.Io
import Quickshell.Networking
import qs.services

// Wi-Fi on or off, the network you're on with its addresses (from nmcli), every network in
// range (scanned while the page is open): click one to join it, asking for its password in
// place, or forget a saved one. And joining a hidden network by name.
Column {
    id: root

    required property var settings

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool on: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property var networks: device?.networks.values ?? []
    readonly property var connected: networks.find(n => n.connected) ?? null
    // Known first, then by signal.
    readonly property var others: networks.filter(n => !n.connected).sort((a, b) => (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // The network asking for a password, and why it asks again.
    property var passwordFor: null
    property string passwordError: ""

    spacing: 22

    Binding {
        target: root.device
        property: "scannerEnabled"
        value: true
        when: root.device !== null && root.on && root.visible
    }

    function icon(n: var): string {
        const level = Math.max(0, Math.min(3, Math.floor(n.signalStrength * 4 - 0.01)));
        return String.fromCodePoint(0xf091f + level * 3 + (secured(n) && !n.known ? 2 : 0));
    }

    function secured(n: var): bool {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function describe(n: var): string {
        if (n.stateChanging)
            return n.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…";
        const parts = [n.connected ? "Connected" : n.known ? "Saved" : secured(n) ? "Secured" : "Open"];
        parts.push(Math.round(n.signalStrength * 100) + "%");
        return parts.join(" · ");
    }

    function join(n: var): void {
        passwordError = "";
        if (n.connected) {
            n.disconnect();
        } else if (n.known || !secured(n)) {
            passwordFor = null;
            n.connect();
        } else {
            passwordFor = passwordFor === n ? null : n;
        }
    }

    Toggle {
        label: "Wi-Fi"
        description: root.device === null ? "No Wi-Fi adapter found." : !Networking.wifiHardwareEnabled ? "Switched off by a hardware switch or airplane mode." : ""
        enabled: root.device !== null && Networking.wifiHardwareEnabled
        checked: root.on
        onToggled: on => Networking.wifiEnabled = on
    }

    // --- the network you're on ------------------------------------------------------------
    Section {
        visible: root.on && root.connected !== null
        title: "Connected"

        ListRow {
            selected: true
            expanded: true
            icon: root.connected ? root.icon(root.connected) : ""
            title: root.connected?.name ?? ""
            subtitle: root.connected ? root.describe(root.connected) : ""
            actions: [{ id: "disconnect", icon: "\u{f05aa}" }, { id: "forget", icon: "\u{f09e7}" }]
            onActed: id => id === "forget" ? root.connected.forget() : root.connected.disconnect()

            // Addresses, two to a line.
            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 6
                columnSpacing: 16

                Repeater {
                    model: details.rows

                    Column {
                        required property var modelData

                        width: (parent.width - 16) / 2

                        Text {
                            text: modelData.label
                            color: Qt.alpha(Theme.goldInk, 0.7)
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Text {
                            width: parent.width
                            text: modelData.value
                            elide: Text.ElideRight
                            color: Theme.goldInk
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    // IP details of the Wi-Fi interface, read again whenever the connection changes.
    Process {
        id: details

        property var rows: []

        function refresh(): void {
            running = false;
            if (root.connected !== null && root.device !== null && root.visible)
                running = true;
        }

        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR", "device", "show", root.device?.name ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i < 0)
                        continue;
                    const key = line.slice(0, i).replace(/\[\d+\]$/, "");
                    const value = line.slice(i + 1).replace(/\\:/g, ":");
                    if (value !== "" && !found[key])
                        found[key] = value;
                }
                const labels = { "IP4.ADDRESS": "IPv4 address", "IP4.GATEWAY": "Gateway", "IP4.DNS": "DNS", "IP6.ADDRESS": "IPv6 address", "GENERAL.HWADDR": "Hardware address" };
                details.rows = Object.keys(labels).filter(k => found[k]).map(k => ({ label: labels[k], value: found[k] }));
            }
        }
    }

    onConnectedChanged: details.refresh()
    onVisibleChanged: details.refresh()
    Component.onCompleted: details.refresh()

    // --- everything else in range -----------------------------------------------------------
    Section {
        visible: root.on
        title: root.others.length > 0 ? "Networks" : "Looking for networks…"

        Repeater {
            model: root.others

            ListRow {
                id: net

                required property var modelData

                icon: root.icon(modelData)
                title: modelData.name
                subtitle: root.describe(modelData)
                actions: modelData.known ? [{ id: "forget", icon: "\u{f09e7}" }] : []
                expanded: root.passwordFor === modelData
                onClicked: root.join(modelData)
                onActed: modelData.forget()

                Field {
                    id: psk

                    password: true
                    placeholder: "Password, then Enter"
                    error: net.expanded ? root.passwordError : ""
                    onAccepted: t => {
                        if (t.length < 8)
                            return;
                        root.passwordError = "";
                        root.passwordFor = null;
                        net.modelData.connectWithPsk(t);
                    }
                }

                onExpandedChanged: if (expanded)
                    psk.input.forceActiveFocus()

                // A wrong password asks again.
                Connections {
                    target: net.modelData

                    function onConnectionFailed(reason: int): void {
                        if (net.modelData.known)
                            return;
                        root.passwordFor = net.modelData;
                        root.passwordError = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed || reason === ConnectionFailReason.WifiAuthTimeout ? "Wrong password, try again." : "Could not connect.";
                    }
                }
            }
        }
    }

    // --- hidden networks --------------------------------------------------------------------
    Section {
        id: hidden

        property bool open: false
        property string error

        visible: root.on
        title: "Hidden network"

        PillButton {
            visible: !hidden.open
            icon: "\u{f0415}"
            label: "Join a hidden network"
            onClicked: {
                hidden.open = true;
                ssid.input.forceActiveFocus();
            }
        }

        Field {
            id: ssid

            visible: hidden.open
            placeholder: "Network name"
        }

        Field {
            id: hiddenPsk

            visible: hidden.open
            password: true
            placeholder: "Password (empty for an open network)"
            error: hidden.error
            onAccepted: if (ssid.input.text !== "")
                joinHidden.start()
        }

        Row {
            visible: hidden.open
            spacing: 8

            PillButton {
                accent: true
                label: joinHidden.running ? "Joining…" : "Join"
                enabled: ssid.input.text !== "" && !joinHidden.running
                onClicked: joinHidden.start()
            }

            PillButton {
                label: "Cancel"
                onClicked: {
                    hidden.open = false;
                    hidden.error = "";
                    ssid.input.text = "";
                    hiddenPsk.input.text = "";
                }
            }
        }

        Process {
            id: joinHidden

            function start(): void {
                if (running)
                    return;
                hidden.error = "";
                const cmd = ["nmcli", "device", "wifi", "connect", ssid.input.text, "hidden", "yes"];
                if (hiddenPsk.input.text !== "")
                    cmd.push("password", hiddenPsk.input.text);
                command = cmd;
                running = true;
            }

            stderr: StdioCollector {
                id: hiddenErr
            }
            onExited: code => {
                if (code === 0) {
                    hidden.open = false;
                    ssid.input.text = "";
                    hiddenPsk.input.text = "";
                } else {
                    hidden.error = hiddenErr.text.trim().replace(/^Error: /, "") || "Could not connect.";
                }
            }
        }
    }
}
