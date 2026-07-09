import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    anchors.fill: parent

    property var node: null
    property var parentItem
    property var availablePorts: []
    property string currentPort: ""
    property bool isLoading: false

    readonly property bool nodeValid: node !== null && node.isSink
    readonly property alias modalVisible: overlay.modalVisible

    signal portSelected(string sinkName, string portName)

    function show(sinkNode) {
        if (!sinkNode || !sinkNode.isSink)
            return;
        node = sinkNode;
        isLoading = true;
        availablePorts = [];
        currentPort = "";

        populateFromCache();
        AudioService.refreshSinkPorts();

        overlay.open();
    }

    function hide() {
        overlay.close();
    }

    function populateFromCache() {
        const info = AudioService.getSinkPorts(node);
        if (!info) {
            availablePorts = [];
            currentPort = "";
            return;
        }
        availablePorts = (info.ports || []).slice().sort((a, b) => b.priority - a.priority);
        currentPort = info.active || "";
        isLoading = false;
    }

    function portDescription(portName) {
        const port = availablePorts.find(p => p.name === portName);
        return port ? port.description : portName;
    }

    function selectPort(portName) {
        if (!nodeValid || isLoading)
            return;

        const port = availablePorts.find(p => p.name === portName);
        if (!port || port.availability === "no")
            return;

        const capturedName = node.name;
        isLoading = true;
        AudioService.setSinkPort(capturedName, portName, function (success, message) {
            if (!root.node || root.node.name !== capturedName)
                return;

            isLoading = false;
            if (success) {
                root.portSelected(capturedName, portName);
                ToastService.showToast(message, ToastService.levelInfo);
                Qt.callLater(root.hide);
                return;
            }
            ToastService.showToast(message, ToastService.levelError);
        });
    }

    onNodeValidChanged: {
        if (overlay.modalVisible && !nodeValid)
            overlay.close();
    }

    Connections {
        target: AudioService
        function onSinkPortsChanged() {
            if (!root.nodeValid)
                return;
            root.populateFromCache();
            root.isLoading = false;
        }
    }

    DetailOverlayModal {
        id: overlay

        onClosed: root.node = null

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.node ? AudioService.sinkIcon(root.node) : "speaker"
                size: Theme.iconSize + 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                StyledText {
                    text: root.node ? AudioService.displayName(root.node) : ""
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                StyledText {
                    text: I18n.tr("Port Selection")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineLight
        }

        StyledText {
            text: {
                if (root.isLoading)
                    return I18n.tr("Loading ports...");
                if (root.availablePorts.length === 0)
                    return I18n.tr("No ports found");
                return I18n.tr("Current: %1").arg(root.portDescription(root.currentPort));
            }
            font.pixelSize: Theme.fontSizeSmall
            color: root.isLoading ? Theme.primary : Theme.surfaceTextMedium
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: root.availablePorts.length > 0

            Repeater {
                model: root.availablePorts

                Rectangle {
                    required property var modelData

                    readonly property bool isCurrent: modelData.name === root.currentPort
                    readonly property bool unavailable: modelData.availability === "no"

                    width: parent.width
                    height: 48
                    radius: Theme.cornerRadius
                    opacity: unavailable ? 0.45 : 1
                    color: {
                        if (isCurrent)
                            return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency);
                        else if (portMouseArea.containsMouse)
                            return Theme.surfaceHover;
                        else
                            return "transparent";
                    }
                    border.color: "transparent"
                    border.width: 0

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: portCheck.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXXS

                        StyledText {
                            text: modelData.description
                            font.pixelSize: Theme.fontSizeMedium
                            color: isCurrent ? Theme.primary : Theme.surfaceText
                            font.weight: isCurrent ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: {
                                if (modelData.availability === "no")
                                    return I18n.tr("Unavailable");
                                if (modelData.availability === "yes")
                                    return I18n.tr("Available");
                                return "";
                            }
                            visible: text.length > 0
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    DankIcon {
                        id: portCheck
                        name: "check"
                        size: Theme.iconSize - 4
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: isCurrent
                    }

                    DankRipple {
                        id: portRipple
                        cornerRadius: parent.radius
                    }

                    MouseArea {
                        id: portMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !isCurrent && !unavailable && !root.isLoading
                        onPressed: mouse => portRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            root.selectPort(modelData.name);
                        }
                    }
                }
            }
        }
    }
}
