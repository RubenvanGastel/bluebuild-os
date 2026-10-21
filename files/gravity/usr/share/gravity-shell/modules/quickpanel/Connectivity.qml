import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.services

// Wi-Fi and Bluetooth in the quick panel: a tile for each, accent-filled while on. The
// round icon switches it on or off; the rest of the tile unfolds its list underneath
// (networks to join, devices to connect or pair), which also starts a scan while open.
// Clicking an entry connects to it, or disconnects when it is the connected one; a
// secured network that isn't known yet asks for its password in place.
Column {
    id: root

    // The quick panel, for which of its lists is unfolded (`expanded`).
    required property var panel

    readonly property bool moving: wifiList.moving || btList.moving

    width: parent?.width ?? 0

    // --- Wi-Fi --------------------------------------------------------------------------
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property var wifiNetworks: wifiDevice?.networks.values ?? []
    readonly property var wifiConnected: wifiNetworks.find(n => n.connected) ?? null
    // Connected first, then known ones, then by signal; at most eight.
    readonly property var wifiShown: wifiNetworks.slice().sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)).slice(0, 8)

    // The network asking for a password, and why it asks again (a failed attempt).
    property var passwordFor: null
    property string passwordError: ""

    // Scan while the list is open.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: true
        when: root.wifiDevice !== null && root.panel.expanded === "wifi" && root.wifiOn
    }

    function wifiIcon(n: var): string {
        // wifi-strength-1..4, with a lock when it needs a password first.
        const level = Math.max(0, Math.min(3, Math.floor(n.signalStrength * 4 - 0.01)));
        const locked = !n.known && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
        return String.fromCodePoint(0xf091f + level * 3 + (locked ? 2 : 0));
    }

    function joinWifi(n: var): void {
        passwordError = "";
        if (n.connected) {
            n.disconnect();
        } else if (n.known || n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe) {
            passwordFor = null;
            n.connect();
        } else {
            passwordFor = passwordFor === n ? null : n;
        }
    }

    // --- Bluetooth --------------------------------------------------------------------
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter?.enabled ?? false
    readonly property var btDevices: adapter?.devices.values ?? []
    readonly property var btConnected: btDevices.filter(d => d.connected)
    // Connected, then paired, then new ones found nearby that have a real name; at most
    // eight.
    readonly property var btShown: btDevices.filter(d => d.paired || d.connected || (d.name !== "" && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name))).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).slice(0, 8)

    // Devices being paired from here: connect once pairing is done.
    property var pairing: []

    Binding {
        target: root.adapter
        property: "discovering"
        value: true
        when: root.adapter !== null && root.panel.expanded === "bluetooth" && root.btOn
    }

    function btIcon(icon: string): string {
        if (/headset|headphone/.test(icon))
            return "\u{f02cb}";
        if (/audio|speaker/.test(icon))
            return "\u{f04c3}";
        if (/keyboard/.test(icon))
            return "\u{f030c}";
        if (/mouse/.test(icon))
            return "\u{f037d}";
        if (/gaming|joystick/.test(icon))
            return "\u{f0297}";
        if (/phone/.test(icon))
            return "\u{f011c}";
        if (/computer/.test(icon))
            return "\u{f0322}";
        return "\u{f00af}";
    }

    function joinBt(d: var): void {
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            d.connect();
        } else {
            d.trusted = true;
            pairing = [...pairing, d];
            d.pair();
        }
    }

    function btState(d: var): string {
        if (d.pairing)
            return "Pairing…";
        switch (d.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        }
        return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "";
    }

    // --- tiles --------------------------------------------------------------------------
    Row {
        id: tiles

        width: parent.width
        spacing: 8

        Tile {
            width: (tiles.width - tiles.spacing) / 2
            panel: root.panel
            list: "wifi"
            active: root.wifiOn
            available: root.wifiDevice !== null && Networking.wifiHardwareEnabled
            icon: !root.wifiOn ? "\u{f05aa}" : root.wifiConnected ? String.fromCodePoint(0xf091f + Math.max(0, Math.min(3, Math.floor(root.wifiConnected.signalStrength * 4 - 0.01))) * 3) : "\u{f092f}"
            label: "Wi-Fi"
            status: root.wifiDevice === null ? "Unavailable" : !Networking.wifiHardwareEnabled ? "Blocked" : !Networking.wifiEnabled ? "Off" : root.wifiConnected?.name ?? "Not connected"
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        Tile {
            width: (tiles.width - tiles.spacing) / 2
            panel: root.panel
            list: "bluetooth"
            active: root.btOn
            available: root.adapter !== null && root.adapter.state !== BluetoothAdapterState.Blocked
            icon: !root.btOn ? "\u{f00b2}" : root.btConnected.length > 0 ? "\u{f00b1}" : "\u{f00af}"
            label: "Bluetooth"
            status: root.adapter === null ? "Unavailable" : root.adapter.state === BluetoothAdapterState.Blocked ? "Blocked" : !root.btOn ? "Off" : root.btConnected.length === 1 ? root.btConnected[0].name : root.btConnected.length > 1 ? root.btConnected.length + " devices" : "On"
            onToggled: root.adapter.enabled = !root.adapter.enabled
        }
    }

    // --- Wi-Fi networks -------------------------------------------------------------------
    Unfold {
        id: wifiList

        open: root.panel.expanded === "wifi" && root.wifiOn
        count: root.wifiShown.length + 1

        Repeater {
            model: root.wifiShown

            Entry {
                id: net

                required property var modelData

                list: wifiList
                selected: modelData.connected
                icon: root.wifiIcon(modelData)
                label: modelData.name
                note: modelData.stateChanging ? (modelData.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…") : ""
                // Known networks can be forgotten.
                action: modelData.known && !modelData.connected ? "\u{f09e7}" : ""
                asking: root.passwordFor === modelData
                error: asking ? root.passwordError : ""
                onClicked: root.joinWifi(modelData)
                onActed: modelData.forget()
                onPassword: psk => {
                    root.passwordError = "";
                    root.passwordFor = null;
                    modelData.connectWithPsk(psk);
                }
                onCancelled: root.passwordFor = null

                // A wrong password asks again.
                Connections {
                    target: net.modelData

                    function onConnectionFailed(reason: int): void {
                        if (net.modelData.known)
                            return;
                        root.passwordFor = net.modelData;
                        root.passwordError = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed || reason === ConnectionFailReason.WifiAuthTimeout ? "Wrong password" : "Could not connect";
                    }
                }
            }
        }

        Searching {
            list: wifiList
            index: root.wifiShown.length
            text: root.wifiShown.length === 0 ? "Looking for networks…" : "Looking for more…"
        }
    }

    // --- Bluetooth devices ----------------------------------------------------------------
    Unfold {
        id: btList

        open: root.panel.expanded === "bluetooth" && root.btOn
        count: root.btShown.length + 1

        Repeater {
            model: root.btShown

            Entry {
                id: dev

                required property var modelData

                list: btList
                selected: modelData.connected
                icon: root.btIcon(modelData.icon)
                label: modelData.name
                note: root.btState(modelData)
                // Paired devices can be forgotten.
                action: modelData.paired && !modelData.connected ? "\u{f09e7}" : ""
                onClicked: root.joinBt(modelData)
                onActed: modelData.forget()

                // Paired from here: connect straight away.
                Connections {
                    target: dev.modelData

                    function onPairedChanged(): void {
                        if (dev.modelData.paired && root.pairing.includes(dev.modelData)) {
                            root.pairing = root.pairing.filter(d => d !== dev.modelData);
                            dev.modelData.connect();
                        }
                    }
                }
            }
        }

        Searching {
            list: btList
            index: root.btShown.length
            text: root.btShown.length === 0 ? "Looking for devices…" : "Looking for more…"
        }
    }

    // The tile for Wi-Fi or Bluetooth. The icon is a switch; the rest unfolds the list.
    component Tile: Rectangle {
        id: tile

        required property var panel
        required property string list
        property bool active: false
        property bool available: true
        property string icon
        property string label
        property string status

        signal toggled

        readonly property bool open: panel.expanded === list && active

        height: 64
        // Squares off a little while on, like an M3 Expressive toggle button.
        radius: active ? 20 : height / 2
        color: active ? Theme.gold : bodyMouse.containsMouse && available ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal
        opacity: available ? 1 : 0.5

        Behavior on radius {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Easing.OutBack
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        // Opens the list; while off, switches it on first.
        MouseArea {
            id: bodyMouse

            anchors.fill: parent
            enabled: tile.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!tile.active)
                    tile.toggled();
                tile.panel.expanded = tile.open ? "" : tile.list;
            }
        }

        // The switch.
        Rectangle {
            id: knob

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            color: tile.active ? (knobMouse.containsMouse ? Qt.alpha(Theme.goldInk, 0.22) : Qt.alpha(Theme.goldInk, 0.12)) : (knobMouse.containsMouse ? Theme.hover(Theme.dusk, 1.3) : Theme.dusk)
            scale: knobMouse.pressed ? 0.9 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Easing.OutBack
                    easing.overshoot: 3
                }
            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Theme.goldInk : Theme.tonalInk
                font.family: "Symbols Nerd Font"
                font.pixelSize: 20
            }

            MouseArea {
                id: knobMouse

                anchors.fill: parent
                enabled: tile.available
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.toggled()
            }
        }

        Column {
            anchors.left: knob.right
            anchors.leftMargin: 10
            anchors.right: chevron.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: tile.label
                elide: Text.ElideRight
                color: tile.active ? Theme.goldInk : Theme.tonalInk
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: tile.status
                elide: Text.ElideRight
                color: tile.active ? Qt.alpha(Theme.goldInk, 0.75) : Theme.textDim
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0140}"
            rotation: tile.open ? 180 : 0
            color: tile.active ? Theme.goldInk : Theme.tonalInk
            font.family: "Symbols Nerd Font"
            font.pixelSize: 18

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    // A network or device in a list: accent-filled when connected, with what it is doing
    // (or its battery) at the right and, on hover, a button for `action` (forget). When
    // `asking`, a password field opens under it.
    component Entry: Rectangle {
        id: entry

        required property Unfold list
        required property int index
        property bool selected: false
        property string icon
        property string label
        property string note
        property string action
        property bool asking: false
        property string error

        signal clicked
        signal acted
        signal password(string psk)
        signal cancelled

        readonly property real p: list.share(index)

        opacity: p
        transform: Translate {
            y: (1 - entry.p) * -10
        }

        width: parent?.width ?? 0
        height: 40 + (asking ? 48 : 0)
        radius: selected ? 14 : 20
        color: selected ? Theme.gold : entryMouse.containsMouse || asking ? Theme.tonal : "transparent"
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.emphasized
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        onAskingChanged: if (asking)
            field.text = ""

        MouseArea {
            id: entryMouse

            width: parent.width
            height: 40
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.clicked()
        }

        Text {
            id: entryIcon

            x: 14
            y: 20 - height / 2
            text: entry.icon
            color: entry.selected ? Theme.goldInk : Theme.text
            font.family: "Symbols Nerd Font"
            font.pixelSize: 17
        }

        Text {
            anchors.left: entryIcon.right
            anchors.leftMargin: 10
            anchors.right: trailing.left
            anchors.rightMargin: 10
            y: 20 - height / 2
            text: entry.label
            elide: Text.ElideRight
            color: entry.selected ? Theme.goldInk : Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: entry.selected ? Font.Bold : Font.Medium
        }

        // State, the forget button on hover, or a check when connected.
        Row {
            id: trailing

            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 20 - height / 2
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: entry.note
                color: entry.selected ? Qt.alpha(Theme.goldInk, 0.75) : Theme.textDim
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.action !== "" && (entryMouse.containsMouse || actionMouse.containsMouse)
                width: 28
                height: 28
                radius: 14
                color: actionMouse.containsMouse ? Theme.hover(Theme.tonal, 1.4) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: entry.action
                    color: actionMouse.containsMouse ? Theme.rose : Theme.textDim
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                }

                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.acted()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.selected
                text: "\u{f012c}"
                color: Theme.goldInk
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
            }
        }

        // Password, under the network's name. Enter connects, Esc gives up.
        Rectangle {
            x: 8
            y: 44
            width: parent.width - 16
            height: 36
            radius: 18
            visible: entry.asking
            color: Theme.surface
            border.width: entry.error !== "" ? 2 : field.activeFocus ? 2 : 0
            border.color: entry.error !== "" ? Theme.rose : Theme.gold

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: hint.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.text
                selectionColor: Theme.gold
                selectedTextColor: Theme.goldInk
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Medium
                clip: true
                focus: entry.asking
                onVisibleChanged: if (visible)
                    forceActiveFocus()
                Keys.onReturnPressed: if (text.length >= 8)
                    entry.password(text)
                Keys.onEnterPressed: if (text.length >= 8)
                    entry.password(text)
                Keys.onEscapePressed: entry.cancelled()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: entry.error !== "" ? entry.error + ", try again" : "Password"
                    color: entry.error !== "" ? Theme.rose : Theme.textDim
                    font: field.font
                }
            }

            Text {
                id: hint

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter"
                opacity: field.text.length >= 8 ? 1 : 0.4
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }

    // The last row of a list while it scans: a softly pulsing dot and a note.
    component Searching: Item {
        id: searching

        required property Unfold list
        required property int index
        property string text

        readonly property real p: list.share(index)

        opacity: p
        width: parent?.width ?? 0
        height: 32

        Row {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.gold

                SequentialAnimation on opacity {
                    running: searching.list.open
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.25
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: searching.text
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
