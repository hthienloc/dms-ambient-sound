import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Right-click action on pill
    pillRightClickAction: () => root.stopAll()

    // Layout constants
    readonly property real cellWidth: (root.popoutWidth - (root.gridSpacing * 2) - 16) / 3
    readonly property real cellHeight: 80
    readonly property real iconSize: 28
    readonly property real fontSize: 14
    readonly property int gridSpacing: 8

    // Plugin directory (for sound files)
    readonly property string pluginDir: {
        var url = Qt.resolvedUrl(".").toString();
        if (url.startsWith("file://")) url = url.replace("file://", "");
        return url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    }

    // Sound definitions
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

    // Sleep timer presets
    readonly property var sleepPresets: [
        { label: "15m",  minutes: 15 },
        { label: "30m",  minutes: 30 },
        { label: "45m",  minutes: 45 },
        { label: "1h",   minutes: 60 },
        { label: "1.5h", minutes: 90 },
        { label: "2h",   minutes: 120 }
    ]

    // Audio state
    property var playingSounds: []
    property int masterVolume: parseInt(pluginData.defaultVolume) || 75

    // Helper – mpv commands
    function playSoundCmd(sound) {
        var soundFile = pluginDir + "/sounds/" + sound + ".ogg";
        return "mpv --no-video --no-config --loop=inf --volume=" + root.masterVolume + " '" + soundFile + "' > /dev/null 2>&1";
    }

    function killSoundCmd(pattern) {
        return "pkill -f 'ambientSound/sounds/" + pattern + ".ogg'";
    }

    // Audio logic
    function toggleSound(sound) {
        var idx = playingSounds.indexOf(sound);
        var list = playingSounds.slice();

        if (idx >= 0) {
            list.splice(idx, 1);
            playingSounds = list;
            Proc.runCommand("stop-" + sound, ["bash", "-c", killSoundCmd(sound)], null, 0);
            if (list.length === 0) {
                root.masterVolume = parseInt(pluginData.defaultVolume) || 75;
            }
        } else {
            list.push(sound);
            playingSounds = list;
            Proc.runCommand("play-" + sound, ["bash", "-c", playSoundCmd(sound)], null, 0);
        }
    }

    function stopAll() {
        playingSounds = [];
        Proc.runCommand("stop-all", ["bash", "-c", killSoundCmd(".*")], null, 0);
        root.masterVolume = parseInt(pluginData.defaultVolume) || 75;
    }

    function restartAll() {
        var toPlay = playingSounds.slice();
        Proc.runCommand("kill-all", ["bash", "-c", killSoundCmd(".*")], (output, exitCode) => {
            for (var i = 0; i < toPlay.length; i++) {
                Proc.runCommand("play-" + toPlay[i], ["bash", "-c", playSoundCmd(toPlay[i])], null, 0);
            }
        }, 0);
    }

    function adjustVolume(delta) {
        var newVol = Math.min(100, Math.max(0, root.masterVolume + delta));
        if (newVol !== root.masterVolume) {
            root.masterVolume = newVol;
            root.restartAll();
        }
    }

    // Auto‑start key generator
    function autoStartKey(soundName) {
        return "autoStart" + soundName.charAt(0).toUpperCase() + soundName.slice(1).replace("-", "");
    }

    // Timers
    Timer {
        id: autoStartTimer
        interval: 2000
        onTriggered: {
            for (var i = 0; i < root.sounds.length; i++) {
                var key = autoStartKey(root.sounds[i].name);
                if (pluginData[key]) root.toggleSound(root.sounds[i].name);
            }
            if (pluginData.enableSleepTimer) {
                var minutes = parseInt(pluginData.sleepTimerDuration) || 0;
                if (minutes > 0) {
                    sleepTimer.interval = minutes * 60 * 1000;
                    sleepTimer.remainingTime = minutes * 60 * 1000;
                    sleepTimer.start();
                }
            }
        }
    }

    Timer {
        id: sleepTimer
        property int remainingTime: 0
        onTriggered: {
            root.stopAll();
            remainingTime = 0;
        }
    }

    Timer {
        id: sleepCountdown
        interval: 1000
        repeat: true                     // tick every second
        running: sleepTimer.running
        onTriggered: sleepTimer.remainingTime = Math.max(0, sleepTimer.remainingTime - 1000);
    }

    Component.onCompleted: autoStartTimer.start()

    // ── Pill (horizontal & vertical) ──
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight

            // Mouse area for left click and wheel
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
                onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y > 0 ? 10 : -10;
                    root.adjustVolume(delta);
                }
            }

            // Centered content row
            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 4

                // Only show the note icon when nothing is playing
                DankIcon {
                    name: "music_note"
                    size: Theme.iconSizeMedium
                    color: Theme.surfaceVariantText
                    visible: root.playingSounds.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Dancing bars, visible only when something is playing
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1   // tighter bars
                    visible: root.playingSounds.length > 0
                    Repeater {
                        model: 5   // 5 bars
                        Rectangle {
                            width: 2
                            height: 6   // base height taller
                            radius: 1
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            Timer {
                                running: root.playingSounds.length > 0
                                repeat: true
                                interval: 150 + (index * 30)   // varied phases
                                onTriggered: parent.height = 6 + Math.random() * 12   // up to 18px
                            }
                            Behavior on height { NumberAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: horizontalBarPill

    // Popout dimensions
    popoutWidth: 380
    popoutHeight: 420

    // Popout content
    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Ambient Sounds"
            detailsText: root.playingSounds.length > 0 ? root.playingSounds.length + " playing" : "Tap to play"
            showCloseButton: false

            Column {
                width: parent.width
                spacing: 8

                // Volume slider
                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    DankIcon {
                        name: "volume_down"
                        size: 18
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankSlider {
                        id: volumeSlider
                        value: root.masterVolume
                        width: parent.width - 60
                        minimum: 0; maximum: 100
                        centerMinimum: false; unit: "%"; showValue: true
                        wheelEnabled: false
                        onSliderValueChanged: v => {
                            root.masterVolume = v;
                            root.restartAll();
                        }
                    }
                    DankIcon {
                        name: "volume_up"
                        size: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.playingSounds.length > 0 ? Theme.primary : Theme.surfaceVariantText
                    }
                }

                // Sound grid
                Flow {
                    width: parent.width
                    spacing: root.gridSpacing
                    Repeater {
                        model: root.sounds
                        delegate: Rectangle {
                            width: root.cellWidth
                            height: root.cellHeight
                            radius: Theme.cornerRadius
                            color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.primary : Theme.surfaceContainerHigh

                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                DankIcon {
                                    name: modelData.icon
                                    size: root.iconSize
                                    color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.onPrimary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: modelData.name.replace("-", " ")
                                    font.pixelSize: root.fontSize
                                    font.weight: Font.Medium
                                    color: root.playingSounds.indexOf(modelData.name) >= 0 ? Theme.onPrimary : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSound(modelData.name)
                            }
                        }
                    }
                }

                // Footer (sleep timer + stop all)
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: 4
                        visible: pluginData.enableSleepTimer ?? true

                        DankIcon {
                            name: "timer"
                            size: 18
                            color: sleepTimer.running ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: sleepTimer.running ? Math.ceil(sleepTimer.remainingTime / 60000) + " min left" : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: sleepTimer.running ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: root.sleepPresets
                            delegate: DankButton {
                                text: modelData.label
                                width: 48; height: 24
                                visible: !sleepTimer.running
                                onClicked: {
                                    var ms = modelData.minutes * 60 * 1000;
                                    sleepTimer.interval = ms;
                                    sleepTimer.remainingTime = ms;
                                    sleepTimer.start();
                                }
                            }
                        }

                        DankButton {
                            text: "Off"
                            width: 48; height: 24
                            backgroundColor: Theme.errorContainer
                            textColor: Theme.error
                            visible: sleepTimer.running
                            onClicked: sleepTimer.stop()
                        }
                    }

                    DankButton {
                        text: "Stop All"
                        iconName: "stop"
                        width: parent.width
                        visible: root.playingSounds.length > 0
                        backgroundColor: Theme.errorContainer
                        textColor: Theme.error
                        onClicked: root.stopAll()
                    }

                    StyledText {
                        text: "Right-click icon to stop all"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.playingSounds.length > 0 && (pluginData.showReminderText ?? true)
                    }
                }
            }
        }
    }
}