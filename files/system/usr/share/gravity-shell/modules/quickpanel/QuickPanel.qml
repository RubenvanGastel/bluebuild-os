import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.components
import qs.services

// Quick panel, opened from the volume/battery pill at the far end of the bar (or
// `gravity-shell ipc call quickPanel toggle`). The bar grows into it there (at the right,
// or the bottom along a side), joined to it, with the battery state, Wi-Fi and Bluetooth,
// volume (and output device) and brightness sliders, light or dark mode (Appearance) and
// the power profile. Click outside it or press Esc to close.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: (battery?.isLaptopBattery ?? false) && (battery?.isPresent ?? false)
    readonly property real batteryLevel: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging

    readonly property bool open: Panels.quick !== ""
    // `shown` keeps the window up while the card goes away after the panel closes.
    property bool shown: false
    // Screen it is on; kept while closing, when Panels.quick is already empty.
    property string screenName: ""

    PwObjectTracker {
        objects: [root.sink]
    }

    // Audio outputs (hardware and network speakers, not app streams).
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // Which list in the panel is unfolded: "output", "wifi", "bluetooth" or "" (none).
    property string expanded: ""

    function nodeName(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || "";
    }

    onOpenChanged: if (open) {
        screenName = Panels.quick;
        shown = true;
        expanded = "";
        Brightness.reload();
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function duration(seconds: real): string {
        const m = Math.round(seconds / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h} h ${m % 60} min` : `${m} min`;
    }

    readonly property string batteryText: {
        switch (battery?.state) {
        case UPowerDeviceState.Charging:
            return battery.timeToFull > 0 ? "Charging, full in " + duration(battery.timeToFull) : "Charging";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Plugged in, not charging";
        case UPowerDeviceState.Discharging:
            return battery.timeToEmpty > 0 ? duration(battery.timeToEmpty) + " left" : "On battery";
        default:
            return "";
        }
    }

    // Nerd Font glyphs (Symbols Nerd Font, installed with the image).
    readonly property string batteryIcon: {
        if (charging)
            return "\u{f0084}";
        if (!UPower.onBattery)
            return "\u{f06a5}";
        const tenths = Math.round(batteryLevel * 10);
        return tenths >= 10 ? "\u{f0079}" : tenths <= 0 ? "\u{f0083}" : String.fromCodePoint(0xf007a + tenths - 1);
    }
    readonly property string volumeIcon: muted || volume <= 0.001 ? "\u{f075f}" : volume < 0.34 ? "\u{f057f}" : volume < 0.67 ? "\u{f0580}" : "\u{f057e}"
    readonly property string brightnessIcon: Brightness.level < 0.34 ? "\u{f00de}" : Brightness.level < 0.67 ? "\u{f00df}" : "\u{f00e0}"

    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, label: "Saver", icon: "\u{f032a}" },
        { value: PowerProfile.Balanced, label: "Balanced", icon: "\u{f05d1}" },
        { value: PowerProfile.Performance, label: "Performance", icon: "\u{f04c5}" }
    ].filter(p => p.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gravity-quick-panel"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Click-through while it goes away.
            mask: root.open ? null : passThrough

            Region {
                id: passThrough
            }

            // Notifications move down below the panel while it is open.
            Binding {
                target: Panels
                property: "quickHeight"
                value: Theme.barEdge === "top" ? sheet.full : 0
                when: root.open
            }

            // The bar's surface growing down into the panel (0 = just the bar, 1 = full
            // size), and the controls showing in it once there is room.
            property real grow: 0
            property real reveal: 0

            Component.onCompleted: enter.start()

            Connections {
                target: root

                function onOpenChanged(): void {
                    if (root.open) {
                        leave.stop();
                        enter.start();
                    } else {
                        enter.stop();
                        leave.start();
                    }
                }
            }

            ParallelAnimation {
                id: enter

                NumberAnimation {
                    target: win
                    property: "grow"
                    to: 1
                    duration: 420
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 140
                    }
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // The reverse: the controls go first, then the bar pulls back up.
            SequentialAnimation {
                id: leave

                ParallelAnimation {
                    NumberAnimation {
                        target: win
                        property: "reveal"
                        to: 0
                        duration: 120
                        easing.type: Easing.InQuad
                    }
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 60
                        }
                        NumberAnimation {
                            target: win
                            property: "grow"
                            to: 0
                            duration: 280
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.depart
                        }
                    }
                }
                ScriptAction {
                    script: root.shown = false
                }
            }

            // Click anywhere else to close.
            MouseArea {
                anchors.fill: parent
                onClicked: Panels.closeQuick()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.closeQuick()
            }

            // The panel is the bar itself growing into the screen at its far end (the right,
            // or the bottom along a side): same colour, no seam, and the curve at the bar's
            // end rides along on its outer edge.
            BarSheet {
                id: sheet

                // Full height of the panel's surface.
                property real full: content.implicitHeight + 40

                // Changes in size grow rather than jump; the output list animates
                // itself, so then it follows directly.
                Behavior on full {
                    enabled: !outputList.moving && !connectivity.moving

                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.emphasized
                    }
                }

                anchors.fill: parent
                align: "barEnd"
                fullWidth: 400
                fullHeight: full
                grow: win.grow

                Column {
                    id: content

                    x: 20
                    y: 20 - (1 - win.reveal) * 10
                    opacity: win.reveal
                    width: parent.width - 40
                    spacing: 14

                    // --- battery, and the cog for the settings ----------------------------
                    Item {
                        width: parent.width
                        height: Math.max(battery.height, 40)

                        Row {
                            id: battery

                            visible: root.hasBattery
                            spacing: 14

                            Badge {
                                icon: root.batteryIcon
                                accent: root.charging || root.batteryLevel >= 0.15
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: Math.round(root.batteryLevel * 100) + "%"
                                    color: root.batteryLevel < 0.15 && !root.charging ? Theme.rose : Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }

                                Text {
                                    visible: text !== ""
                                    text: root.batteryText
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            radius: 20
                            color: cogMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u{f0493}"
                                color: Theme.tonalInk
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 20
                                rotation: cogMouse.containsMouse ? 60 : 0

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            MouseArea {
                                id: cogMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Panels.openSettings("")
                            }
                        }
                    }

                    // --- Wi-Fi and Bluetooth ------------------------------------------
                    Connectivity {
                        id: connectivity

                        panel: root
                    }

                    // --- audio output ----------------------------------------------
                    // The current one; click to choose another.
                    Column {
                        visible: root.sinks.length > 1
                        width: parent.width

                        Rectangle {
                            width: parent.width
                            height: 44
                            radius: 22
                            color: outputMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }

                            Text {
                                id: outputIcon

                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u{f04c3}"
                                color: Theme.tonalInk
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                            }

                            Text {
                                anchors.left: outputIcon.right
                                anchors.leftMargin: 10
                                anchors.right: chevron.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.nodeName(root.sink)
                                elide: Text.ElideRight
                                color: Theme.tonalInk
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                id: chevron

                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u{f0140}"
                                rotation: root.expanded === "output" ? 180 : 0
                                color: Theme.tonalInk
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            MouseArea {
                                id: outputMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expanded = root.expanded === "output" ? "" : "output"
                            }
                        }

                        // The list unfolds out of the selector.
                        Unfold {
                            id: outputList

                            open: root.expanded === "output"
                            count: root.sinks.length

                            Repeater {
                                model: root.sinks

                                Rectangle {
                                    id: output

                                    required property PwNode modelData
                                    required property int index
                                    readonly property bool selected: modelData === root.sink
                                    readonly property real p: outputList.share(index)

                                    opacity: p
                                    transform: Translate {
                                        y: (1 - output.p) * -10
                                    }

                                    width: parent.width
                                    height: 40
                                    radius: selected ? 14 : 20
                                    color: selected ? Theme.gold : outputItemMouse.containsMouse ? Theme.tonal : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.fast
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: check.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.nodeName(output.modelData)
                                        elide: Text.ElideRight
                                        color: output.selected ? Theme.goldInk : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: output.selected ? Font.Bold : Font.Medium
                                    }

                                    Text {
                                        id: check

                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: output.selected
                                        text: "\u{f012c}"
                                        color: Theme.goldInk
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: outputItemMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Pipewire.preferredDefaultAudioSink = output.modelData;
                                            root.expanded = "";
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- sliders ------------------------------------------------------
                    SliderRow {
                        visible: root.sink !== null
                        icon: root.volumeIcon
                        value: root.volume
                        dimmed: root.muted
                        label: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
                        iconClickable: true
                        armed: win.reveal > 0.2
                        onIconClicked: if (root.sink?.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                        onMoved: v => root.setVolume(v)
                    }

                    SliderRow {
                        visible: Brightness.available
                        icon: root.brightnessIcon
                        value: Brightness.level
                        label: Math.round(Brightness.level * 100) + "%"
                        armed: win.reveal > 0.55
                        onMoved: v => Brightness.setLevel(v)
                    }

                    // --- light / dark -------------------------------------------------
                    Text {
                        topPadding: 4
                        // Says who decides while it's automatic.
                        text: !Appearance.automatic ? "Appearance" : Appearance.mode === "wallpaper" ? "Appearance · automatic, by the wallpaper" : !Appearance.hasLocation ? "Appearance · automatic, set a place in the settings" : Appearance.nextChange ? "Appearance · automatic, " + (Appearance.sunUp ? "dark at sunset " : "light at sunrise ") + Qt.formatTime(Appearance.nextChange, Config.use24h ? "HH:mm" : "h:mm AP") : "Appearance · automatic, by the sun"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    // Greyed out while it's automatic; choosing one goes back to manual.
                    Row {
                        id: appearanceRow

                        width: parent.width
                        spacing: 6
                        opacity: Appearance.automatic ? 0.45 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.normal
                            }
                        }

                        Repeater {
                            model: [
                                { light: true, label: "Light", icon: "\u{f0599}" },
                                { light: false, label: "Dark", icon: "\u{f0594}" }
                            ]

                            Rectangle {
                                id: appearance

                                required property var modelData
                                readonly property bool selected: Appearance.light === modelData.light

                                width: (appearanceRow.width - appearanceRow.spacing) / 2
                                height: 48
                                radius: selected ? 14 : height / 2
                                color: selected ? Theme.gold : appearanceMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

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

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appearance.modelData.icon
                                        color: appearance.selected ? Theme.goldInk : Theme.tonalInk
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: appearance.modelData.label
                                        color: appearance.selected ? Theme.goldInk : Theme.tonalInk
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    id: appearanceMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Appearance.choose(appearance.modelData.light)
                                }
                            }
                        }
                    }

                    // --- power profile ------------------------------------------------
                    Text {
                        topPadding: 4
                        text: "Power mode"
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    Row {
                        id: profileRow

                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.profiles

                            Rectangle {
                                id: profile

                                required property var modelData
                                readonly property bool selected: PowerProfiles.profile === modelData.value

                                width: (profileRow.width - profileRow.spacing * (root.profiles.length - 1)) / root.profiles.length
                                height: 48
                                // The chosen one squares off a little, like an M3 Expressive
                                // button group.
                                radius: selected ? 14 : height / 2
                                color: selected ? Theme.gold : profileMouse.containsMouse ? Theme.hover(Theme.tonal, 1.25) : Theme.tonal

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

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profile.modelData.icon
                                        color: profile.selected ? Theme.goldInk : Theme.tonalInk
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profile.modelData.label
                                        color: profile.selected ? Theme.goldInk : Theme.tonalInk
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    id: profileMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PowerProfiles.profile = profile.modelData.value
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Icon in an accent circle; tonal when not accented.
    component Badge: Rectangle {
        id: badge

        property string icon
        property bool accent: true

        // A little pop when the icon or its accent changes (e.g. a volume step, muting).
        onIconChanged: pop.restart()
        onAccentChanged: pop.restart()

        SequentialAnimation {
            id: pop

            NumberAnimation {
                target: badge
                property: "scale"
                to: 1.14
                duration: 90
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: badge
                property: "scale"
                to: 1
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }

        width: 44
        height: 44
        radius: 22
        color: accent ? Theme.gold : Theme.tonal

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Text {
            anchors.centerIn: parent
            text: badge.icon
            color: badge.accent ? Theme.goldInk : Theme.tonalInk
            font.family: "Symbols Nerd Font"
            font.pixelSize: 20
        }
    }

    // Icon, M3 Expressive slider (thick track split by a handle) and value. `moved` gives
    // the new level (0..1) while dragging, clicking or scrolling.
    //
    // It moves on a spring: the handle chases the level with a little overshoot and leans
    // the way it is going, the track swells under the pointer, and once `armed` it fills
    // up from empty (as the panel opens).
    component SliderRow: Row {
        id: row

        property string icon
        property real value
        property string label
        property bool dimmed: false
        property bool iconClickable: false
        property bool armed: true

        signal moved(real v)
        signal iconClicked

        width: parent?.width ?? 0
        spacing: 12

        Badge {
            id: badge

            icon: row.icon
            accent: !row.dimmed

            MouseArea {
                anchors.fill: parent
                enabled: row.iconClickable
                cursorShape: Qt.PointingHandCursor
                onClicked: row.iconClicked()
            }
        }

        Item {
            id: slider

            // While dragging, the pointer's own position: the real level (e.g. PipeWire's
            // volume) only comes back a moment later.
            readonly property real f: drag.dragging ? drag.level : row.armed ? Math.max(0, Math.min(1, row.value)) : 0
            readonly property bool engaged: drag.pressed || drag.containsMouse

            // The level as drawn: springs after `f`, except while dragging, when the handle
            // stays right under the pointer.
            property real shown: f

            Behavior on shown {
                enabled: !drag.dragging

                SpringAnimation {
                    spring: 3.5
                    damping: 0.28
                    epsilon: 0.0005
                }
            }

            width: row.width - badge.width - valueText.width - row.spacing * 2
            height: 44

            readonly property real trackHeight: drag.pressed ? 22 : engaged ? 19 : 16

            // Filled part, up to the handle.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, handle.x - 4)
                height: slider.trackHeight
                radius: height / 2
                color: row.dimmed ? Theme.textDim : Theme.gold

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }

            // The rest, after the handle.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: handle.x + handle.width + 4
                width: Math.max(0, slider.width - x)
                height: slider.trackHeight
                radius: height / 2
                color: Theme.tonal

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }
                }
            }

            Rectangle {
                id: handle

                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(1, slider.shown)) * (slider.width - width)
                width: drag.pressed ? 7 : 5
                height: drag.pressed ? 40 : slider.engaged ? 35 : 30
                radius: width / 2
                color: row.dimmed ? Theme.textDim : Theme.gold
                // Leans into the way it is moving: the further it lags behind the
                // level, the more; it straightens (and wobbles past) as it settles.
                rotation: Math.max(-22, Math.min(22, (slider.f - slider.shown) * 160))

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.fast
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.5
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.normal
                    }
                }
            }

            MouseArea {
                id: drag

                // Pointer level, and whether it has moved since the press (a plain click
                // still springs the handle over).
                property real level: 0
                property bool dragging: false

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function at(mx: real): void {
                    level = Math.max(0, Math.min(1, mx / width));
                    row.moved(level);
                }

                onPressed: mouse => at(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) {
                        dragging = true;
                        at(mouse.x);
                    }
                }
                onReleased: dragging = false
                onCanceled: dragging = false
                onWheel: wheel => row.moved(Math.max(0, Math.min(1, row.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }

        Text {
            id: valueText

            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: row.label
            color: row.dimmed ? Theme.textDim : Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
            // A touch bigger while the slider is held.
            scale: drag.pressed ? 1.12 : 1
            transformOrigin: Item.Right

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }
            }
        }
    }
}
