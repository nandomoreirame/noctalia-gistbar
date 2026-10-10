import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "components"
import "components/ui"
import "utils/search.js" as Search
import "utils/format.js" as Format

// Gist list: search, visibility chips and rows. Create mode swaps in the form.
Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  readonly property var mainInstance: pluginApi?.mainInstance ?? null

  property string query: ""
  property string filter: "all"
  property int selected: 0
  property int asking: 0
  property bool showCreate: false
  property var frozenItems: []
  property var nowMs: Date.now()

  readonly property var counts: mainInstance ? Search.counts(mainInstance.gists) : ({ "all": 0, "public": 0, "secret": 0 })
  readonly property var liveItems: mainInstance ? Search.search(mainInstance.gists, mainInstance.contents, query, filter) : []
  readonly property var items: asking > 0 ? frozenItems : liveItems
  readonly property string authKind: {
    const err = mainInstance ? mainInstance.listState.error : "";
    return err === "gh-login" || err === "gh-missing" ? err : "";
  }

  onLiveItemsChanged: if (asking === 0) frozenItems = liveItems
  onAskingChanged: if (asking === 0) frozenItems = liveItems
  onQueryChanged: selected = 0
  onFilterChanged: selected = 0

  property real contentPreferredWidth: 640 * Style.uiScaleRatio
  property real contentPreferredHeight: 420 * Style.uiScaleRatio

  anchors.fill: parent

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : key;
  }

  function focusSearch() {
    searchField.forceActiveFocus();
  }

  function openCreateForm() {
    showCreate = true;
  }

  function updatedLabel() {
    if (!mainInstance || !mainInstance.listState.fetchedAt)
      return "";
    const rel = Format.relative(mainInstance.listState.fetchedAt, nowMs);
    if (rel.key === "time.now")
      return tr("panel.updated-now");
    if (rel.key === "time.minutes")
      return tr("panel.updated").replace("{n}", String(rel.n));
    return tr(rel.key).replace("{n}", String(rel.n));
  }

  function activateSelected(shift) {
    if (items.length === 0 || !mainInstance)
      return;
    const index = Math.max(0, Math.min(selected, items.length - 1));
    const gist = items[index];
    if (!gist)
      return;
    if (shift)
      mainInstance.copyLink(gist.id);
    else {
      mainInstance.copyGist(gist.id);
      if (pluginApi)
        pluginApi.closePanel(pluginApi.panelOpenScreen);
    }
  }

  onVisibleChanged: {
    if (!visible)
      return;
    nowMs = Date.now();
    if (mainInstance)
      mainInstance.onPanelOpened();
    if (mainInstance && mainInstance.requestedMode === "create") {
      showCreate = true;
      mainInstance.requestedMode = "";
    }
    if (!showCreate)
      Qt.callLater(focusSearch);
  }

  Connections {
    target: root.mainInstance
    function onRequestedModeChanged() {
      if (root.mainInstance && root.mainInstance.requestedMode === "create") {
        root.showCreate = true;
        root.mainInstance.requestedMode = "";
      }
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.visible
    onTriggered: root.nowMs = Date.now()
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Math.round(10 * Style.uiScaleRatio)
      spacing: Math.round(8 * Style.uiScaleRatio)

      RowLayout {
        visible: !root.showCreate
        Layout.fillWidth: true
        spacing: Style.marginS

        Field {
          id: searchField
          Layout.fillWidth: true
          placeholderText: root.tr("panel.search")
          Accessible.name: root.tr("panel.search")
          onTextChanged: root.query = text
          Keys.onEscapePressed: text = ""
          Keys.onUpPressed: function (event) {
            root.selected = Math.max(0, root.selected - 1);
            event.accepted = true;
          }
          Keys.onDownPressed: function (event) {
            root.selected = Math.min(Math.max(0, root.items.length - 1), root.selected + 1);
            event.accepted = true;
          }
          Keys.onReturnPressed: function (event) {
            root.activateSelected(event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
          }
          Keys.onEnterPressed: function (event) {
            root.activateSelected(event.modifiers & Qt.ShiftModifier);
            event.accepted = true;
          }
        }

        PillButton {
          icon: "plus"
          text: root.tr("panel.new")
          onClicked: root.openCreateForm()
        }

        PillButton {
          icon: "refresh"
          tooltipText: root.tr("panel.refresh")
          busy: root.mainInstance?.listState?.syncing ?? false
          onClicked: root.mainInstance?.refreshList()
        }
      }

      RowLayout {
        visible: !root.showCreate
        Layout.fillWidth: true
        spacing: Style.marginS

        Chip {
          text: root.tr("chip.all") + " (" + root.counts.all + ")"
          selected: root.filter === "all"
          onClicked: root.filter = "all"
        }
        Chip {
          text: root.tr("chip.public") + " (" + root.counts.public + ")"
          selected: root.filter === "public"
          onClicked: root.filter = "public"
        }
        Chip {
          text: root.tr("chip.secret") + " (" + root.counts.secret + ")"
          selected: root.filter === "secret"
          onClicked: root.filter = "secret"
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: root.mainInstance?.listState?.stale ? root.tr("panel.stale") : root.updatedLabel()
          font.italic: true
          pointSize: Style.fontSizeXS
          color: Qt.alpha(Color.mOnSurface, 0.56)
        }
      }

      Rectangle {
        visible: !root.showCreate && root.authKind !== ""
        Layout.fillWidth: true
        radius: Math.round(8 * Style.uiScaleRatio)
        color: Qt.alpha(Color.mError, 0.12)
        implicitHeight: authCol.implicitHeight + Math.round(16 * Style.uiScaleRatio)

        ColumnLayout {
          id: authCol
          anchors.fill: parent
          anchors.margins: Math.round(8 * Style.uiScaleRatio)
          spacing: Math.round(6 * Style.uiScaleRatio)

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.tr(root.authKind === "gh-missing" ? "error.gh-missing" : "error.gh-login")
            pointSize: Style.fontSizeS
            color: Color.mOnSurface
          }

          Rectangle {
            visible: root.authKind === "gh-login"
            radius: Math.round(6 * Style.uiScaleRatio)
            color: Qt.alpha(Color.mOnSurface, 0.08)
            implicitWidth: authCode.implicitWidth + Math.round(16 * Style.uiScaleRatio)
            implicitHeight: authCode.implicitHeight + Math.round(8 * Style.uiScaleRatio)

            NText {
              id: authCode
              anchors.centerIn: parent
              text: "gh auth login"
              family: Settings.data.ui.fontFixed
              pointSize: Style.fontSizeS
              textFormat: Text.PlainText
              color: Color.mOnSurface
            }
          }
        }
      }

      EmptyState {
        visible: !root.showCreate && root.items.length === 0 && root.authKind === ""
        icon: (root.mainInstance?.gists?.length ?? 0) === 0 ? "brand-github" : "search"
        title: (root.mainInstance?.gists?.length ?? 0) === 0 ? root.tr("panel.empty") : root.tr("panel.no-results").replace("{q}", root.query)
      }

      NScrollView {
        id: scroll
        visible: !root.showCreate && root.items.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        horizontalPolicy: ScrollBar.AlwaysOff

        ColumnLayout {
          width: scroll.availableWidth
          spacing: Math.round(2 * Style.uiScaleRatio)

          Repeater {
            model: root.items

            GistRow {
              required property var modelData
              required property int index
              pluginApi: root.pluginApi
              gist: modelData
              nowMs: root.nowMs
              selected: root.selected === index
              busy: !!(root.mainInstance && root.mainInstance.pendingCopy[modelData.id])
              onCopyRequested: root.mainInstance?.copyGist(modelData.id)
              onLinkRequested: root.mainInstance?.copyLink(modelData.id)
              onOpenRequested: root.mainInstance?.openGist(modelData.id)
              onDeleteRequested: root.mainInstance?.deleteGist(modelData.id)
              onPreviewRequested: root.mainInstance?.openPreview(modelData.id)
              onAskOpened: root.asking++
              onAskClosed: root.asking = Math.max(0, root.asking - 1)
            }
          }
        }
      }

      CreateForm {
        visible: root.showCreate
        Layout.fillWidth: true
        Layout.fillHeight: true
        pluginApi: root.pluginApi
        mainInstance: root.mainInstance
        active: root.showCreate
        onCancel: root.showCreate = false
        onCreated: root.showCreate = false
      }
    }
  }
}
