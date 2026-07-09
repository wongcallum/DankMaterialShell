import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    anchors.fill: parent

    property var device: null
    property var parentItem
    property var availableCodecs: []
    property string currentCodec: ""
    property bool isLoading: false
    property string statusMessage: ""
    property bool statusIsError: false

    readonly property bool deviceValid: device !== null && device.connected && BluetoothService.isAudioDevice(device)
    readonly property alias modalVisible: overlay.modalVisible

    signal codecSelected(string deviceAddress, string codecName)

    function show(bluetoothDevice) {
        if (!bluetoothDevice?.connected)
            return;
        if (!BluetoothService.isAudioDevice(bluetoothDevice))
            return;
        device = bluetoothDevice;
        isLoading = true;
        availableCodecs = [];
        currentCodec = "";
        statusMessage = "";
        statusIsError = false;

        overlay.open();
        queryCodecs();
    }

    function hide() {
        overlay.close();
    }

    function queryCodecs() {
        if (!deviceValid) {
            hide();
            return;
        }

        const capturedDevice = device;
        const capturedAddress = device.address;

        BluetoothService.getAvailableCodecs(capturedDevice, function (codecs, current) {
            if (!root.deviceValid || root.device?.address !== capturedAddress)
                return;
            availableCodecs = codecs;
            currentCodec = current;
            isLoading = false;
            if (BluetoothService.pactlChecked && !BluetoothService.pactlAvailable) {
                statusMessage = I18n.tr("Codec switching is unavailable because pactl was not found");
                statusIsError = true;
            } else if (codecs.length === 0) {
                statusMessage = I18n.tr("No codecs found");
                statusIsError = false;
            } else {
                statusMessage = "";
                statusIsError = false;
            }
        });
    }

    function selectCodec(profileName) {
        if (!deviceValid || isLoading)
            return;

        const capturedDevice = device;
        const capturedAddress = device.address;

        const selectedCodec = availableCodecs.find(c => c.profile === profileName);
        if (!selectedCodec)
            return;

        isLoading = true;
        BluetoothService.switchCodec(capturedDevice, profileName, function (success, message) {
            if (!root.device || root.device.address !== capturedAddress)
                return;

            isLoading = false;
            if (success) {
                BluetoothService.updateDeviceCodec(capturedAddress, selectedCodec.name);
                root.codecSelected(capturedAddress, selectedCodec.name);
                ToastService.showToast(message, ToastService.levelInfo);
                Qt.callLater(root.hide);
                return;
            }
            ToastService.showToast(message, ToastService.levelError);
        });
    }

    onDeviceValidChanged: {
        if (overlay.modalVisible && !deviceValid)
            overlay.close();
    }

    DetailOverlayModal {
        id: overlay

        onClosed: root.device = null

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.device ? BluetoothService.getDeviceIcon(root.device) : "headset"
                size: Theme.iconSize + 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS

                StyledText {
                    text: root.device ? (root.device.name || root.device.deviceName) : ""
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                }

                StyledText {
                    text: I18n.tr("Audio Codec Selection")
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
                    return I18n.tr("Loading codecs...");
                if (root.statusMessage.length > 0)
                    return root.statusMessage;
                return I18n.tr("Current: %1").arg(root.currentCodec);
            }
            font.pixelSize: Theme.fontSizeSmall
            color: root.statusIsError ? Theme.error : (root.isLoading ? Theme.primary : Theme.surfaceTextMedium)
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: root.availableCodecs.length > 0

            Repeater {
                model: root.availableCodecs

                Rectangle {
                    required property var modelData

                    readonly property bool isCurrent: modelData.name === root.currentCodec

                    width: parent.width
                    height: 48
                    radius: Theme.cornerRadius
                    color: {
                        if (isCurrent)
                            return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency);
                        else if (codecMouseArea.containsMouse)
                            return Theme.surfaceHover;
                        else
                            return "transparent";
                    }
                    border.color: "transparent"
                    border.width: 0

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: modelData.qualityColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXXS

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                color: isCurrent ? Theme.primary : Theme.surfaceText
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                            }
                        }
                    }

                    DankIcon {
                        name: "check"
                        size: Theme.iconSize - 4
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: isCurrent
                    }

                    DankRipple {
                        id: codecRipple
                        cornerRadius: parent.radius
                    }

                    MouseArea {
                        id: codecMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !isCurrent && !root.isLoading
                        onPressed: mouse => codecRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            root.selectCodec(modelData.profile);
                        }
                    }
                }
            }
        }
    }
}
