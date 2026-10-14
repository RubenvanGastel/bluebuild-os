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

    // Leaving: gravity wins. The card drops and tumbles, then really goes away.
    function leave(dismissed: bool): void {
        if (leaving)
            return;
        leaving = true;
        fallAnim.dismissed = dismissed;
        fallAnim.start();
    }

    SequentialAnimation {
        id: fallAnim

        property bool dismissed: false

        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "y"
                to: card.y + 260
                duration: 620
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: card
                property: "rotation"
                to: fallAnim.dismissed ? -9 : 7
                duration: 620
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: 620
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: fallAnim.dismissed ? card.notification.dismiss() : card.notification.expire()
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

    Rectangle {
        id: bg

        anchors.fill: parent
        radius: 18
        color: Theme.panel
        border.width: 1
        border.color: card.critical ? Theme.rose : Theme.panelBorder

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0.02, 0, 0.08, 0.7)
            shadowBlur: 0.8
            shadowVerticalOffset: 5
        }
    }

    // Gold accent along the left edge.
    Rectangle {
        x: 0
        y: 14
        width: 3
        height: parent.height - 28
        radius: 2
        color: card.critical ? Theme.rose : Theme.gold
    }

    RowLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 18
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
                radius: 10
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
                    color: Theme.textDim
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                }

                // Close: flick it away.
                Text {
                    text: "✕"
                    color: closeMouse.containsMouse ? Theme.cream : Theme.textDim
                    font.pixelSize: 12

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.leave(true)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: card.notification.summary
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.body
                textFormat: Text.StyledText
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                visible: card.notification.actions.length > 0

                Repeater {
                    model: card.notification.actions

                    Rectangle {
                        id: action

                        required property NotificationAction modelData

                        width: label.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: actionMouse.containsMouse ? Qt.rgba(Theme.gold.r, Theme.gold.g, Theme.gold.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Theme.panelBorder

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.fast
                            }
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: action.modelData.text
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: action.modelData.invoke()
                        }
                    }
                }
            }
        }
    }

    // Clicking the card body dismisses it (actions above take priority).
    TapHandler {
        onTapped: card.leave(true)
    }
}
