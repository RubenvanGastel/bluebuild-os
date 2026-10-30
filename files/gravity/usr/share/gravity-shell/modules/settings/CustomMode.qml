import QtQuick
import qs.services

// Adding a custom mode to one monitor: its size and refresh rate, with the timings niri
// works out (CVT) or GTF ones (what CRTs expect), or a modeline of your own (from the
// monitor's manual, or a tool) that sets all three. The timings and the horizontal
// frequency they need are shown before it is tried.
Column {
    id: root

    required property var output

    property string timing: "cvt"
    property string widthText
    property string heightText
    property string refreshText
    property string modelineText

    readonly property int w: Number(widthText)
    readonly property int h: Number(heightText)
    readonly property real hz: Number(refreshText)
    readonly property bool sizeValid: Number.isInteger(w) && Number.isInteger(h) && w >= 320 && h >= 200 && w <= 8192 && h <= 8192 && hz >= 20 && hz <= 500
    readonly property var parsed: timing === "modeline" ? Displays.parseModeline(modelineText) : timing === "gtf" && sizeValid ? Displays.parseModeline(Displays.gtf(w, h, hz)) : null
    readonly property bool valid: timing === "modeline" ? parsed !== null : sizeValid

    width: parent?.width ?? 0
    spacing: 10

    Column {
        width: parent.width
        spacing: 2

        Text {
            text: "Add a custom mode"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "A mode the monitor doesn't list. Out of its range it may stay dark (this goes back by itself) or, with a CRT, be damaged: keep within the horizontal and vertical frequencies its manual gives."
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Choice {
        options: [
            { value: "cvt", label: "Standard (CVT)" },
            { value: "gtf", label: "CRT (GTF)" },
            { value: "modeline", label: "Modeline" }
        ]
        value: root.timing
        onChosen: v => root.timing = v
    }

    Row {
        visible: root.timing !== "modeline"
        width: parent.width
        spacing: 8

        Field {
            width: (parent.width - 2 * parent.spacing) / 3
            placeholder: "Width, e.g. 640"
            text: root.widthText
            onAccepted: t => root.widthText = t.trim()
        }

        Field {
            width: (parent.width - 2 * parent.spacing) / 3
            placeholder: "Height, e.g. 480"
            text: root.heightText
            onAccepted: t => root.heightText = t.trim()
        }

        Field {
            width: (parent.width - 2 * parent.spacing) / 3
            placeholder: "Hz, e.g. 60"
            text: root.refreshText
            onAccepted: t => root.refreshText = t.trim().replace(",", ".")
        }
    }

    Field {
        visible: root.timing === "modeline"
        placeholder: "clock hdisp hsyncstart hsyncend htotal vdisp vsyncstart vsyncend vtotal ±hsync ±vsync"
        text: root.modelineText
        error: root.modelineText !== "" && root.parsed === null ? "Nine numbers, each sync after the one before it, then +hsync or -hsync and +vsync or -vsync." : ""
        onAccepted: t => root.modelineText = t.trim()
    }

    // What it comes to.
    Text {
        visible: text !== ""
        width: parent.width
        wrapMode: Text.WrapAnywhere
        text: {
            const p = root.parsed;
            if (!p)
                return root.timing === "cvt" && root.sizeValid ? "niri works out CVT timings for it." : "";
            const n = p.numbers;
            const hfreq = n[0] * 1000 / n[4], vfreq = n[0] * 1e6 / (n[4] * n[8]);
            return `${n[1]}×${n[5]} at ${vfreq.toFixed(2)} Hz, ${hfreq.toFixed(2)} kHz horizontal, ${n[0]} MHz pixel clock\n${n.join(" ")} ${p.hsync} ${p.vsync}`;
        }
        color: Theme.gold
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    PillButton {
        enabled: root.valid
        opacity: enabled ? 1 : 0.5
        accent: true
        icon: "\u{f0415}"
        label: "Add and try"
        onClicked: {
            const p = root.parsed;
            const mode = root.timing === "modeline" ? {
                width: p.numbers[1],
                height: p.numbers[5],
                refresh: Number((p.numbers[0] * 1e6 / (p.numbers[4] * p.numbers[8])).toFixed(3)),
                timing: "modeline",
                modeline: `${p.numbers.join(" ")} ${p.hsync} ${p.vsync}`
            } : {
                width: root.w,
                height: root.h,
                refresh: root.hz,
                timing: root.timing,
                modeline: ""
            };
            Displays.addCustomMode(root.output, mode);
            root.widthText = root.heightText = root.refreshText = root.modelineText = "";
        }
    }
}
