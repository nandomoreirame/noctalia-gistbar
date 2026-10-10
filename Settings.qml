import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "components/ui"

// Plugin settings. Noctalia calls saveSettings() when the dialog is confirmed.
ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance ?? null
  property int listMinutes: 15

  spacing: Style.marginM

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : key;
  }

  function value(key) {
    const s = pluginApi?.pluginSettings ?? {};
    const d = pluginApi?.manifest?.metadata?.defaultSettings ?? {};
    return s[key] === undefined ? d[key] : s[key];
  }

  function loadSettings() {
    const mins = Number(value("listMinutes"));
    listMinutes = mins >= 5 && mins <= 120 ? mins : 15;
  }

  function saveSettings() {
    if (!pluginApi)
      return;
    const s = pluginApi.pluginSettings;
    s.listMinutes = listMinutes;
    pluginApi.saveSettings();
  }

  onPluginApiChanged: if (pluginApi) loadSettings()
  Component.onCompleted: if (pluginApi) loadSettings()

  NSpinBox {
    label: root.tr("settings.list-minutes")
    from: 5
    to: 120
    value: root.listMinutes
    suffix: " min"
    onValueChanged: root.listMinutes = value
  }

  NText {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: root.tr("settings.clear-cache-desc")
    pointSize: Style.fontSizeS
    color: Qt.alpha(Color.mOnSurface, 0.7)
  }

  PillButton {
    danger: true
    icon: "trash"
    text: root.tr("settings.clear-cache")
    onClicked: root.mainInstance?.clearCache()
  }
}
