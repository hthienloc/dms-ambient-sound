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
    onActiveChanged: progressBorder.requestPaint()
    
    // Active background overlay (Material Design 3 style)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.activeColor
        opacity: root.active ? 0.12 : 0.0
        
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
            
            var w = width;
            var h = height;
            if (w <= 0 || h <= 0) return;
            
            var progress = Math.max(0.0, Math.min(1.0, root.volumeProgress));
            if (progress <= 0) return;
            
            var r = root.radius;
            var lw = 2; // line width
            
            ctx.strokeStyle = root.activeColor;
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            
            var offset = lw / 2;
            var r_adj = Math.max(0, r - offset);
            
            var L1 = w / 2 - offset - r_adj;
            var L2 = Math.PI / 2 * r_adj;
            var L3 = h - 2 * offset - 2 * r_adj;
            var L4 = L2;
            var L5 = w - 2 * offset - 2 * r_adj;
            var L6 = L2;
            var L7 = L3;
            var L8 = L2;
            var L9 = L1;
            
            var perimeter = L1 + L2 + L3 + L4 + L5 + L6 + L7 + L8 + L9;
            var d = perimeter * progress;
            
            ctx.beginPath();
            // Start at top center
            ctx.moveTo(w / 2, offset);
            
            // Segment 1: Top-right straight line
            if (d > 0) {
                var len = Math.min(d, L1);
                ctx.lineTo(w / 2 + len, offset);
                d -= len;
            }
            
            // Segment 2: Top-right arc
            if (d > 0) {
                var len = Math.min(d, L2);
                if (r_adj > 0) {
                    var angle = (len / L2) * (Math.PI / 2);
                    ctx.arc(w - offset - r_adj, offset + r_adj, r_adj, -Math.PI / 2, -Math.PI / 2 + angle);
                }
                d -= len;
            }
            
            // Segment 3: Right straight line
            if (d > 0) {
                var len = Math.min(d, L3);
                ctx.lineTo(w - offset, offset + r_adj + len);
                d -= len;
            }
            
            // Segment 4: Bottom-right arc
            if (d > 0) {
                var len = Math.min(d, L4);
                if (r_adj > 0) {
                    var angle = (len / L4) * (Math.PI / 2);
                    ctx.arc(w - offset - r_adj, h - offset - r_adj, r_adj, 0, angle);
                }
                d -= len;
            }
            
            // Segment 5: Bottom straight line
            if (d > 0) {
                var len = Math.min(d, L5);
                ctx.lineTo(w - offset - r_adj - len, h - offset);
                d -= len;
            }
            
            // Segment 6: Bottom-left arc
            if (d > 0) {
                var len = Math.min(d, L6);
                if (r_adj > 0) {
                    var angle = (len / L6) * (Math.PI / 2);
                    ctx.arc(offset + r_adj, h - offset - r_adj, r_adj, Math.PI / 2, Math.PI / 2 + angle);
                }
                d -= len;
            }
            
            // Segment 7: Left straight line
            if (d > 0) {
                var len = Math.min(d, L7);
                ctx.lineTo(offset, h - offset - r_adj - len);
                d -= len;
            }
            
            // Segment 8: Top-left arc
            if (d > 0) {
                var len = Math.min(d, L8);
                if (r_adj > 0) {
                    var angle = (len / L8) * (Math.PI / 2);
                    ctx.arc(offset + r_adj, offset + r_adj, r_adj, Math.PI, Math.PI + angle);
                }
                d -= len;
            }
            
            // Segment 9: Top-left straight line
            if (d > 0) {
                var len = Math.min(d, L9);
                ctx.lineTo(offset + r_adj + len, offset);
                d -= len;
            }
            
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
            color: root.active ? root.activeColor : root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        StyledText {
            text: root.title
            font.pixelSize: root.titleFontSize
            font.weight: Font.Medium
            color: root.active ? root.activeColor : root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
            elide: Text.ElideRight
            width: parent.parent.width - 16
            horizontalAlignment: Text.AlignHCenter
        }
        
        StyledText {
            text: root.subtitle
            font.pixelSize: 11
            color: root.active ? root.activeColor : root.textColor
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
