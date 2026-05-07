import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "ambientSound"

    StyledText {
        width: parent.width
        text: "Ambient Sound Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: mainColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Audio Settings"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "defaultVolume"
                label: "Default Volume"
                description: "Initial volume level when a sound is first played."
                options: [
                    { label: "25%", value: 25 },
                    { label: "50%", value: 50 },
                    { label: "75%", value: 75 },
                    { label: "100%", value: 100 }
                ]
                defaultValue: 70
            }
        }
    }
}