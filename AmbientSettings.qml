import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "ambientSound"

    // Helper component for consistent section layout
    component SettingsSection: StyledRect {
        id: sectionRoot
        property string title: ""
        default property alias sectionContent: sectionColumn.data  // ← indent đúng

        width: parent.width
        implicitHeight: sectionColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: sectionColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: Theme.spacingL
            }
            spacing: Theme.spacingM

            StyledText {
                text: sectionRoot.title
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                visible: text !== ""
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Ambient Sound Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SettingsSection {
        title: "Audio"
        NumberSetting {
            settingKey: "defaultVolume"
            label: "Default Volume (%)"
            description: "Initial volume level when a sound is first played."
            defaultValue: 70
            minimum: 0
            maximum: 100
        }
    }
}