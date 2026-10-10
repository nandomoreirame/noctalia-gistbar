import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import "components/ui"
import "utils/format.js" as Format
import "utils/mdrender.js" as MdRender
import "utils/markdown.js" as Markdown

// Overlay for one gist: selectable preview, Markdown when the file is Markdown,
// and an editor for the description plus the current file.
PanelWindow {
  id: root

  property var pluginApi: null
  property var mainInstance: null
  property string gistId: ""
  property int fileIndex: 0
  property bool editing: false
  property string editDescription: ""
  property string editBody: ""
  property var fileDrafts: ({})
  property bool saving: false
  property string saveError: ""
  property bool discardOpen: false
  property bool editSeeded: false

  readonly property var gist: {
    if (!mainInstance || gistId === "")
      return null;
    return mainInstance.gists.find(g => g.id === gistId) || null;
  }
  readonly property var entry: mainInstance && gistId !== "" ? mainInstance.contents[gistId] || null : null
  readonly property var files: entry && entry.files ? entry.files : []
  readonly property var file: files[fileIndex] || null
  readonly property bool markdownFile: {
    if (!file)
      return false;
    if (file.language === "Markdown")
      return true;
    return /\.md$/i.test(String(file.name || ""));
  }
  readonly property string savedDescription: gist ? String(gist.description || "") : ""
  readonly property string titleText: gist ? (gist.description || (file ? file.name : gistId)) : gistId
  readonly property bool dirty: {
    if (!editing || !file)
      return false;
    if (editDescription !== savedDescription)
      return true;
    if (editBody !== String(file.content || ""))
      return true;
    for (let i = 0; i < files.length; i++) {
      const f = files[i];
      if (!f || f.name === file.name)
        continue;
      if (fileDrafts[f.name] !== undefined && fileDrafts[f.name] !== String(f.content || ""))
        return true;
    }
    return false;
  }
  readonly property var markdownTheme: ({
      text: String(Color.mOnSurface),
      dim: String(Qt.tint(Color.mSurface, Qt.alpha(Color.mOnSurface, 0.6))),
      link: String(Color.mPrimary),
      codeBg: String(Qt.tint(Color.mSurface, Qt.alpha(Color.mOnSurface, 0.08))),
      codeFg: String(Color.mTertiary),
      border: String(Qt.tint(Color.mSurface, Qt.alpha(Color.mOnSurface, 0.18)))
    })

  anchors.top: true
  anchors.left: true
  anchors.right: true
  anchors.bottom: true
  visible: false
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  WlrLayershell.namespace: "noctalia-gistbar-preview"
  WlrLayershell.exclusionMode: ExclusionMode.Ignore

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : key;
  }

  function whenText() {
    if (!gist)
      return "";
    const rel = Format.relative(gist.updatedAt, Date.now());
    return tr(rel.key).replace("{n}", String(rel.n));
  }

  function openOn(targetScreen, id) {
    screen = targetScreen;
    gistId = id;
    fileIndex = 0;
    editing = false;
    editDescription = "";
    editBody = "";
    fileDrafts = ({});
    editSeeded = false;
    saving = false;
    saveError = "";
    discardOpen = false;
    visible = true;
    if (mainInstance)
      mainInstance.ensureContent(id);
  }

  function closeWindow(ask) {
    if (ask !== false && dirty) {
      discardOpen = true;
      return;
    }
    discardOpen = false;
    visible = false;
    editing = false;
    gistId = "";
    editBody = "";
    fileDrafts = ({});
    saveError = "";
  }

  function enterEdit() {
    if (!entry || !file)
      return;
    if (!editSeeded) {
      editDescription = savedDescription;
      editSeeded = true;
    }
    editing = true;
    editBody = storedBody(file.name, String(file.content || ""));
    descField.text = editDescription;
    editor.text = editBody;
    saveError = "";
    Qt.callLater(focusEditor);
  }

  function rememberCurrent() {
    if (!file)
      return;
    const next = Object.assign({}, fileDrafts);
    next[file.name] = editBody;
    fileDrafts = next;
  }

  function focusEditor() {
    editor.forceActiveFocus();
  }

  function storedBody(name, fallback) {
    if (fileDrafts[name] !== undefined)
      return fileDrafts[name];
    return fallback;
  }

  function selectFile(index) {
    if (editing && file)
      rememberCurrent();
    const nextFile = files[index];
    fileIndex = index;
    if (editing && nextFile) {
      editBody = storedBody(nextFile.name, String(nextFile.content || ""));
      editor.text = editBody;
    }
  }

  function toggleEdit() {
    if (editing) {
      rememberCurrent();
      editing = false;
    } else {
      enterEdit();
    }
  }

  function save() {
    if (saving || !file || !mainInstance)
      return;
    saving = true;
    saveError = "";
    mainInstance.saveGist(gistId, editDescription, file.name, editBody, function (ok) {
      root.saving = false;
      if (!ok) {
        root.saveError = root.tr("toast.failed");
        return;
      }
      root.saveError = "";
      root.fileDrafts = ({});
      root.editSeeded = true;
      const g = root.mainInstance.gists.find(item => item.id === root.gistId);
      root.editDescription = g ? String(g.description || "") : root.editDescription;
      descField.text = root.editDescription;
      const fresh = root.mainInstance.contents[root.gistId];
      const current = fresh && fresh.files ? fresh.files[root.fileIndex] : null;
      root.editBody = current ? String(current.content || "") : root.editBody;
      editor.text = root.editBody;
    });
  }

  onVisibleChanged: if (visible && mainInstance && gistId !== "") mainInstance.ensureContent(gistId)
  onDiscardOpenChanged: {
    if (discardOpen)
      discardPopup.open();
    else if (discardPopup.opened)
      discardPopup.close();
  }

  Shortcut {
    sequence: "Ctrl+E"
    enabled: root.visible && !root.discardOpen
    onActivated: root.toggleEdit()
  }
  Shortcut {
    sequence: "Ctrl+S"
    enabled: root.visible && root.editing && !root.discardOpen
    onActivated: root.save()
  }
  Shortcut {
    sequence: "Escape"
    enabled: root.visible && !root.discardOpen
    onActivated: root.closeWindow()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.closeWindow()

    Rectangle {
      anchors.fill: parent
      color: Qt.alpha(Color.mShadow, 0.35)
    }
  }

  Rectangle {
    width: Math.min(1100 * Style.uiScaleRatio, parent.width * 0.9)
    height: Math.min(800 * Style.uiScaleRatio, parent.height * 0.9)
    anchors.centerIn: parent
    radius: Style.radiusL
    color: Color.mSurface
    border.color: Qt.alpha(Color.mOnSurface, 0.08)
    border.width: Style.borderS

    MouseArea {
      anchors.fill: parent
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Math.round(18 * Style.uiScaleRatio)
      spacing: Math.round(12 * Style.uiScaleRatio)

      RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(6 * Style.uiScaleRatio)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.titleText
            pointSize: Style.fontSizeXL
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
          }

          NText {
            visible: root.gist !== null
            text: root.whenText()
            pointSize: Style.fontSizeXS
            color: Qt.alpha(Color.mOnSurface, 0.42)
          }
        }

        PillButton {
          icon: root.editing ? "eye" : "pencil"
          tooltipText: root.editing ? root.tr("preview.view") : root.tr("preview.edit")
          onClicked: root.toggleEdit()
        }
        PillButton {
          visible: root.editing
          icon: "device-floppy"
          text: root.tr("preview.save")
          busy: root.saving
          enabled: !root.saving
          onClicked: root.save()
        }
        PillButton {
          icon: "copy"
          tooltipText: root.tr("preview.copy")
          onClicked: root.mainInstance?.copyFile(root.gistId, root.fileIndex)
        }
        PillButton {
          icon: "x"
          tooltipText: root.tr("preview.close")
          onClicked: root.closeWindow()
        }
      }

      IconTabs {
        visible: root.files.length > 1
        controlled: true
        currentIndex: root.fileIndex
        model: root.files.map(f => ({ key: f.name, icon: "file", label: f.name }))
        onActivated: index => root.selectFile(index)
      }

      NText {
        visible: !root.entry
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.tr("bar.syncing")
        font.italic: true
        color: Qt.alpha(Color.mOnSurface, 0.56)
      }

      NScrollView {
        id: previewScroll
        visible: !!root.entry && !root.editing
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        horizontalPolicy: ScrollBar.AlwaysOff
        Component.onCompleted: if (contentItem) contentItem.interactive = false

        TextEdit {
          id: preview
          width: previewScroll.availableWidth
          readOnly: true
          selectByMouse: true
          persistentSelection: true
          wrapMode: TextEdit.Wrap
          textFormat: root.markdownFile ? TextEdit.RichText : TextEdit.PlainText
          text: {
            if (!root.file)
              return "";
            const body = String(root.file.content || "");
            return root.markdownFile ? MdRender.render(body, root.markdownTheme) : body;
          }
          font.family: root.markdownFile ? Settings.data.ui.fontDefault : Settings.data.ui.fontFixed
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          color: Color.mOnSurface
          selectionColor: Qt.alpha(Color.mPrimary, 0.35)
          selectedTextColor: Color.mOnSurface
          onLinkActivated: link => {
            if (Markdown.isOpenableLink(link))
              Quickshell.execDetached(["xdg-open", link]);
          }
        }
      }

      ColumnLayout {
        visible: !!root.entry && root.editing
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Math.round(8 * Style.uiScaleRatio)

        Field {
          id: descField
          Layout.fillWidth: true
          placeholderText: root.tr("preview.description")
          Accessible.name: root.tr("preview.description")
          onTextChanged: root.editDescription = text
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true

          TextArea {
            id: editor
            wrapMode: TextArea.Wrap
            font.family: Settings.data.ui.fontFixed
            font.pointSize: Style.fontSizeM * Style.uiScaleRatio
            color: Color.mOnSurface
            placeholderTextColor: Qt.alpha(Color.mOnSurface, 0.42)
            selectionColor: Qt.alpha(Color.mPrimary, 0.4)
            Accessible.name: root.tr("preview.edit")
            background: Rectangle {
              radius: Math.round(12 * Style.uiScaleRatio)
              color: Qt.alpha(Color.mOnSurface, 0.05)
            }
            onTextChanged: root.editBody = text
          }
        }

        NText {
          visible: root.saveError !== ""
          text: root.saveError
          color: Color.mError
          pointSize: Style.fontSizeS
        }
      }

      NText {
        visible: !!root.file && root.file.truncated
        text: root.tr("preview.truncated")
        font.italic: true
        pointSize: Style.fontSizeS
        color: Qt.alpha(Color.mOnSurface, 0.56)
      }

      NText {
        text: root.tr("preview.hints")
        pointSize: Style.fontSizeXS
        color: Qt.alpha(Color.mOnSurface, 0.42)
      }
    }
  }

  Popup {
    id: discardPopup
    modal: true
    focus: true
    padding: Math.round(12 * Style.uiScaleRatio)
    closePolicy: Popup.CloseOnEscape
    onAboutToShow: {
      x = Math.max(0, (root.width - width) / 2);
      y = Math.max(0, (root.height - height) / 2);
    }
    onClosed: root.discardOpen = false

    background: Rectangle {
      radius: Math.round(12 * Style.uiScaleRatio)
      color: Color.mSurface
      border.color: Qt.alpha(Color.mOnSurface, 0.12)
      border.width: Style.borderS
    }

    contentItem: ColumnLayout {
      spacing: Math.round(8 * Style.uiScaleRatio)

      NText {
        text: root.tr("preview.discard")
        pointSize: Style.fontSizeS
        color: Color.mOnSurface
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Math.round(6 * Style.uiScaleRatio)

        PillButton {
          text: root.tr("confirm.cancel")
          onClicked: root.discardOpen = false
        }
        PillButton {
          primary: true
          text: root.tr("confirm.ok")
          onClicked: root.closeWindow(false)
        }
      }
    }
  }
}
