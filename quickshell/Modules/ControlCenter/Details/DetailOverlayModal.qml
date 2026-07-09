import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    default property alias content: contentColumn.data
    property real contentWidth: 320
    property bool modalVisible: false

    signal closed

    function open() {
        visible = true;
        modalVisible = true;
        Qt.callLater(() => focusScope.forceActiveFocus());
    }

    function close() {
        if (!modalVisible)
            return;
        modalVisible = false;
    }

    visible: false
    anchors.fill: parent
    z: 2000

    MouseArea {
        id: modalBlocker
        anchors.fill: parent
        visible: root.visible
        enabled: root.visible
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false

        onClicked: root.close()
        onWheel: wheel => {
            wheel.accepted = true;
        }
        onPositionChanged: mouse => {
            mouse.accepted = true;
        }
    }

    Rectangle {
        id: modalBackground
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, BlurService.enabled ? 0.72 : 0.5)
        opacity: root.modalVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: root.visible
        enabled: root.visible

        Keys.onEscapePressed: event => {
            root.close();
            event.accepted = true;
        }
    }

    Rectangle {
        id: modalContent
        anchors.centerIn: parent
        width: root.contentWidth
        height: contentColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, BlurService.enabled ? 0.96 : Theme.popupTransparency)
        border.color: BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium
        border.width: BlurService.enabled ? BlurService.borderWidth : Theme.layerOutlineWidth
        opacity: root.modalVisible ? 1 : 0
        scale: root.modalVisible ? 1 : 0.9

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onClicked: mouse => {
                mouse.accepted = true;
            }
            onWheel: wheel => {
                wheel.accepted = true;
            }
            onPositionChanged: mouse => {
                mouse.accepted = true;
            }
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
                onRunningChanged: {
                    if (!running && !root.modalVisible) {
                        root.visible = false;
                        root.closed();
                    }
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }
}
