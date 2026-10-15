import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services

Item {
    id: card

    required property Notification notification

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    // The "default" action is what clicking the notification itself does (e.g. focus the
    // app); it has no label and is not drawn as a button. The rest are buttons.
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default" && a.text !== "")
    // Seconds; the sender's timeout if it gave one, else 6s. Critical ones stay.
    readonly property real lifetime: notification.expireTimeout > 0 ? notification.expireTimeout : 6
    property bool leaving: false
    property real bob: 0

    implicitHeight: body.implicitHeight + 28
    height: implicitHeight

    // Float in from the right with a slight tilt.
    x: 60
    opacity: 0
    rotation: 3

    Component.onCompleted: arrive.start()

    ParallelAnimation {
        id: arrive

        NumberAnimation {
            target: card
            property: "x"
            to: 0
            duration: 650
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: 260
        }
        NumberAnimation {
            target: card
            property: "rotation"
            to: 0
            duration: 900
            easing.type: Easing.OutElastic
            easing.amplitude: 1
            easing.period: 0.5
        }
    }

    // Gentle hover in place.
    SequentialAnimation on bob {
        loops: Animation.Infinite
        running: !card.leaving
        NumberAnimation {
            to: 1
            duration: 2200
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -1
            duration: 2200
            easing.type: Easing.InOutSine
        }
    }

    transform: Translate {
        y: card.bob * 2.5
    }

    // Leaving: the card is pulled off to the right, over the screen edge, with a slight
    // tilt; dismissed ones go a little quicker, as if flicked.
    function leave(dismissed: bool): void {
        if (leaving)
            return;
        leaving = true;
        fallAnim.dismissed = dismissed;
        fallAnim.start();
    }

    // An action button: slide out first and invoke at the end, since invoking removes the
    // notification at once. Resident notifications stay after an action, so they don't move.
    function invoke(action: NotificationAction): void {
        if (leaving)
            return;
        if (notification.resident) {
            action.invoke();
            return;
        }
        fallAnim.action = action;
        leave(true);
    }

    SequentialAnimation {
        id: fallAnim

        property bool dismissed: false
        property NotificationAction action: null

        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "x"
                to: card.width + 60
                duration: fallAnim.dismissed ? 340 : 480
                easing.type: Easing.InBack
                easing.overshoot: 1.2
            }
            NumberAnimation {
                target: card
                property: "rotation"
                to: 4
                duration: fallAnim.dismissed ? 340 : 480
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                if (fallAnim.action)
                    fallAnim.action.invoke();
                else if (fallAnim.dismissed)
                    card.notification.dismiss();
                else
                    card.notification.expire();
            }
        }
    }

    Timer {
        running: !card.critical && !hover.hovered && !card.leaving
        interval: card.lifetime * 1000
        onTriggered: card.leave(false)
    }

    HoverHandler {
        id: hover
    }

    // Solid surface like the bar; critical ones get an error-coloured ring.
    Rectangle {
        id: bg

        anchors.fill: parent
        radius: 24
        color: Theme.surface
        border.width: card.critical ? 2 : 0
        border.color: Theme.rose

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.6
            shadowVerticalOffset: 4
        }
    }

    RowLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        anchors.topMargin: 14
        spacing: 12

        Item {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
            visible: icon.status === Image.Ready || image.status === Image.Ready

            IconImage {
                id: icon

                anchors.fill: parent
                visible: image.status !== Image.Ready
                source: card.notification.appIcon !== "" ? Quickshell.iconPath(card.notification.appIcon, true) : ""
                asynchronous: true
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                visible: image.status === Image.Ready

                Image {
                    id: image

                    anchors.fill: parent
                    source: card.notification.image
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: card.notification.appName
                    color: card.critical ? Theme.rose : Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                // Close: a round tonal button; flicks the card away.
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: closeMouse.containsMouse ? Theme.tonal : Theme.dusk

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? Theme.tonalInk : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.leave(true)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: card.notification.summary
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.body
                textFormat: Text.StyledText
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8
                visible: card.buttons.length > 0

                Repeater {
                    model: card.buttons

                    // The first action is the main one: accent pill; the rest are tonal.
                    Rectangle {
                        id: action

                        required property NotificationAction modelData
                        required property int index
                        readonly property bool primary: index === 0

                        width: label.implicitWidth + 28
                        height: 32
                        radius: height / 2
                        color: primary ? (actionMouse.containsMouse ? Qt.lighter(Theme.gold, 1.12) : Theme.gold) : (actionMouse.containsMouse ? Qt.lighter(Theme.tonal, 1.25) : Theme.tonal)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.fast
                            }
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: action.modelData.text
                            color: action.primary ? Theme.goldInk : Theme.tonalInk
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.invoke(action.modelData)
                        }
                    }
                }
            }
        }
    }

    // Clicking the card body runs its default action if it has one (and dismisses it);
    // the buttons and the close button above take priority.
    TapHandler {
        onTapped: {
            if (card.defaultAction)
                card.invoke(card.defaultAction);
            else
                card.leave(true);
        }
    }
}
