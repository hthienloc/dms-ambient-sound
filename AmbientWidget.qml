import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property real cellWidth: (root.popoutWidth - (root.gridSpacing * 2) - 16) / 3
    readonly property real cellHeight: 80
    readonly property real iconSize: 24
    readonly property real fontSize: 12
    readonly property int gridSpacing: 8

    readonly property string pluginDir: {
        var url = Qt.resolvedUrl(".").toString();
        if (url.startsWith("file://")) url = url.replace("file://", "");
        return url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    }

    // --- Audio Logic ---

    function playSoundCmd(sound) {
        var soundFile = pluginDir + "/sounds/" + sound + ".ogg";
        return "mpv --no-video --no-config --loop=inf --volume=" + root.masterVolume + " '" + soundFile + "' > /dev/null 2>&1";
    }

    function killSoundCmd(pattern) {
        return "pkill -f 'ambientSound/sounds/" + pattern + ".ogg'";
    }

    function toggleSound(sound) {
        var idx = playingSounds.indexOf(sound);
        var list = playingSounds.slice();
        
        if (idx >= 0) {
            list.splice(idx, 1);
            playingSounds = list;
            Proc.runCommand("stop-" + sound, ["bash", "-c", killSoundCmd(sound)], null, 0);
            if (list.length === 0) root.masterVolume = pluginData.defaultVolume ?? 70;
        } else {
            list.push(sound);
            playingSounds = list;
            Proc.runCommand("play-" + sound, ["bash", "-c", playSoundCmd(sound)], null, 0);
        }
    }

    function stopAll() {
        playingSounds = [];
        Proc.runCommand("stop-all", ["bash", "-c", killSoundCmd(".*")], null, 0);
        root.masterVolume = pluginData.defaultVolume ?? 70;
    }

    function restartAll() {
        var toPlay = playingSounds.slice();
        Proc.runCommand("kill-all", ["bash", "-c", killSoundCmd(".*")], (output, exitCode) => {
            for (var i = 0; i < toPlay.length; i++) {
                Proc.runCommand("play-" + toPlay[i], ["bash", "-c", playSoundCmd(toPlay[i])], null, 0);
            }
        }, 0);
    }

    property var playingSounds: []
    property int masterVolume: pluginData.defaultVolume ?? 70

    readonly property var sounds: [
        { name: "rain", icon: "water_drop" },
        { name: "fireplace", icon: "local_fire_department" },
        { name: "waves", icon: "waves" },
        { name: "wind", icon: "air" },
        { name: "storm", icon: "thunderstorm" },
        { name: "birds", icon: "flutter_dash" },
        { name: "city", icon: "location_city" },
        { name: "coffee-shop", icon: "local_cafe" },
        { name: "stream", icon: "water" },
        { name: "summer-night", icon: "dark_mode" }
    ]

    // --- UI Components ---

    horizontalBarPill: Component {
        DankActionButton {
            iconName: root.playingSounds.length > 0 ? "" : "music_note"
            iconSize: Theme.iconSizeSmall
            backgroundColor: root.playingSounds.length > 0 ? Theme.primary : "transparent"
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) root.stopAll();
                    else root.triggerPopout();
                }
            }

            Row {
                anchors.centerIn: parent
                visible: root.playingSounds.length > 0
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        width: 2; height: 4; radius: 1
                        color: Theme.onPrimary
                        anchors.verticalCenter: parent.verticalCenter
                        Timer {
                            running: root.playingSounds.length > 0; repeat: true; interval: 150 + (index * 50)
                            onTriggered: parent.height = 4 + Math.random() * 8
                        }
                        Behavior on height { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 380
    popoutHeight: 420

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Ambient Sounds"
            detailsText: root.playingSounds.length > 0 ? root.playingSounds.length + " playing" : "Tap to play"
            showCloseButton: false

            Column {
                width: parent.width; spacing: 8

                // Volume Slider Row
                Row {
                    width: parent.width; spacing: Theme.spacingS
                    DankIcon { name: "volume_down"; size: 18; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                    DankSlider {
                        id: volumeSlider; value: root.masterVolume; width: parent.width - 60; minimum: 0; maximum: 100
                        centerMinimum: false; unit: "%"; showValue: true; wheelEnabled: false
                        onSliderValueChanged: v => { root.masterVolume = v; root.restartAll(); }
                    }
                    DankIcon {
                        name: "volume_up"; size: 18; anchors.verticalCenter: parent.verticalCenter
                        color: root.playingSounds.length > 0 ? Theme.primary : Theme.surfaceVariantText
                    }
                }

                // Sound Grid
                Flow {
                    width: parent.width
                    spacing: root.gridSpacing

                    Repeater {
                        model: root.sounds
                        delegate: Rectangle {
                            width: root.cellWidth; height: root.cellHeight; radius: Theme.cornerRadius
                            color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.primary : Theme.surfaceContainerHigh

                            Column {
                                anchors.centerIn: parent; spacing: 2
                                DankIcon {
                                    name: modelData.icon; size: root.iconSize
                                    color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.onPrimary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: modelData.name.replace("-", " "); font.pixelSize: root.fontSize; font.weight: Font.Medium
                                    color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.onPrimary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSound(modelData.name)
                            }
                        }
                    }
                }

                // Footer
                Column {
                    width: parent.width; spacing: 4
                    DankButton {
                        text: "Stop All"; iconName: "stop"; width: parent.width; visible: root.playingSounds.length > 0
                        backgroundColor: Theme.errorContainer; textColor: Theme.error
                        onClicked: root.stopAll()
                    }
                    StyledText {
                        text: "Right-click icon to stop all"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter; visible: root.playingSounds.length > 0
                    }
                }
            }
        }
    }
}
