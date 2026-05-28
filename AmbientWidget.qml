import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"


PluginComponent {
    id: root
    readonly property bool showHints: pluginData.showHints ?? true


    // Right-click action on pill
    pillRightClickAction: () => root.toggleMute()

    // Layout constants
    readonly property real cellWidth: (root.popoutWidth - (root.gridSpacing * 2) - 16) / 3
    readonly property real cellHeight: 80
    readonly property real iconSize: 24
    readonly property real fontSize: 13
    readonly property int gridSpacing: 6

    // Plugin directory (for sound files)
    readonly property string pluginDir: {
        var url = Qt.resolvedUrl(".").toString();
        if (url.startsWith("file://")) url = url.replace("file://", "");
        return url.endsWith("/") ? url.substring(0, url.length - 1) : url;
    }

    function getIpcSocket(sound) {
        return "/tmp/dms-ambient-" + sound + ".sock";
    }

    // Sound definitions
    readonly property var sounds: [
        { name: "rain", icon: "water_drop" },
        { name: "storm", icon: "thunderstorm" },
        { name: "wind", icon: "air" },
        { name: "waves", icon: "waves" },
        { name: "stream", icon: "water" },
        { name: "birds", icon: "flutter_dash" },
        { name: "summer-night", icon: "dark_mode" },
        { name: "fireplace", icon: "local_fire_department" },
        { name: "coffee-shop", icon: "local_cafe" },
        { name: "city", icon: "location_city" },
        { name: "train", icon: "train" },
        { name: "boat", icon: "sailing" },
        { name: "white-noise", icon: "blur_on" },
        { name: "pink-noise", icon: "blur_linear" }
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

    // When Done options
    readonly property var whenDoneOptions: [
        { label: "Stop\nAll", value: "stopAll" },
        { label: "Mute", value: "mute" },
        { label: "Lock\nScreen", value: "lock" },
        { label: "Power\nOff", value: "powerOff" }
    ]
    property var whenDoneActions: pluginData.whenDoneActions || ["stopAll"]

    function isWhenDoneSelected(value) {
        return whenDoneActions.indexOf(value) >= 0;
    }

    function toggleWhenDoneAction(value) {
        var idx = whenDoneActions.indexOf(value);
        var newActions = whenDoneActions.slice();

        if (value === "stopAll" || value === "mute") {
            newActions = newActions.filter(a => a !== "stopAll" && a !== "mute");
            if (idx < 0) newActions.push(value);
        } else if (value === "lock" || value === "powerOff") {
            newActions = newActions.filter(a => a !== "lock" && a !== "powerOff");
            if (idx < 0) newActions.push(value);
        } else {
            if (idx >= 0) {
                if (whenDoneActions.length > 1) {
                    newActions.splice(idx, 1);
                }
            } else {
                newActions.push(value);
            }
        }

        whenDoneActions = newActions;
        pluginService.savePluginData(root.pluginId, "whenDoneActions", newActions);
    }

    // Audio state
    property var playingSounds: []
    property var soundVolumes: pluginData.soundVolumes || ({})
    property int masterVolume: pluginData.defaultVolume !== undefined ? parseInt(pluginData.defaultVolume) : 75
    property bool isMuted: false

    function getEffectiveVolume(sound) {
        var individual = soundVolumes[sound] !== undefined ? soundVolumes[sound] : 100;
        return (individual / 100) * (root.isMuted ? 0 : root.masterVolume);
    }

    function setSoundVolume(sound, vol) {
        soundVolumes[sound] = vol;
        pluginService.savePluginData(root.pluginId, "soundVolumes", soundVolumes);
        var socket = getIpcSocket(sound);
        sendIpcCommand(socket, { "command": ["set_property", "volume", getEffectiveVolume(sound)] });
    }

    // Preset state
    property var presets: pluginData.presets || []
    property int editingIndex: -1

    function savePreset() {
        if (playingSounds.length === 0) {
            ToastService.showError("Play some sounds first to save as preset!");
            return;
        }
        var newPresets = presets.slice();
        var presetName = "Preset " + (newPresets.length + 1);
        newPresets.push({
            name: presetName,
            sounds: playingSounds.slice(),
            volume: root.masterVolume
        });
        pluginService.savePluginData(root.pluginId, "presets", newPresets);
        ToastService.showInfo("Saved " + presetName);
    }

    function loadPreset(preset) {
        // First kill everything and wait for it to finish
        stopAll(() => {
            root.isMuted = false;
            root.masterVolume = preset.volume;
            root.playingSounds = preset.sounds.slice();
            
            // Now start playing each sound in the preset
            for (var i = 0; i < root.playingSounds.length; i++) {
                Proc.runCommand("play-" + root.playingSounds[i], ["bash", "-c", playSoundCmd(root.playingSounds[i])], null, 0);
            }
        });
    }

    function deletePreset(index) {
        var newPresets = presets.slice();
        newPresets.splice(index, 1);
        pluginService.savePluginData(root.pluginId, "presets", newPresets);
    }

    function renamePreset(index, newName) {
        if (newName && newName.trim() !== "") {
            var newPresets = presets.slice();
            newPresets[index].name = newName.trim();
            pluginService.savePluginData(root.pluginId, "presets", newPresets);
            ToastService.showInfo("Preset renamed to " + newName);
        }
        editingIndex = -1;
    }

    // Helper – mpv commands
    function playSoundCmd(sound) {
        var vol = root.isMuted ? 0 : root.masterVolume;
        var soundFile = pluginDir + "/sounds/" + sound + ".ogg";
        var socket = getIpcSocket(sound);
        return "mpv --no-video --no-config --loop=inf --volume=" + vol + " --input-ipc-server='" + socket + "' '" + soundFile + "' > /dev/null 2>&1";
    }

    function killSoundCmd(pattern) {
        return "pkill -f 'ambientSound/sounds/" + pattern + ".ogg'";
    }

    function sendIpcCommand(socket, cmdJson) {
        let cmd = "echo '" + JSON.stringify(cmdJson) + "' | socat - 'UNIX-CONNECT:" + socket + "'";
        Proc.runCommand("ipc-cmd", ["bash", "-c", cmd], null, 0);
    }

    function updateAllVolumes() {
        if (playingSounds.length === 0) return;
        var fullCmd = "";
        for (var i = 0; i < playingSounds.length; i++) {
            var sound = playingSounds[i];
            var vol = getEffectiveVolume(sound);
            var cmdJson = JSON.stringify({ "command": ["set_property", "volume", vol] });
            var socket = getIpcSocket(sound);
            fullCmd += "echo '" + cmdJson + "' | socat - 'UNIX-CONNECT:" + socket + "'; ";
        }
        Proc.runCommand("update-volumes", ["bash", "-c", fullCmd], null, 0);
    }

    // Audio logic
    function toggleMute() {
        isMuted = !isMuted;
        updateAllVolumes();
    }
    
    function toggleSound(sound) {
        var idx = playingSounds.indexOf(sound);
        var list = playingSounds.slice();

        if (idx >= 0) {
            list.splice(idx, 1);
            playingSounds = list;
            var socket = getIpcSocket(sound);
            Proc.runCommand("stop-" + sound, ["bash", "-c", killSoundCmd(sound) + "; rm -f " + socket], null, 0);
            if (list.length === 0) {
                root.isMuted = false;
            }
        } else {
            list.push(sound);
            playingSounds = list;
            Proc.runCommand("play-" + sound, ["bash", "-c", playSoundCmd(sound)], null, 0);
        }
    }

    function stopAll(callback) {
        playingSounds = [];
        isMuted = false;
        let cmd = killSoundCmd(".*") + "; rm -f /tmp/dms-ambient-*.sock";
        Proc.runCommand("stop-all", ["bash", "-c", cmd], (o, e) => {
            if (callback) callback();
        }, 0);
    }

    function adjustVolume(delta) {
        var newVol = Math.min(100, Math.max(0, root.masterVolume + delta));
        if (newVol !== root.masterVolume) {
            root.masterVolume = newVol;
            updateAllVolumes();
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
            executeWhenDone();
            remainingTime = 0;
        }
    }

    function executeWhenDone() {
        for (var i = 0; i < whenDoneActions.length; i++) {
            var action = whenDoneActions[i];
            if (action === "stopAll") {
                root.stopAll();
            } else if (action === "mute") {
                root.isMuted = true;
                root.updateAllVolumes();
            } else if (action === "lock") {
                Proc.runCommand("lock-screen", ["bash", "-c", "loginctl lock-session"], null, 0);
            } else if (action === "powerOff") {
                Proc.runCommand("power-off", ["bash", "-c", "systemctl suspend"], null, 0);
            }
        }
    }

    Timer {
        id: sleepCountdown
        interval: 1000
        repeat: true                     // tick every second
        running: sleepTimer.running
        onTriggered: sleepTimer.remainingTime = Math.max(0, sleepTimer.remainingTime - 1000);
    }

    Component.onCompleted: {
        autoStartTimer.start();
        // Initialize default preset only once
        if (pluginData.hasInitializedPresets === undefined) {
            var defaultPresets = [
                {
                    name: "Relaxing Rain",
                    sounds: ["rain", "birds", "wind"],
                    volume: 75
                }
            ];
            pluginService?.savePluginData(root.pluginId, "presets", defaultPresets);
            pluginService?.savePluginData(root.pluginId, "hasInitializedPresets", true);
        }
    }

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

                // Only show the note icon when nothing is playing or when muted
                DankIcon {
                    name: root.isMuted ? "volume_off" : "music_note"
                    size: 18
                    color: root.isMuted ? Theme.error : Theme.surfaceVariantText
                    visible: root.playingSounds.length === 0 || root.isMuted
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Dancing bars, visible only when something is playing and NOT muted
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1   // tighter bars
                    visible: root.playingSounds.length > 0 && !root.isMuted
                    Repeater {
                        model: 5   // 5 bars
                        Rectangle {
                            width: 2
                            height: 6   // base height taller
                            radius: 1
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            Timer {
                                running: root.playingSounds.length > 0 && !root.isMuted
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
    popoutWidth: 350
    popoutHeight: {
        let h = 330; // Base: Header + Audio + Grid + Timer + When Done
        if (root.presets.length > 0) h += 65;
        if (root.showHints && root.playingSounds.length > 0) h += 50;
        return h;
    }

    // Popout content
    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Ambient Sound"
            detailsText: root.playingSounds.length > 0 ? root.playingSounds.length + " playing" : "Tap to play"
            showCloseButton: false

            Column {
                width: parent.width
                spacing: 8

                // Volume & Control bar
                MediaHeader {
                    volume: root.masterVolume / 100
                    isMuted: root.isMuted
                    showStopButton: true
                    stopButtonEnabled: root.playingSounds.length > 0
                    onVolumeChangeRequested: v => {
                        root.masterVolume = v * 100;
                        if (v > 0 && root.isMuted) root.isMuted = false;
                        root.updateAllVolumes();
                    }
                    onMuteToggled: root.toggleMute()
                    onStopClicked: root.stopAll()
                }

                // Presets section - moved up for quick access
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.presets.length > 0

                    StyledText {
                        text: "Your Presets"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                    }

                    Flow {
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: root.presets
                            delegate: Item {
                                width: (parent.width - 4) / 2
                                height: 32

                                DankButton {
                                    id: presetButton
                                    text: modelData.name
                                    width: parent.width - 48
                                    height: parent.height
                                    visible: root.editingIndex !== index
                                    onClicked: root.loadPreset(modelData)
                                }

                                DankTextField {
                                    id: editField
                                    width: parent.width - 48
                                    height: parent.height
                                    text: modelData.name
                                    visible: root.editingIndex === index
                                    onEditingFinished: root.renamePreset(index, text)
                                    Component.onCompleted: {
                                        if (root.editingIndex === index) forceActiveFocus();
                                    }
                                }

                                DankIcon {
                                    name: root.editingIndex === index ? "check" : "edit"
                                    size: 16
                                    anchors.right: deleteIcon.left
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.surfaceVariantText
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.editingIndex === index) {
                                                root.renamePreset(index, editField.text);
                                            } else {
                                                root.editingIndex = index;
                                            }
                                        }
                                    }
                                }

                                DankIcon {
                                    id: deleteIcon
                                    name: "close"
                                    size: 16
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.error
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deletePreset(index)
                                    }
                                }
                            }
                        }
                    }
                }

                // Sound grid
                Flow {
                    width: parent.width
                    spacing: root.gridSpacing
                    
                    // 14 Sound Tiles
                    Repeater {
                        model: root.sounds
                        delegate: ActionTile {
                            width: root.cellWidth
                            height: root.cellHeight
                            iconName: modelData.icon
                            title: modelData.name.replace("-", " ")
                            titleFontSize: 12
                            subtitle: {
                                var vol = root.soundVolumes[modelData.name] !== undefined ? root.soundVolumes[modelData.name] : 100;
                                return vol < 100 ? vol + "%" : ""
                            }
                            active: root.playingSounds.indexOf(modelData.name) >= 0
                            
                            onClicked: root.toggleSound(modelData.name)
                            onScrollUp: {
                                if (active) {
                                    var current = root.soundVolumes[modelData.name] !== undefined ? root.soundVolumes[modelData.name] : 100;
                                    root.setSoundVolume(modelData.name, Math.min(100, current + 10));
                                }
                            }
                            onScrollDown: {
                                if (active) {
                                    var current = root.soundVolumes[modelData.name] !== undefined ? root.soundVolumes[modelData.name] : 100;
                                    root.setSoundVolume(modelData.name, Math.max(0, current - 10));
                                }
                            }
                        }
                    }

                    // 15th Slot: Save Preset Button
                    ActionTile {
                        width: root.cellWidth
                        height: root.cellHeight
                        iconName: "bookmark_add"
                        title: "Save Preset"
                        titleFontSize: 12
                        textColor: Theme.primary
                        onClicked: root.savePreset()
                    }
                }

                // Footer (sleep timer + stop all)
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: 4
                        visible: !sleepTimer.running

                        Repeater {
                            model: root.sleepPresets
                            delegate: DankButton {
                                text: modelData.label
                                width: (parent.width - (parent.spacing * 5)) / 6
                                height: 32
                                onClicked: {
                                    var ms = modelData.minutes * 60 * 1000;
                                    sleepTimer.interval = ms;
                                    sleepTimer.remainingTime = ms;
                                    sleepTimer.start();
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        visible: sleepTimer.running

                        StyledText {
                            text: "Sleep timer: " + Math.ceil(sleepTimer.remainingTime / 60000) + " minutes left"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80 - parent.spacing
                        }

                        DankButton {
                            text: "Cancel"
                            width: 80; height: 32
                            backgroundColor: Theme.surfaceContainerHighest
                            textColor: Theme.surfaceText
                            onClicked: sleepTimer.stop()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: "When Done:"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.whenDoneOptions
                                delegate: Rectangle {
                                    width: (parent.width - (parent.spacing * 3)) / 4; height: 36
                                    radius: Theme.cornerRadius
                                    color: root.isWhenDoneSelected(modelData.value) ? Theme.primary : Theme.surfaceContainerHigh
                                    border.width: root.isWhenDoneSelected(modelData.value) ? 0 : 1
                                    border.color: Theme.surfaceVariant
                                    clip: true

                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.isWhenDoneSelected(modelData.value) ? Theme.onPrimary : Theme.surfaceText
                                        width: parent.width
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleWhenDoneAction(modelData.value)
                                    }
                                }
                            }
                        }
                    }

                    HintSection {
                        width: parent.width
                        showHints: root.showHints && root.playingSounds.length > 0

                        HintItem {
                            icon: "mouse"
                            text: "Right-click bar icon to quickly mute/unmute."
                        }
                        HintItem {
                            icon: "mouse"
                            text: "Scroll on a sound tile to adjust its individual volume."
                        }
                    }
                }
            }
        }
    }
}
