import QtQuick
import qs.Commons

import qs.Commons as Commons
// Square icon button whose glyph is optically centred, so play/pause and
// prev/next (which have different font metrics) line up on one axis.
Item {
  id: root

  property string iconText: ""
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property real size: Style.space(30)
  property real iconSize: Style.font.icon
  property real iconOffsetY: 0

  signal clicked()

  implicitWidth: size
  implicitHeight: size
  opacity: enabled ? 1.0 : 0.4

  Rectangle {
    anchors.fill: parent
    radius: Style.spacing.labelGap
    color: mouseArea.containsMouse && root.enabled ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Text {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: root.iconOffsetY
    text: root.iconText
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: root.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.enabled) root.clicked()
  }
}
