import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

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

    SettingsCard {
        id: audioSection
        SectionTitle { 
            text: I18n.tr("Audio")
            icon: "volume_up" 
            showReset: defaultVolume.isDirty
            onResetClicked: defaultVolume.resetToDefault()
        }

        SliderSettingPlus {
            id: defaultVolume
            settingKey: "defaultVolume"
            label: I18n.tr("Default Volume")
            description: I18n.tr("Initial volume when starting.")
            minimum: 0
            maximum: 100
            unit: "%"
            defaultValue: 75
            leftLabel: "0%"
            rightLabel: "100%"
        }
    }

    SettingsCard {
        id: timerSection
        SectionTitle { 
            text: I18n.tr("Sleep Timer")
            icon: "timer" 
            showReset: enableSleepTimer.isDirty || defaultTimer.isDirty
            onResetClicked: {
                enableSleepTimer.resetToDefault();
                defaultTimer.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: enableSleepTimer
            settingKey: "enableSleepTimer"
            label: I18n.tr("Enable Sleep Timer")
            description: I18n.tr("Stop audio automatically after set duration.")
            defaultValue: true
        }

        Separator { visible: enableSleepTimer.value }

        SelectionSettingPlus {
            id: defaultTimer
            settingKey: "defaultTimer"
            label: I18n.tr("Default Duration")
            options: [
                { label: I18n.tr("15 minutes"), value: "15" },
                { label: I18n.tr("30 minutes"), value: "30" },
                { label: I18n.tr("45 minutes"), value: "45" },
                { label: I18n.tr("1 hour"), value: "60" },
                { label: I18n.tr("1.5 hours"), value: "90" },
                { label: I18n.tr("2 hours"), value: "120" }
            ]
            defaultValue: "30"
            visible: enableSleepTimer.value
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Auto-start Sounds"); icon: "play_circle_outline" }
        InfoText { text: I18n.tr("Select sounds to play automatically when you log in.") }

        Flow {
            id: autoStartFlow
            width: parent.width
            spacing: 6

            Repeater {
                model: root.sounds
                delegate: Rectangle {
                    width: (autoStartFlow.width - 12) / 3
                    height: 36
                    radius: Theme.cornerRadius
                    
                    readonly property string sKey: root.autoStartKey(modelData.name)
                    readonly property bool isChecked: root.autoStartStates[sKey] ?? false
                    
                    color: isChecked ? Theme.primary : Theme.surfaceContainerHigh
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        DankIcon {
                            name: modelData.icon
                            size: 16
                            color: isChecked ? Theme.onPrimary : Theme.surfaceVariantText
                        }
                        StyledText {
                            text: I18n.tr(modelData.name.replace("-", " "))
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

    SettingsCard {
        id: behaviorSection
        SectionTitle { 
            text: I18n.tr("Behavior")
            icon: "settings" 
            showReset: showHints.isDirty
            onResetClicked: showHints.resetToDefault()
        }

        ToggleSettingPlus {
            id: showHints
            settingKey: "showHints"
            label: I18n.tr("Show Hints")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Left-click</b> the pill to open the sound selector."),
                I18n.tr("<b>Right-click</b> the pill to stop all sounds instantly."),
                I18n.tr("You can play <b>multiple sounds</b> simultaneously to create your own atmosphere."),
                I18n.tr("Set the <b>Sleep Timer</b> in the popout to turn off sounds after a delay.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-ambient-sound"
    }
}
