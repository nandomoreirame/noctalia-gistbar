import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "ui"
import "../utils/filename.js" as Filename

// New gist from the clipboard. Public stays off unless the user turns it on.
ColumnLayout {
  id: root

  property var pluginApi: null
  property var mainInstance: null
  property bool active: false
  property string filename: ""
  property string description: ""
  property string content: ""
  property bool isPublic: false
  property bool nameEdited: false
  property bool applyingName: false
  property bool emptyClip: false
  property bool busy: false

  signal cancel
  signal created

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : key;
  }

  function setSuggested(name) {
    applyingName = true;
    filename = name;
    nameField.text = name;
    applyingName = false;
  }

  function loadClipboard() {
    nameEdited = false;
    description = "";
    descField.text = "";
    isPublic = false;
    content = "";
    body.text = "";
    emptyClip = false;
    busy = false;
    if (!mainInstance)
      return;
    mainInstance.clipboardText(function (text) {
      if (!root.active)
        return;
      const value = String(text || "");
      root.content = value;
      root.body.text = value;
      root.emptyClip = value.trim() === "";
      if (!root.nameEdited)
        root.setSuggested(Filename.suggestName(value));
      root.body.forceActiveFocus();
    });
  }

  onActiveChanged: if (active) loadClipboard()

  spacing: Math.round(8 * Style.uiScaleRatio)

  NText {
    text: root.tr("create.title")
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightSemiBold
    color: Color.mOnSurface
  }

  NText {
    visible: root.emptyClip && root.content.trim() === ""
    text: root.tr("create.empty-clipboard")
    font.italic: true
    pointSize: Style.fontSizeS
    color: Qt.alpha(Color.mOnSurface, 0.56)
  }

  ScrollView {
    Layout.fillWidth: true
    Layout.fillHeight: true

    TextArea {
      id: body
      wrapMode: TextArea.Wrap
      font.family: Settings.data.ui.fontFixed
      font.pointSize: Style.fontSizeM * Style.uiScaleRatio
      color: Color.mOnSurface
      placeholderTextColor: Qt.alpha(Color.mOnSurface, 0.42)
      selectionColor: Qt.alpha(Color.mPrimary, 0.4)
      background: Rectangle {
        radius: Math.round(12 * Style.uiScaleRatio)
        color: Qt.alpha(Color.mOnSurface, 0.05)
      }
      Accessible.name: root.tr("create.title")
      onTextChanged: {
        root.content = text;
        if (!root.nameEdited)
          root.setSuggested(Filename.suggestName(text));
      }
    }
  }

  Field {
    id: nameField
    Layout.fillWidth: true
    placeholderText: root.tr("create.filename")
    Accessible.name: root.tr("create.filename")
    onTextChanged: {
      if (root.applyingName)
        return;
      root.filename = text;
      root.nameEdited = true;
    }
  }

  Field {
    id: descField
    Layout.fillWidth: true
    placeholderText: root.tr("create.description")
    Accessible.name: root.tr("create.description")
    onTextChanged: root.description = text
  }

  NToggle {
    label: root.tr("create.public")
    description: root.tr("create.public-desc")
    checked: root.isPublic
    onToggled: checked => root.isPublic = checked
  }

  RowLayout {
    Layout.alignment: Qt.AlignRight
    spacing: Style.marginS

    PillButton {
      text: root.tr("create.cancel")
      onClicked: root.cancel()
    }

    PillButton {
      primary: true
      busy: root.busy
      enabled: root.content.trim() !== "" && !root.busy
      text: root.tr("create.save")
      onClicked: {
        if (!root.mainInstance)
          return;
        root.busy = true;
        const name = root.filename.trim() || "snippet.txt";
        root.mainInstance.createGist(name, root.description, root.isPublic, root.content, function (ok) {
          root.busy = false;
          if (ok)
            root.created();
        });
      }
    }
  }
}
