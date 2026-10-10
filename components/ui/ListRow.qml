import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Commons

// List line with a soft hover wash. Children go into the inner RowLayout;
// `overlay` children float over the row's right edge (hover actions) without
// taking layout width.
Rectangle {
  id: root

  default property alias content: row.data
  property alias overlay: overlayHost.data
  property alias cursorShape: hover.cursorShape
  // Keyboard selection: a stronger wash and a primary outline.
  property bool selected: false
  readonly property bool hovered: hover.hovered
  // True when the active focus item is this row or one of its descendants
  // (action buttons, inline editors). Views use it with hover/asking to keep
  // row actions visible for keyboard users.
  readonly property bool focusInside: {
    let f = Window.activeFocusItem;
    while (f) {
      if (f === root)
        return true;
      f = f.parent;
    }
    return false;
  }

  Layout.fillWidth: true
  implicitHeight: Math.max(Math.round(30 * Style.uiScaleRatio), row.implicitHeight + Math.round(8 * Style.uiScaleRatio))
  radius: Math.round(8 * Style.uiScaleRatio)
  color: selected ? Qt.alpha(Color.mOnSurface, 0.08) : hovered ? Qt.alpha(Color.mOnSurface, 0.04) : "transparent"
  border.color: selected ? Qt.alpha(Color.mPrimary, 0.5) : "transparent"
  border.width: Style.borderS

  HoverHandler {
    id: hover
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.leftMargin: Math.round(6 * Style.uiScaleRatio)
    anchors.rightMargin: Math.round(6 * Style.uiScaleRatio)
    spacing: Math.round(8 * Style.uiScaleRatio)
  }

  Item {
    id: overlayHost
    anchors.right: parent.right
    anchors.rightMargin: Math.round(4 * Style.uiScaleRatio)
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
    z: 2
  }
}
