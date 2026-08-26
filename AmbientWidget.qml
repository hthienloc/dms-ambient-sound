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
    readonly property real cellWidth: (root.popoutWidth - (root.gridSpacing * 3) - 16) / 4
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

    function hashString(value) {
        var hash = 0;
        var text = String(value);
        for (var i = 0; i < text.length; i++) {
            hash = ((hash << 5) - hash) + text.charCodeAt(i);
            hash = hash & hash;
        }
        return Math.abs(hash).toString(36);
    }

    function soundId(sound) {
        return sound.id || sound.name;
    }

    function getIpcSocket(soundId) {
        var safeId = String(soundId).replace(/[^A-Za-z0-9_.-]/g, "_");
        if (safeId.length > 48) safeId = safeId.substring(0, 32) + "-" + hashString(soundId);
        return "/tmp/dms-ambient-" + safeId + ".sock";
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function getSound(soundId) {
        for (var i = 0; i < sounds.length; i++) {
            if (root.soundId(sounds[i]) === soundId || sounds[i].name === soundId) return sounds[i];
        }
        return { name: soundId, icon: "music_note" };
    }

    function commandId(prefix, sound) {
        return prefix + "-" + hashString(sound);
    }

    // Sound definitions
    readonly property var bundledSounds: [
        { name: "rain", icon: "water_drop" },
        { name: "storm", icon: "thunderstorm" },
        { name: "wind", icon: "air" },
        { name: "waves", icon: "waves" },
        { name: "stream", icon: "water" },
        { name: "birds", icon: "flutter_dash" },
        { name: "forest", icon: "forest" },
        { name: "summer-night", icon: "dark_mode" },
        { name: "fireplace", icon: "local_fire_department" },
        { name: "coffee-shop", icon: "local_cafe" },
        { name: "city", icon: "location_city" },
        { name: "train", icon: "train" },
        { name: "boat", icon: "sailing" },
        { name: "acoustic-guitar", icon: "music_note" },
        { name: "warm-piano", icon: "piano" },
        { name: "ambient-music", icon: "library_music" },
        { name: "lofi-beats", icon: "headphones" },
        { name: "fan", icon: "mode_fan" },
        { name: "airplane", icon: "flight" },
        { name: "laundry-room", icon: "local_laundry_service" },
        { name: "white-noise", icon: "blur_on" },
        { name: "pink-noise", icon: "blur_linear" },
        { name: "brown-noise", icon: "blur_circular" },
        { name: "green-noise", icon: "lens_blur" }
    ]

    readonly property var customSounds: (pluginData.customSounds || []).map(sound => ({
        id: "custom:" + sound.path,
        name: sound.name,
        icon: "audiotrack",
        path: sound.path,
        custom: true
    }))
    readonly property var sounds: bundledSounds.concat(customSounds)
    readonly property var visibleSounds: sounds.filter(s => s.custom || (pluginData.hiddenSounds || []).indexOf(s.name) < 0)

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
        var volumes = Object.assign({}, soundVolumes);
        volumes[sound] = vol;
        soundVolumes = volumes;
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
                Proc.runCommand(commandId("play", root.playingSounds[i]), ["bash", "-c", playSoundCmd(root.playingSounds[i])], null, 0);
            }
        });
    }

    function togglePresetByName(presetName) {
        var foundPreset = null;
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].name === presetName) {
                foundPreset = presets[i];
                break;
            }
        }
        if (!foundPreset) return;

        var active = true;
        if (root.playingSounds.length !== foundPreset.sounds.length) {
            active = false;
        } else {
            for (var j = 0; j < foundPreset.sounds.length; j++) {
                if (root.playingSounds.indexOf(foundPreset.sounds[j]) < 0) {
                    active = false;
                    break;
                }
            }
        }

        if (active) {
            root.stopAll();
        } else {
            root.loadPreset(foundPreset);
        }
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
        var vol = getEffectiveVolume(sound);
        var soundData = getSound(sound);
        var soundFile = soundData.path || (pluginDir + "/sounds/" + soundData.name + ".ogg");
        var socket = getIpcSocket(sound);
        return "if command -v mpv >/dev/null 2>&1; then mpv --no-video --no-config --loop=inf --volume=" + vol + " --input-ipc-server=" + shellQuote(socket) + " " + shellQuote(soundFile) + " > /dev/null 2>&1; elif command -v ffplay >/dev/null 2>&1; then ffplay -nodisp -loglevel quiet -loop 0 -volume " + vol + " " + shellQuote(soundFile) + " > /dev/null 2>&1; else dms notify 'Ambient Sound' 'Install mpv or ffplay for playback' --icon music_note; exit 1; fi";
    }

    function killSoundCmd(sound) {
        var soundData = getSound(sound);
        var soundFile = soundData.path || (pluginDir + "/sounds/" + soundData.name + ".ogg");
        return "pkill -f " + shellQuote(soundFile);
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
            Proc.runCommand(commandId("stop", sound), ["bash", "-c", killSoundCmd(sound) + "; rm -f " + shellQuote(socket)], null, 0);
            if (list.length === 0) {
                root.isMuted = false;
            }
        } else {
            list.push(sound);
            playingSounds = list;
            Proc.runCommand(commandId("play", sound), ["bash", "-c", playSoundCmd(sound)], null, 0);
        }
    }

    function stopAll(callback) {
        playingSounds = [];
        isMuted = false;
        let cmd = "pkill -f 'ambientSound/sounds/.*\\.ogg'";
        for (var i = 0; i < root.customSounds.length; i++) {
            cmd += "; pkill -f " + shellQuote(root.customSounds[i].path);
        }
        cmd += "; rm -f /tmp/dms-ambient-*.sock";
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
            var mode = pluginData.autoStartMode || "preset";
            if (mode === "preset") {
                var presetName = pluginData.autoStartPreset || "";
                if (presetName !== "") {
                    root.togglePresetByName(presetName);
                }
            } else {
                for (var i = 0; i < root.sounds.length; i++) {
                    var key = autoStartKey(root.sounds[i].name);
                    if (pluginData[key]) root.toggleSound(root.sounds[i].name);
                }
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
            if (pluginService) {
                pluginService.savePluginData(root.pluginId, "presets", defaultPresets);
                pluginService.savePluginData(root.pluginId, "hasInitializedPresets", true);
            }
        }
    }

    // ── Pill (horizontal & vertical) ──
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight

            // Mouse area for left click, middle click, and wheel
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        var preset = pluginData.middleClickAction || "";
                        if (preset !== "") {
                            root.togglePresetByName(preset);
                        }
                    } else {
                        root.triggerPopout();
                    }
                }
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
    popoutWidth: 440
    popoutHeight: {
        let gridRows = Math.ceil(root.visibleSounds.length / 4);
        let gridHeight = gridRows * root.cellHeight + (gridRows - 1) * root.gridSpacing;
        let baseH = 90; // Header + MediaHeader + spacing/padding
        if (pluginData.showTimerSection ?? true) baseH += 110; // Sleep presets & When Done
        let h = baseH + gridHeight;
        if (root.presets.length > 0 || root.playingSounds.length > 0) {
            h += 40; // Save preset button / header row
            if (root.presets.length > 0) {
                let presetRows = Math.ceil(root.presets.length / 2);
                h += presetRows * 32 + (presetRows - 1) * 4 + 8; // Presets flow height
            }
        }
        if (root.showHints && root.playingSounds.length > 0) h += 50;
        return Math.min(800, h);
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
                    visible: root.presets.length > 0 || root.playingSounds.length > 0

                    Item {
                        width: parent.width
                        height: 32

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Your Presets")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceVariantText
                            visible: root.presets.length > 0
                        }

                        DankButton {
                            id: saveButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Save Preset")
                            iconName: "bookmark_add"
                            buttonHeight: 28
                            backgroundColor: "transparent"
                            textColor: Theme.primary
                            horizontalPadding: Theme.spacingM
                            visible: root.playingSounds.length > 0
                            onClicked: root.savePreset()
                        }
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
                    
                    // Sound Tiles
                    Repeater {
                        model: root.visibleSounds
                        delegate: ActionTile {
                            readonly property string itemId: root.soundId(modelData)
                            width: root.cellWidth
                            height: root.cellHeight
                            iconName: modelData.icon
                            title: modelData.name.replace("-", " ")
                            titleFontSize: 12
                            subtitle: ""
                            volumeProgress: {
                                var vol = root.soundVolumes[itemId] !== undefined ? root.soundVolumes[itemId] : 100;
                                return vol / 100.0;
                            }
                            active: root.playingSounds.indexOf(itemId) >= 0
                            
                            onClicked: root.toggleSound(itemId)
                            onScrollUp: {
                                if (active) {
                                    var current = root.soundVolumes[itemId] !== undefined ? root.soundVolumes[itemId] : 100;
                                    root.setSoundVolume(itemId, Math.min(100, current + 5));
                                }
                            }
                            onScrollDown: {
                                if (active) {
                                    var current = root.soundVolumes[itemId] !== undefined ? root.soundVolumes[itemId] : 100;
                                    root.setSoundVolume(itemId, Math.max(0, current - 5));
                                }
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
                        visible: !sleepTimer.running && (pluginData.showTimerSection ?? true)

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
                            text: I18n.tr("Sleep timer: ") + Math.ceil(sleepTimer.remainingTime / 60000) + I18n.tr(" minutes left")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80 - parent.spacing
                        }

                        DankButton {
                            text: I18n.tr("Cancel")
                            width: 80; height: 32
                            backgroundColor: Theme.surfaceContainerHighest
                            textColor: Theme.surfaceText
                            onClicked: sleepTimer.stop()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: pluginData.showTimerSection ?? true

                        StyledText {
                            text: I18n.tr("When Done:")
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
                            text: I18n.tr("Middle-click bar icon to toggle your preset sound.")
                        }
                        HintItem {
                            icon: "mouse"
                            text: I18n.tr("Right-click bar icon to quickly mute/unmute.")
                        }
                        HintItem {
                            icon: "mouse"
                            text: I18n.tr("Scroll on a sound tile to adjust its individual volume.")
                        }
                    }
                }
            }
        }
    }
}
