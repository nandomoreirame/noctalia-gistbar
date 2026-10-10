import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "ui"
import "../utils/gists.js" as Gists
import "../utils/format.js" as Format

// One gist: title, file names, language, relative time, lock when secret.
ListRow {
  id: root

  property var pluginApi: null
  property var gist: null
  property var nowMs: 0
  property bool busy: false

  signal copyRequested
  signal linkRequested
  signal openRequested
  signal deleteRequested
  signal previewRequested
  signal askOpened
  signal askClosed

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : key;
  }

  readonly property string titleText: gist ? Gists.title(gist) : ""
  readonly property string filesText: gist ? gist.files.map(f => f.name).join(", ") : ""
  readonly property string languageText: {
    if (!gist)
      return "";
    for (const f of gist.files) {
      if (f.language)
        return f.language;
    }
    return "";
  }
  readonly property string whenText: {
    if (!gist)
      return "";
    const rel = Format.relative(gist.updatedAt, nowMs || Date.now());
    return tr(rel.key).replace("{n}", String(rel.n));
  }

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: titleText

  NIcon {
    id: kindIcon
    icon: root.busy ? "refresh" : "code"
    pointSize: Style.fontSizeM
    color: Qt.alpha(Color.mOnSurface, 0.56)

    RotationAnimator on rotation {
      from: 0
      to: 360
      duration: 900
      loops: Animation.Infinite
      running: root.busy
      onRunningChanged: if (!running) kindIcon.rotation = 0
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    NText {
      Layout.fillWidth: true
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.titleText
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightSemiBold
      color: Color.mOnSurface
    }

    NText {
      visible: root.filesText !== ""
      Layout.fillWidth: true
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.filesText
      pointSize: Style.fontSizeS
      color: Qt.alpha(Color.mOnSurface, 0.56)
    }
  }

  // Static language tag: the row's tap opens the preview, so nothing here is clickable.
  Rectangle {
    visible: root.languageText !== ""
    implicitWidth: langLabel.implicitWidth + Math.round(14 * Style.uiScaleRatio)
    implicitHeight: langLabel.implicitHeight + Math.round(6 * Style.uiScaleRatio)
    radius: height / 2
    color: Qt.alpha(Color.mOnSurface, 0.06)

    NText {
      id: langLabel
      anchors.centerIn: parent
      text: root.languageText
      pointSize: Style.fontSizeXS
      color: Qt.alpha(Color.mOnSurface, 0.7)
    }
  }

  NIcon {
    visible: !!root.gist && !root.gist.public
    icon: "lock"
    pointSize: Style.fontSizeS
    color: Qt.alpha(Color.mOnSurface, 0.56)
    Accessible.name: root.tr("row.secret")
  }

  NText {
    text: root.whenText
    pointSize: Style.fontSizeXS
    color: Qt.alpha(Color.mOnSurface, 0.42)
  }

  cursorShape: Qt.PointingHandCursor

  // Hover/Tab actions float over the right edge (language, lock and time stay
  // in the layout underneath), on an opaque wash with a short fade so they
  // never cost the title any width.
  overlay: Rectangle {
    id: actions
    opacity: root.hovered || root.focusInside || trash.asking ? 1 : 0
    readonly property color wash: Qt.tint(Color.mSurface, root.selected ? Qt.alpha(Color.mOnSurface, 0.08) : Qt.alpha(Color.mOnSurface, 0.04))
    implicitWidth: actionRow.implicitWidth + fade.width
    implicitHeight: actionRow.implicitHeight
    width: implicitWidth
    height: implicitHeight
    color: "transparent"

    Rectangle {
      id: fade
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: Math.round(16 * Style.uiScaleRatio)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.alpha(actions.wash, 0) }
        GradientStop { position: 1.0; color: actions.wash }
      }
    }

    Rectangle {
      anchors.left: fade.right
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      color: actions.wash
    }

    RowLayout {
      id: actionRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Math.round(2 * Style.uiScaleRatio)

      PillButton {
        icon: "copy"
        tooltipText: root.tr("row.copy")
        // The row icon already spins while the content loads; one indicator is enough.
        enabled: !root.busy
        onClicked: root.copyRequested()
      }
      PillButton {
        icon: "link"
        tooltipText: root.tr("row.link")
        onClicked: root.linkRequested()
      }
      PillButton {
        icon: "external-link"
        tooltipText: root.tr("row.open")
        onClicked: root.openRequested()
      }
      ConfirmButton {
        id: trash
        icon: "trash"
        tooltipText: root.tr("row.delete")
        question: root.tr("row.confirm-delete")
        okText: root.tr("confirm.ok")
        cancelText: root.tr("confirm.cancel")
        onConfirmed: root.deleteRequested()
        onOpened: root.askOpened()
        onClosed: root.askClosed()
      }
    }
  }

  TapHandler {
    onTapped: root.previewRequested()
  }
}
