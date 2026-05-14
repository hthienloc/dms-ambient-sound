import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "ambientSound"

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

    property var autoStartStates: ({})

    function autoStartKey(soundName) {
        return "autoStart" + soundName.charAt(0).toUpperCase() + soundName.slice(1).replace("-", "");
    }

    function updateAutoStartStates() {
        let states = {};
        for (let i = 0; i < sounds.length; i++) {
            let key = autoStartKey(sounds[i].name);
            states[key] = root.loadValue(key, false);
        }
        autoStartStates = states;
    }

    Component.onCompleted: updateAutoStartStates()
    onSettingChanged: updateAutoStartStates()

    StyledText {
        width: parent.width
        text: "Ambient Sound Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledRect {
        width: parent.width
        height: audioColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: audioColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Audio"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SliderSetting {
                settingKey: "defaultVolume"
                label: "Default Volume"
                description: "Initial volume when starting."
                minimum: 0
                maximum: 100
                unit: "%"
                defaultValue: 75
            }
        }
    }

    StyledRect {
        width: parent.width
        height: timerColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: timerColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Sleep Timer"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "enableSleepTimer"
                label: "Enable Sleep Timer"
                description: "Show sleep timer controls."
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "showReminderText"
                label: "Show Reminder Text"
                description: "Show helper text like right-click to stop."
                defaultValue: true
            }

            SelectionSetting {
                settingKey: "sleepTimerDuration"
                label: "Default Duration"
                description: "Default duration when starting timer."
                options: [
                    { label: "Off", value: "0" },
                    { label: "15 minutes", value: "15" },
                    { label: "30 minutes", value: "30" },
                    { label: "45 minutes", value: "45" },
                    { label: "1 hour", value: "60" },
                    { label: "1.5 hours", value: "90" },
                    { label: "2 hours", value: "120" }
                ]
                defaultValue: "0"
                visible: root.loadValue("enableSleepTimer", true)
            }
        }
    }

    StyledRect {
        width: parent.width
        height: autoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: autoColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Auto-Start on Login"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            
            StyledText {
                text: "Select sounds to play automatically when you log in."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Flow {
                id: autoStartFlow
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.sounds
                    delegate: Rectangle {
                        width: (autoStartFlow.width - 16) / 3
                        height: 44
                        radius: Theme.cornerRadius
                        
                        readonly property string sKey: root.autoStartKey(modelData.name)
                        readonly property bool isChecked: root.autoStartStates[sKey] ?? false
                        
                        color: isChecked ? Theme.primary : Theme.surfaceContainerHigh
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            DankIcon {
                                name: modelData.icon
                                size: 18
                                color: isChecked ? Theme.onPrimary : Theme.surfaceVariantText
                            }
                            StyledText {
                                text: modelData.name.replace("-", " ")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isChecked ? Font.Bold : Font.Normal
                                color: isChecked ? Theme.onPrimary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.saveValue(sKey, !isChecked);
                            }
                        }
                    }
                }
            }
        }
    }
}
