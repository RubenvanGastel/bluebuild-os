import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.components
import qs.services

// Battery panel, opened from the battery pill in the bar. Like the system monitor it is the
// bar growing into the screen beside its pill: the level large with a thick bar, the power
// going in or out, the energy left, the battery's health, the charge over the last 12 hours
// (UPower's own history, so it reaches back before login), the power mode and what the
// battery is. Esc or a click outside closes.
Scope {
    id: root

    readonly property bool open: Panels.battery !== ""
    // Keeps the window up while the card goes away after closing.
    property bool shown: false
    // Screen it is on; kept while closing, when Panels.battery is already empty.
    property string screenName: ""

    onOpenChanged: if (open) {
        screenName = Panels.battery;
        shown = true;
        history.running = true;
        info.running = true;
    }

    // The combined battery (level, state, rate) and the laptop's own battery (health,
    // model, and where it is in /sys).
    readonly property var dev: UPower.displayDevice
    readonly property var cell: UPower.devices.values.find(d => d.isLaptopBattery) ?? null

    readonly property real level: dev?.percentage ?? 0
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool plugged: charging || !UPower.onBattery
    readonly property bool low: level < 0.15 && !plugged
    readonly property real rate: Math.abs(dev?.changeRate ?? 0)

    // From /sys/class/power_supply (info): cycles, chemistry, maker and charging mode.
    property var sys: ({})
    // From UPower when it knows, else full capacity against the design capacity.
    readonly property real health: cell?.healthSupported ? cell.healthPercentage / 100 : sys.energy_full > 0 && sys.energy_full_design > 0 ? sys.energy_full / sys.energy_full_design : -1

    // Charge history: [{ t (unix seconds), v (0..1), charging }], oldest first.
    property var points: []
    readonly property real span: 12 * 3600

    readonly property string stateText: {
        switch (dev?.state) {
        case UPowerDeviceState.Charging:
            return dev.timeToFull > 0 ? "Charging, full in " + duration(dev.timeToFull) : "Charging";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Plugged in, not charging";
        case UPowerDeviceState.Discharging:
            return dev.timeToEmpty > 0 ? duration(dev.timeToEmpty) + " left" : "On battery";
        default:
            return "";
        }
    }

    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, label: "Saver", icon: "\u{f032a}" },
        { value: PowerProfile.Balanced, label: "Balanced", icon: "\u{f05d1}" },
        { value: PowerProfile.Performance, label: "Performance", icon: "\u{f04c5}" }
    ].filter(p => p.value !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    function duration(seconds: real): string {
        const m = Math.round(seconds / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h} h ${m % 60} min` : `${m} min`;
    }

    function levelColor(): color {
        return root.low ? Theme.rose : root.charging ? Theme.gold : Theme.glow;
    }

    // UPower keeps a charge history per battery in /var/lib/upower, named after its model:
    // "<time>\t<percent>\t<state>" lines, written as the level changes.
    Process {
        id: history

        command: ["sh", "-c", `
            f=$(ls -t /var/lib/upower/history-charge-"$1"*.dat 2>/dev/null | head -n 1)
            [ -n "$f" ] && tail -n 600 "$f"
        `, "sh", root.cell?.model ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const pts = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 3 || f[2] === "unknown")
                        continue;
                    pts.push({ t: parseInt(f[0]), v: parseFloat(f[1].replace(",", ".")) / 100, charging: f[2] === "charging" });
                }
                pts.sort((a, b) => a.t - b.t);
                root.points = pts;
            }
        }
    }

    Process {
        id: info

        command: ["sh", "-c", `
            cd /sys/class/power_supply/"$1" 2>/dev/null || exit 0
            for f in cycle_count technology manufacturer model_name charge_types energy_full energy_full_design; do
                printf '%s\\t%s\\n' "$f" "$(cat "$f" 2>/dev/null)"
            done
        `, "sh", root.cell?.nativePath ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const sys = {};
                for (const line of text.split("\n")) {
                    const [key, value] = line.split("\t");
                    if (key && value)
                        sys[key] = /^\d+$/.test(value) ? parseInt(value) : value;
                }
                root.sys = sys;
            }
        }
    }

    // UPower writes a point every few minutes; keep up while it is open.
    Timer {
        interval: 60000
        repeat: true
        running: root.open
        onTriggered: history.running = true
    }

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
            WlrLayershell.namespace: "gravity-battery"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Click-through while it goes away.
            mask: root.open ? null : passThrough

            Region {
                id: passThrough
            }

            // The bar's surface growing into the panel, and the contents showing in it once
            // there is room. As the system monitor.
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

            // The reverse: the contents go first, then the surface pulls back.
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
                acceptedButtons: Qt.AllButtons
                onClicked: Panels.closeBattery()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.closeBattery()
            }

            // Centred on the pill, kept clear of the bar's ends.
            BarSheet {
                anchors.fill: parent
                at: Panels.batteryAt
                fullWidth: 440
                fullHeight: content.implicitHeight + 40
                grow: win.grow

                Column {
                    id: content

                    x: 20
                    y: 20 - (1 - win.reveal) * 10
                    opacity: win.reveal
                    width: parent.width - 40
                    spacing: 14

                    // --- the level -----------------------------------------------------
                    Item {
                        width: parent.width
                        height: levelText.height

                        Text {
                            id: levelText

                            text: Math.round(root.level * 100) + "%"
                            color: root.low ? Theme.rose : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 44
                            font.weight: Font.Bold
                        }

                        Column {
                            anchors.left: levelText.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 6
                                visible: root.plugged

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u{f140b}"
                                    color: root.charging ? Theme.gold : Theme.textDim
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Plugged in"
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.stateText
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // A thick bar of the level, with a sheen running along it while it
                    // charges.
                    Rectangle {
                        width: parent.width
                        height: 22
                        radius: 11
                        color: Qt.alpha(Theme.text, 0.08)
                        clip: true

                        Rectangle {
                            id: fill

                            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.level)) * win.reveal)
                            height: parent.height
                            radius: parent.radius
                            color: root.levelColor()
                            clip: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.normal
                                }
                            }

                            Rectangle {
                                visible: root.charging
                                width: 60
                                height: parent.height
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 0.5
                                        color: Qt.alpha("white", 0.35)
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "transparent"
                                    }
                                }

                                NumberAnimation on x {
                                    from: -60
                                    to: fill.width
                                    duration: 1600
                                    loops: Animation.Infinite
                                    running: root.charging && root.open
                                }
                            }
                        }
                    }

                    // --- the three figures ---------------------------------------------
                    Row {
                        width: parent.width
                        spacing: 8

                        Tile {
                            icon: root.charging ? "\u{f140b}" : "\u{f06a5}"
                            label: root.charging ? "Charging" : "Using"
                            value: root.rate > 0 ? root.rate.toFixed(1) + " W" : "–"
                            detail: root.rate <= 0 ? "Idle" : root.charging ? "Into the battery" : "From the battery"
                            level: root.rate / 65
                            accent: root.charging ? Theme.gold : Theme.glow
                        }

                        Tile {
                            icon: "\u{f0079}"
                            label: "Energy"
                            value: (root.dev?.energy ?? 0).toFixed(1) + " Wh"
                            detail: "of " + (root.dev?.energyCapacity ?? 0).toFixed(1) + " Wh"
                            level: root.level
                            accent: root.levelColor()
                        }

                        Tile {
                            icon: "\u{f02d1}"
                            label: "Health"
                            value: root.health >= 0 ? Math.round(root.health * 100) + "%" : "–"
                            detail: root.sys.cycle_count > 0 ? root.sys.cycle_count + " cycles" : "Of its new capacity"
                            level: root.health
                            accent: root.health >= 0 && root.health < 0.7 ? Theme.amber : Theme.glow
                        }
                    }

                    // --- the last 12 hours -----------------------------------------------
                    Rectangle {
                        visible: root.points.length > 0
                        width: parent.width
                        height: 140
                        radius: 20
                        color: Theme.deep

                        Canvas {
                            id: graph

                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.topMargin: 32
                            anchors.bottomMargin: 26

                            Connections {
                                target: root

                                function onPointsChanged(): void {
                                    graph.requestPaint();
                                }
                                function onLevelChanged(): void {
                                    graph.requestPaint();
                                }
                            }
                            Connections {
                                target: Theme

                                function onGoldChanged(): void {
                                    graph.requestPaint();
                                }
                            }

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const now = Date.now() / 1000;
                                const t0 = now - root.span;
                                const x = t => Math.max(0, (t - t0) / root.span * width);
                                const y = v => height - Math.max(0, Math.min(1, v)) * (height - 2) - 1;

                                // Faint lines at 0, 50% and 100%.
                                ctx.strokeStyle = Theme.text;
                                ctx.globalAlpha = 0.08;
                                ctx.lineWidth = 1;
                                for (const f of [0, 0.5, 1]) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, Math.round(y(f)) + 0.5);
                                    ctx.lineTo(width, Math.round(y(f)) + 0.5);
                                    ctx.stroke();
                                }
                                ctx.globalAlpha = 1;

                                // From the last point before the window, through to now.
                                const all = root.points;
                                let first = all.findIndex(p => p.t >= t0);
                                if (first < 0)
                                    first = all.length;
                                const pts = all.slice(Math.max(0, first - 1));
                                pts.push({ t: now, v: root.level, charging: root.charging });
                                if (pts.length < 2)
                                    return;

                                // Charging stretches shaded behind.
                                ctx.fillStyle = Theme.gold;
                                ctx.globalAlpha = 0.14;
                                for (let i = 0; i < pts.length - 1; i++) {
                                    if (pts[i].charging)
                                        ctx.fillRect(x(pts[i].t), 0, x(pts[i + 1].t) - x(pts[i].t), height);
                                }
                                ctx.globalAlpha = 1;

                                ctx.beginPath();
                                pts.forEach((p, i) => i === 0 ? ctx.moveTo(x(p.t), y(p.v)) : ctx.lineTo(x(p.t), y(p.v)));
                                ctx.strokeStyle = Theme.glow;
                                ctx.lineWidth = 2.5;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.stroke();
                                // Soft fill under the line.
                                ctx.lineTo(width, height);
                                ctx.lineTo(x(pts[0].t), height);
                                ctx.closePath();
                                ctx.globalAlpha = 0.18;
                                ctx.fillStyle = Theme.glow;
                                ctx.fill();
                                ctx.globalAlpha = 1;

                                // Now.
                                ctx.beginPath();
                                ctx.arc(width - 1, y(root.level), 4, 0, 2 * Math.PI);
                                ctx.fillStyle = root.charging ? Theme.gold : Theme.glow;
                                ctx.fill();
                            }
                        }

                        Row {
                            x: 14
                            y: 11
                            spacing: 14

                            Legend {
                                colour: Theme.glow
                                label: "Charge"
                            }

                            Legend {
                                colour: Qt.alpha(Theme.gold, 0.5)
                                label: "Charging"
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            y: 11
                            text: "Last 12 hours"
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        // Hours along the bottom.
                        Repeater {
                            model: [12, 9, 6, 3, 0]

                            Text {
                                required property int modelData
                                required property int index

                                x: 12 + (graph.width) * index / 4 - (index === 0 ? 0 : index === 4 ? width : width / 2)
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                text: modelData === 0 ? "now" : "-" + modelData + " h"
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // --- power mode --------------------------------------------------------
                    Heading {
                        text: "Power mode"
                        aside: PowerProfiles.degradationReason !== PerformanceDegradationReason.None ? "Performance held back" : ""
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

                    // --- what the battery is -----------------------------------------------
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        // e.g. "ATL L24N4PC0 · Li-poly · Fast charging"; the marked one of
                        // charge_types is the mode in use.
                        text: [[root.sys.manufacturer, root.sys.model_name].filter(s => s).join(" "), root.sys.technology, (String(root.sys.charge_types ?? "").match(/\[([^\]]+)\]/)?.[1]?.replace("_", " ") ?? "") + (root.sys.charge_types ? " charging" : "")].filter(s => s).join("    ·    ")
                        visible: text !== ""
                        color: Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // A figure in a tonal tile: icon and label, the value large, a detail line and a thin
    // bar along the bottom. As in the system monitor.
    component Tile: Rectangle {
        id: tile

        property string icon
        property string label
        property string value
        property string detail
        property real level
        property color accent

        // A third of the row.
        width: parent ? (parent.width - parent.spacing * 2) / 3 : 0
        height: 104
        radius: 20
        color: Theme.tonal

        Column {
            x: 14
            y: 12
            width: parent.width - 28
            spacing: 2

            Row {
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.icon
                    color: tile.accent
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.label
                    color: Theme.tonalInk
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Text {
                width: parent.width
                text: tile.value
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 16
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: tile.detail
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: parent.width - 28
            height: 5
            radius: 2.5
            color: Qt.alpha(Theme.text, 0.12)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, tile.level)))
                height: parent.height
                radius: parent.radius
                color: tile.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // Section title, with a dim note at the right.
    component Heading: Item {
        id: heading

        property string text
        property string aside

        width: parent?.width ?? 0
        height: 18

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: heading.text
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.aside
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    // A dot in a colour and a label.
    component Legend: Row {
        id: legend

        property color colour
        property string label

        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: legend.colour
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: legend.label
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }
}
