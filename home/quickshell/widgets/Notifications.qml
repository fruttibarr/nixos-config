import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "root:/"
import "root:/services"

Scope {
    id: root

    property var toasts: []

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: notif => {
            // Everything lands in the control center's history...
            ShellState.pushHistory({
                id: notif.id,
                appName: notif.appName ?? "",
                appIcon: notif.appIcon ? Quickshell.iconPath(notif.appIcon, true) : "",
                summary: notif.summary ?? "",
                body: notif.body ?? "",
                image: notif.image ?? "",
                time: Date.now()
            });

            // ...but Do Not Disturb holds back toasts unless it's critical.
            if (ShellState.dnd && notif.urgency !== NotificationUrgency.Critical) return;

            // Keep the notification alive past this handler so it can be
            // rendered and dismissed from the toast stack.
            notif.tracked = true;
            root.toasts = [notif, ...root.toasts].slice(0, 5);
        }
    }

    function dismiss(notif) {
        root.toasts = root.toasts.filter(n => n !== notif);
        notif.dismiss();
    }

    PanelWindow {
        visible: root.toasts.length > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        // Toasts should never steal focus or reserve screen space.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        anchors {
            top: true
            right: true
        }

        margins {
            top: 8
            right: 10
        }

        implicitWidth: 380
        implicitHeight: Math.max(1, stack.implicitHeight + 30)
        color: "transparent"

        ColumnLayout {
            id: stack
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 8

            Repeater {
                model: root.toasts

                Item {
                    id: toast
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: card.implicitHeight

                    // Slide in from the right.
                    property real slide: 1
                    Component.onCompleted: slide = 0
                    Behavior on slide {
                        NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                    }

                    RectangularShadow {
                        anchors.fill: card
                        radius: card.radius
                        blur: 20
                        offset.y: 6
                        color: Qt.rgba(0, 0, 0, 0.45)
                        opacity: card.opacity
                    }

                    Rectangle {
                        id: card
                        x: toast.slide * (toast.width + 20)
                        width: toast.width
                        implicitHeight: body.implicitHeight + 26
                        radius: 20
                        color: Theme.island
                        border.width: 1
                        border.color: Theme.islandRim
                        opacity: 1 - toast.slide

                        HoverHandler {
                            id: hover
                        }

                        RowLayout {
                            id: body
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 13
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 38
                                implicitHeight: 38
                                radius: 12
                                color: Theme.alpha(Colors.primary, 0.15)
                                clip: true

                                Glyph {
                                    anchors.centerIn: parent
                                    visible: toastImg.status !== Image.Ready
                                    text: "󰂚"
                                    size: 16
                                    color: Colors.primary
                                }
                                Image {
                                    id: toastImg
                                    anchors.fill: parent
                                    source: toast.modelData.image
                                        || (toast.modelData.appIcon ? Quickshell.iconPath(toast.modelData.appIcon, true) : "")
                                    sourceSize.width: 76
                                    sourceSize.height: 76
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: toast.modelData.summary ?? ""
                                        color: Colors.text
                                        font.family: Theme.sans
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: toast.modelData.appName ?? ""
                                        color: Theme.textFaint
                                        font.family: Theme.sans
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: toast.modelData.body ?? ""
                                    color: Theme.textSoft
                                    font.family: Theme.sans
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                // Action buttons, when the app supplies any.
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    visible: (toast.modelData.actions?.length ?? 0) > 0
                                    spacing: 6

                                    Repeater {
                                        model: toast.modelData.actions ?? []
                                        Rectangle {
                                            required property var modelData
                                            implicitWidth: actText.implicitWidth + 22
                                            implicitHeight: 26
                                            radius: 13
                                            color: actMouse.containsMouse ? Theme.cardHover : Theme.card
                                            Text {
                                                id: actText
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                color: Colors.text
                                                font.family: Theme.sans
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            MouseArea {
                                                id: actMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    modelData.invoke();
                                                    root.dismiss(toast.modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            IconButton {
                                Layout.alignment: Qt.AlignTop
                                icon: "󰅖"
                                size: 22
                                flat: true
                                opacity: hover.hovered ? 1 : 0.35
                                onClicked: root.dismiss(toast.modelData)
                            }
                        }
                    }

                    // Pauses while hovered so you can actually read it.
                    Timer {
                        interval: HyprSettings.get("shell.toastSeconds") * 1000
                        running: !hover.hovered
                        onTriggered: root.dismiss(toast.modelData)
                    }
                }
            }
        }
    }
}
