import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// System monitor, opened from the CPU/memory pill in the bar. Like the tray menus it is the
// bar growing into the screen beside its pill, flowing into the bar in a curve on each side:
// the three figures large, the last minute of CPU and memory use, every core, the
// temperatures, memory and GPU, and the busiest processes. Esc or a click outside closes.
Scope {
    id: root

    readonly property bool open: Panels.monitor !== ""
    // Keeps the window up while the card goes away after closing.
    property bool shown: false
    // Screen it is on; kept while closing, when Panels.monitor is already empty.
    property string screenName: ""

    onOpenChanged: if (open) {
        screenName = Panels.monitor;
        shown = true;
    }

    // Details are gathered only while it is open.
    Binding {
        target: SysMon
        property: "detailed"
        value: root.open
    }

    function percent(v: real): string {
        return Math.round(Math.max(0, Math.min(1, v)) * 100) + "%";
    }

    function duration(seconds: real): string {
        const m = Math.floor(seconds / 60);
        const h = Math.floor(m / 60);
        const d = Math.floor(h / 24);
        return d > 0 ? `${d} d ${h % 24} h` : h > 0 ? `${h} h ${m % 60} min` : `${m} min`;
    }

    // Cool to hot: the accent up to 70 °C, amber up to the hot mark, rose beyond.
    function tempColor(t: real): color {
        return t >= SysMon.hot ? Theme.rose : t >= 70 ? Theme.amber : Theme.glow;
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
            WlrLayershell.namespace: "gravity-monitor"
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            // Click-through while it goes away.
            mask: root.open ? null : passThrough

            Region {
                id: passThrough
            }

            // The bar's surface growing down into the panel (0 = just the bar, 1 = full
            // size), and the contents showing in it once there is room. As the quick panel.
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

            // The reverse: the contents go first, then the surface pulls back up.
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
                onClicked: Panels.closeMonitor()
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Panels.closeMonitor()
            }

            // Full height of the panel's surface; it grows rather than jumps when the
            // details come in.
            property real full: content.implicitHeight + 40

            Behavior on full {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
            }

            // Centred on the pill, kept clear of the bar's ends.
            BarSheet {
                anchors.fill: parent
                at: Panels.monitorAt
                fullWidth: 440
                fullHeight: win.full
                grow: win.grow

                Column {
                    id: content

                    x: 20
                    y: 20 - (1 - win.reveal) * 10
                    opacity: win.reveal
                    width: parent.width - 40
                    spacing: 14

                    // --- the three figures ---------------------------------------------
                    Row {
                        width: parent.width
                        spacing: 8

                        Tile {
                            icon: "\u{f061a}"
                            label: "CPU"
                            value: root.percent(SysMon.cpu)
                            detail: SysMon.cpuFreq > 0 ? (SysMon.cpuFreq / 1000).toFixed(2) + " GHz" : SysMon.cores.length + " threads"
                            level: SysMon.cpu
                            accent: Theme.gold
                        }

                        Tile {
                            icon: "\u{f050f}"
                            label: "Temp"
                            value: Math.round(SysMon.cpuTemp) + "°C"
                            detail: SysMon.cpuTemp >= SysMon.hot ? "Hot" : SysMon.cpuTemp >= 70 ? "Warm" : "Cool"
                            level: (SysMon.cpuTemp - 30) / 70
                            accent: root.tempColor(SysMon.cpuTemp)
                        }

                        Tile {
                            icon: "\u{f035b}"
                            label: "Memory"
                            value: root.percent(SysMon.mem)
                            detail: SysMon.gib(SysMon.memUsed) + " / " + Math.round(SysMon.memTotal / 1048576) + " GiB"
                            level: SysMon.mem
                            accent: Theme.glow
                        }
                    }

                    // --- the last minute -------------------------------------------------
                    Rectangle {
                        width: parent.width
                        height: 120
                        radius: 20
                        color: Theme.deep

                        Canvas {
                            id: graph

                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.topMargin: 30

                            // Repaints with each sample, while it can be seen.
                            Connections {
                                target: SysMon

                                function onCpuHistoryChanged(): void {
                                    if (root.open)
                                        graph.requestPaint();
                                }
                            }
                            Connections {
                                target: Theme

                                function onGoldChanged(): void {
                                    graph.requestPaint();
                                }
                            }

                            function line(ctx: var, data: var, colour: color): void {
                                const n = SysMon.historyLength;
                                const step = width / (n - 1);
                                const x0 = width - (data.length - 1) * step;
                                const y = v => height - Math.max(0, Math.min(1, v)) * (height - 2) - 1;
                                ctx.beginPath();
                                data.forEach((v, i) => i === 0 ? ctx.moveTo(x0, y(v)) : ctx.lineTo(x0 + i * step, y(v)));
                                ctx.strokeStyle = colour;
                                ctx.lineWidth = 2;
                                ctx.lineJoin = "round";
                                ctx.stroke();
                                // Soft fill under the line.
                                ctx.lineTo(width, height);
                                ctx.lineTo(x0, height);
                                ctx.closePath();
                                ctx.globalAlpha = 0.18;
                                ctx.fillStyle = colour;
                                ctx.fill();
                                ctx.globalAlpha = 1;
                            }

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                // Faint lines at 50% and 100%.
                                ctx.strokeStyle = Theme.text;
                                ctx.globalAlpha = 0.08;
                                ctx.lineWidth = 1;
                                for (const f of [0, 0.5]) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, Math.round(height * f) + 0.5);
                                    ctx.lineTo(width, Math.round(height * f) + 0.5);
                                    ctx.stroke();
                                }
                                ctx.globalAlpha = 1;
                                if (SysMon.memHistory.length > 1)
                                    line(ctx, SysMon.memHistory, Theme.glow);
                                if (SysMon.cpuHistory.length > 1)
                                    line(ctx, SysMon.cpuHistory, Theme.gold);
                            }
                        }

                        Row {
                            x: 14
                            y: 10
                            spacing: 14

                            Legend {
                                colour: Theme.gold
                                label: "CPU"
                            }

                            Legend {
                                colour: Theme.glow
                                label: "Memory"
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            y: 10
                            text: "Last minute"
                            color: Theme.textDim
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // --- cores -------------------------------------------------------------
                    Heading {
                        text: "Cores"
                        aside: SysMon.cpuModel
                    }

                    Row {
                        id: coreRow

                        width: parent.width
                        height: 36
                        spacing: 4

                        Repeater {
                            model: SysMon.cores.length

                            Rectangle {
                                id: core

                                required property int index
                                readonly property real level: SysMon.cores[index] ?? 0

                                width: (coreRow.width - coreRow.spacing * (SysMon.cores.length - 1)) / SysMon.cores.length
                                height: coreRow.height
                                radius: Math.min(width / 2, 6)
                                color: Qt.alpha(Theme.text, 0.08)

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(parent.radius * 2, parent.height * core.level)
                                    radius: parent.radius
                                    color: core.level > 0.9 ? Theme.rose : Theme.gold

                                    Behavior on height {
                                        NumberAnimation {
                                            duration: Theme.normal
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- temperatures ------------------------------------------------------
                    Heading {
                        visible: SysMon.temps.length > 0
                        text: "Temperatures"
                        aside: SysMon.fans.length === 0 ? "" : SysMon.fans.some(f => f.rpm > 0) ? SysMon.fans.filter(f => f.rpm > 0).map(f => f.rpm + " rpm").join(" · ") : "Fans off"
                    }

                    Flow {
                        visible: SysMon.temps.length > 0
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: SysMon.temps

                            Rectangle {
                                id: sensor

                                required property var modelData

                                width: sensorRow.implicitWidth + 24
                                height: 32
                                radius: 16
                                color: Theme.tonal

                                Row {
                                    id: sensorRow

                                    anchors.centerIn: parent
                                    spacing: 7

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: root.tempColor(sensor.modelData.temp)
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sensor.modelData.name
                                        color: Theme.tonalInk
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(sensor.modelData.temp) + "°"
                                        color: Theme.tonalInk
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }

                    // --- memory and GPU ----------------------------------------------------
                    Heading {
                        text: "Memory"
                        aside: SysMon.gib(SysMon.memAvailable) + " available"
                    }

                    // Used by programs, then cache (given back when needed), then free.
                    Item {
                        width: parent.width
                        height: 16

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Qt.alpha(Theme.text, 0.08)
                        }

                        Rectangle {
                            x: Math.max(0, used.width - 8)
                            width: SysMon.memTotal > 0 ? Math.min(parent.width - x, parent.width * SysMon.memCached / SysMon.memTotal + 8) : 0
                            height: parent.height
                            radius: 8
                            color: Theme.glow
                            opacity: 0.4
                        }

                        Rectangle {
                            id: used

                            width: Math.max(16, parent.width * SysMon.mem)
                            height: parent.height
                            radius: 8
                            color: SysMon.mem > 0.9 ? Theme.rose : Theme.glow

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.normal
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 16

                        Legend {
                            colour: Theme.glow
                            label: "Used " + SysMon.gib(SysMon.memUsed)
                        }

                        Legend {
                            colour: Qt.alpha(Theme.glow, 0.4)
                            label: "Cache " + SysMon.gib(SysMon.memCached)
                        }

                        Legend {
                            visible: SysMon.swapTotal > 0
                            colour: Qt.alpha(Theme.text, 0.3)
                            label: "Swap " + root.percent(SysMon.swap)
                        }
                    }

                    Heading {
                        visible: SysMon.gpu >= 0
                        text: "Graphics"
                        aside: SysMon.vramTotal > 0 ? SysMon.gib(SysMon.vramUsed) + " of " + SysMon.gib(SysMon.vramTotal) + " video memory" : ""
                    }

                    Bar {
                        visible: SysMon.gpu >= 0
                        level: SysMon.gpu
                        label: root.percent(SysMon.gpu)
                    }

                    // --- busiest processes -------------------------------------------------
                    Heading {
                        visible: SysMon.processes.length > 0
                        text: "Busiest"
                        aside: "% of one core"
                    }

                    Column {
                        visible: SysMon.processes.length > 0
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: SysMon.processes

                            Item {
                                id: proc

                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 15
                                    color: proc.index % 2 === 0 ? Theme.deep : "transparent"
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: procMem.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: proc.modelData.name
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    id: procMem

                                    anchors.right: procCpu.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 80
                                    horizontalAlignment: Text.AlignRight
                                    text: proc.modelData.mem >= 1048576 ? SysMon.gib(proc.modelData.mem) : Math.round(proc.modelData.mem / 1024) + " MiB"
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    id: procCpu

                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 60
                                    horizontalAlignment: Text.AlignRight
                                    text: proc.modelData.cpu.toFixed(proc.modelData.cpu < 10 ? 1 : 0) + "%"
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    // --- load and uptime ---------------------------------------------------
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: SysMon.uptime > 0
                        text: "Load " + SysMon.loadAvg.map(l => l.toFixed(2)).join("  ") + "    ·    Up " + root.duration(SysMon.uptime)
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
    // bar along the bottom.
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
                text: tile.value
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
            width: Math.min(implicitWidth, parent.width - 120)
            horizontalAlignment: Text.AlignRight
            text: heading.aside
            elide: Text.ElideLeft
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

    // A thick level bar with the value beside it.
    component Bar: Row {
        id: bar

        property real level
        property string label

        width: parent?.width ?? 0
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: bar.width - barLabel.width - bar.spacing
            height: 16
            radius: 8
            color: Qt.alpha(Theme.text, 0.08)

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, bar.level)))
                height: parent.height
                radius: parent.radius
                color: bar.level > 0.9 ? Theme.rose : Theme.gold

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: barLabel

            anchors.verticalCenter: parent.verticalCenter
            width: 44
            horizontalAlignment: Text.AlignRight
            text: bar.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }
}
