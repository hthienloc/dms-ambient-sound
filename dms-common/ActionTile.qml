import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property color activeColor: Theme.primary
    property color onActiveColor: Theme.onPrimary
    property color borderColor: "transparent"
    property real borderWidth: 0
    property color textColor: Theme.surfaceText
    property int titleFontSize: 14
    property real volumeProgress: 0.0 // from 0.0 to 1.0
    
    signal clicked()
    signal pressAndHold()
    signal scrollUp()
    signal scrollDown()
    
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: borderColor
    border.width: borderWidth
    
    onVolumeProgressChanged: progressBorder.requestPaint()
    
    // Active background overlay (Material Design 3 style)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.primary
        opacity: 0.12
        visible: root.active
        
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // Dynamic progress border
    Canvas {
        id: progressBorder
        anchors.fill: parent
        visible: root.active && root.volumeProgress > 0
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            
            var progress = root.volumeProgress;
            if (progress <= 0) return;
            
            var w = width;
            var h = height;
            var r = root.radius;
            var lw = 2; // line width
            
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            
            var offset = lw / 2;
            var adjW = w - lw;
            var adjH = h - lw;
            var adjR = Math.max(0, r - offset);
            
            var perimeter = 2 * (adjW - 2 * adjR) + 2 * (adjH - 2 * adjR) + 2 * Math.PI * adjR;
            
            ctx.beginPath();
            // Start at top center
            ctx.moveTo(w / 2, offset);
            // Go to top right
            ctx.lineTo(w - offset - adjR, offset);
            ctx.arcTo(w - offset, offset, w - offset, offset + adjR, adjR);
            // Go to bottom right
            ctx.lineTo(w - offset, h - offset - adjR);
            ctx.arcTo(w - offset, h - offset, w - offset - adjR, h - offset, adjR);
            // Go to bottom left
            ctx.lineTo(offset + adjR, h - offset);
            ctx.arcTo(offset, h - offset, offset, h - offset - adjR, adjR);
            // Go to top left
            ctx.lineTo(offset, offset + adjR);
            ctx.arcTo(offset, offset, offset + adjR, offset, adjR);
            // Go back to top center
            ctx.lineTo(w / 2, offset);
            
            ctx.setLineDash([perimeter * progress, perimeter * (1 - progress)]);
            ctx.stroke();
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Column {
        anchors.centerIn: parent
        spacing: 4
        
        DankIcon {
            name: root.iconName
            size: 32
            color: root.active ? Theme.primary : root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        StyledText {
            text: root.title
            font.pixelSize: root.titleFontSize
            font.weight: Font.Medium
            color: root.active ? Theme.primary : root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
            width: parent.parent.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
        
        StyledText {
            text: root.subtitle
            font.pixelSize: 11
            color: root.active ? Theme.primary : root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) root.scrollUp()
            else root.scrollDown()
        }
    }
}
