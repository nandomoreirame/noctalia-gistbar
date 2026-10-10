import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "utils/format.js" as Format

// Bar entry: the GitHub mark and "Gists" (icon only on a vertical bar).
// Left click toggles the panel, middle click creates.
Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  readonly property bool syncing: !!mainInstance && !!mainInstance.listState.syncing
  readonly property bool authError: {
    const err = mainInstance ? mainInstance.listState.error : "";
    return err === "gh-login" || err === "gh-missing";
  }
  readonly property string tooltipText: {
    if (!mainInstance)
      return "";
    if (syncing)
      return pluginApi?.tr("bar.syncing") ?? "";
    const rel = Format.relative(mainInstance.listState.fetchedAt, Date.now());
    const when = (pluginApi?.tr(rel.key) ?? rel.key).replace("{n}", String(rel.n));
    return (pluginApi?.tr("bar.tooltip") ?? "").replace("{n}", String(mainInstance.gists.length)).replace("{when}", when);
  }

  readonly property bool barIsVertical: (Settings.data.bar.position || "top") === "left" || Settings.data.bar.position === "right"
  readonly property color fg: authError ? Color.mError : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)

  implicitWidth: barIsVertical ? Style.capsuleHeight : content.implicitWidth + Style.marginM * 2
  implicitHeight: Style.capsuleHeight

  Rectangle {
    anchors.centerIn: parent
    width: root.implicitWidth
    height: root.implicitHeight
    radius: Style.radiusL
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor

    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        id: mark
        icon: "brand-github"
        applyUiScale: false
        color: root.fg

        SequentialAnimation on opacity {
          running: root.syncing
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.35
            duration: 600
          }
          NumberAnimation {
            to: 1
            duration: 600
          }
          onRunningChanged: if (!running) mark.opacity = 1
        }
      }

      NText {
        visible: !root.barIsVertical
        text: root.pluginApi?.tr("bar.label") ?? ""
        pointSize: Style.barFontSize
        font.weight: Style.fontWeightSemiBold
        color: root.fg
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    Accessible.role: Accessible.Button
    Accessible.name: root.tooltipText

    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screen?.name))
    onExited: TooltipService.hide(root)

    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton && root.mainInstance)
        root.mainInstance.openCreate();
      else if (root.pluginApi)
        root.pluginApi.togglePanel(root.screen, root);
    }
  }
}
