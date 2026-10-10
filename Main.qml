import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "utils/gists.js" as Gists
import "utils/gh.js" as Gh
import "utils/cachesync.js" as CacheSync

// Services for the gist list, the content cache and every gh / clipboard call.
// UI files read state from here and call these functions. Payloads go to stdin.
Item {
  id: root

  property var pluginApi: null
  readonly property var settings: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")) + "/noctalia-gistbar"

  property var gists: []
  property var contents: ({})
  property var cachedAt: ({})
  property var listState: ({ "syncing": false, "error": "", "stale": false, "fetchedAt": "" })
  property var queue: CacheSync.createQueue()
  property var pendingCopy: ({})
  property var callbacks: ({})
  property int nextToken: 1
  property int epoch: 0
  property bool listFromNetwork: false
  property string requestedMode: ""

  function setting(key) {
    const v = settings[key];
    return v === undefined ? defaults[key] : v;
  }

  function cacheDirOk() {
    return /\/noctalia-gistbar$/.test(cacheDir) && cacheDir.indexOf("..") < 0;
  }

  function isCachePath(path) {
    const p = String(path || "");
    return p.indexOf("..") < 0 && p.indexOf(cacheDir + "/") === 0;
  }

  function cacheFile(id) {
    if (!/^[0-9a-zA-Z]+$/.test(String(id)))
      return "";
    return cacheDir + "/" + id + ".json";
  }

  function toast(key) {
    ToastService.showNotice(pluginApi?.tr(key) ?? key, "", "check");
  }

  function takeCallback(token) {
    if (!token)
      return null;
    const cb = callbacks[String(token)];
    if (!cb)
      return null;
    const next = Object.assign({}, callbacks);
    delete next[String(token)];
    callbacks = next;
    return cb;
  }

  function spawn(command, opts) {
    const o = opts || {};
    let token = 0;
    if (o.done) {
      token = nextToken;
      nextToken = token + 1;
      const next = Object.assign({}, callbacks);
      next[String(token)] = o.done;
      callbacks = next;
    }
    const proc = runner.createObject(root, {
      command: command,
      kind: o.kind || "",
      gistId: o.gistId || "",
      token: token,
      epoch: epoch,
      payload: o.payload || "",
      sendStdin: !!o.stdin,
      meta: o.meta || null
    });
    if (!proc) {
      Logger.w("gistbar", "failed");
      const cb = takeCallback(token);
      if (cb)
        cb(false, "failed");
      return null;
    }
    if (o.stdin)
      proc.stdinEnabled = true;
    proc.running = true;
    return proc;
  }

  function writeJson(path, text) {
    if (!isCachePath(path))
      return;
    spawn(["install", "-m", "600", "/dev/stdin", path], { kind: "write", stdin: true, payload: String(text) });
  }

  function removeCached(id) {
    const contentsNext = Object.assign({}, contents);
    delete contentsNext[id];
    contents = contentsNext;
    const cachedNext = Object.assign({}, cachedAt);
    delete cachedNext[id];
    cachedAt = cachedNext;
    const path = cacheFile(id);
    if (path)
      spawn(["rm", "-f", path], { kind: "rm" });
  }

  function acceptEntry(entry) {
    if (!entry || !entry.id)
      return;
    const have = contents[entry.id];
    if (have && String(have.updatedAt) > String(entry.updatedAt || ""))
      return;
    const contentsNext = Object.assign({}, contents);
    contentsNext[entry.id] = entry;
    contents = contentsNext;
    const cachedNext = Object.assign({}, cachedAt);
    cachedNext[entry.id] = entry.updatedAt;
    cachedAt = cachedNext;
  }

  function replaceGist(gist) {
    if (!gist || !gist.id)
      return;
    let found = false;
    const next = gists.map(g => {
      if (g.id !== gist.id)
        return g;
      found = true;
      return gist;
    });
    gists = found ? next : Gists.prepend(gists, gist);
  }

  function clearPending(id) {
    if (!pendingCopy[id])
      return;
    const next = Object.assign({}, pendingCopy);
    delete next[id];
    pendingCopy = next;
  }

  function copyText(text) {
    spawn(["wl-copy"], {
      kind: "copy",
      stdin: true,
      payload: String(text === undefined || text === null ? "" : text)
    });
  }

  function copyGist(id) {
    const entry = contents[id];
    if (entry && entry.files && entry.files.length) {
      copyText(entry.files[0].content || "");
      toast("toast.copied");
      return;
    }
    const next = Object.assign({}, pendingCopy);
    next[id] = true;
    pendingCopy = next;
    queue = CacheSync.enqueue(queue, [id]);
    pump();
  }

  function copyLink(id) {
    const g = gists.find(x => x.id === id);
    const url = g ? String(g.url || "") : "";
    if (!/^https:\/\/gist\.github\.com\/\S+$/.test(url))
      return;
    copyText(url);
    toast("toast.link-copied");
  }

  function copyFile(id, index) {
    const entry = contents[id];
    if (!entry || !entry.files || !entry.files[index])
      return;
    copyText(entry.files[index].content || "");
    toast("toast.copied");
  }

  function openGist(id) {
    const g = gists.find(x => x.id === id);
    const url = g ? String(g.url || "") : "";
    if (!/^https:\/\/gist\.github\.com\/\S+$/.test(url)) {
      Logger.w("gistbar", "failed");
      return;
    }
    spawn(["xdg-open", url], { kind: "open" });
  }

  function ensureContent(id) {
    if (contents[id])
      return;
    queue = CacheSync.enqueue(queue, [id]);
    pump();
  }

  function refreshList() {
    if (listState.syncing)
      return;
    if (!cacheDirOk()) {
      Logger.w("gistbar", "failed");
      return;
    }
    listState = Object.assign({}, listState, { syncing: true });
    if (!spawn(Gh.listArgs(), { kind: "list" }))
      listState = Object.assign({}, listState, { syncing: false, stale: true, error: "failed" });
  }

  // Panel open refreshes when the last successful list is older than a minute.
  function onPanelOpened() {
    const at = Date.parse(listState.fetchedAt || "");
    if (!(at > 0) || (Date.now() - at) > 60000)
      refreshList();
  }

  function pump() {
    const r = CacheSync.nextJobs(queue, 2);
    queue = r.queue;
    for (const id of r.start)
      startDetail(id);
  }

  function startDetail(id) {
    let args;
    try {
      args = Gh.detailArgs(id);
    } catch (e) {
      queue = CacheSync.finish(queue, id);
      Logger.w("gistbar", "failed");
      return;
    }
    if (!spawn(args, { kind: "detail", gistId: id }))
      queue = CacheSync.finish(queue, id);
  }

  function deleteGist(id) {
    let args;
    try {
      args = Gh.deleteArgs(id);
    } catch (e) {
      Logger.w("gistbar", "failed");
      return;
    }
    spawn(args, { kind: "delete", gistId: id });
  }

  function createGist(filename, description, isPublic, content, done) {
    spawn(Gh.createArgs(filename, description, !!isPublic), {
      kind: "create",
      stdin: true,
      payload: String(content || ""),
      done: done,
      meta: {
        filename: String(filename || "snippet.txt"),
        description: String(description || ""),
        isPublic: !!isPublic,
        bytes: String(content || "").length
      }
    });
  }

  function saveGist(id, description, filename, content, done) {
    let args;
    let body;
    try {
      args = Gh.patchArgs(id);
      body = Gh.patchBody(description, filename, content);
    } catch (e) {
      Logger.w("gistbar", "failed");
      if (done)
        done(false, "failed");
      return;
    }
    spawn(args, { kind: "save", gistId: id, stdin: true, payload: body, done: done });
  }

  function clipboardText(done) {
    spawn(["wl-paste", "--no-newline", "--type", "text"], { kind: "paste", done: done });
  }

  function clearCache() {
    if (!cacheDirOk()) {
      Logger.w("gistbar", "failed");
      return;
    }
    epoch = epoch + 1;
    queue = CacheSync.createQueue();
    pendingCopy = ({});
    contents = ({});
    cachedAt = ({});
    listFromNetwork = false;
    listState = { syncing: false, error: "", stale: false, fetchedAt: "" };
    spawn(["rm", "-rf", cacheDir], { kind: "clear" });
  }

  function openCreate() {
    requestedMode = "create";
    if (pluginApi)
      pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen));
  }

  function openPreview(id) {
    if (!pluginApi)
      return;
    ensureContent(id);
    if (pluginApi.panelOpenScreen)
      pluginApi.closePanel(pluginApi.panelOpenScreen);
    pluginApi.withCurrentScreen(screen => previewWindow.openOn(screen, id));
  }

  function applyCacheText(path, text) {
    if (!isCachePath(path))
      return;
    const base = path.split("/").pop();
    let parsed;
    try {
      parsed = JSON.parse(String(text || ""));
    } catch (e) {
      Logger.w("gistbar", "parse");
      return;
    }
    if (base === "list.json") {
      if (listFromNetwork || !Array.isArray(parsed))
        return;
      gists = parsed;
      return;
    }
    if (parsed && parsed.id)
      acceptEntry(parsed);
  }

  function finishProcess(kind, gistId, token, procEpoch, code, stdout, stderr, meta) {
    const cb = takeCallback(token);
    if (procEpoch !== epoch) {
      if (kind === "paste" && cb)
        cb("");
      else if (cb)
        cb(false, "failed");
      return;
    }
    if (kind === "mkdir") {
      spawn(["find", cacheDir, "-maxdepth", "1", "-type", "f", "-name", "*.json"], { kind: "scan" });
      return;
    }
    if (kind === "mkdir-after-clear") {
      refreshList();
      return;
    }
    if (kind === "clear") {
      if (code !== 0)
        Logger.w("gistbar", "failed");
      spawn(["mkdir", "-p", cacheDir], { kind: "mkdir-after-clear" });
      return;
    }
    if (kind === "scan") {
      if (code !== 0) {
        Logger.w("gistbar", "failed");
        return;
      }
      for (const line of String(stdout || "").split("\n")) {
        const path = line.trim();
        if (isCachePath(path))
          spawn(["cat", path], { kind: "read", meta: { path: path } });
      }
      return;
    }
    if (kind === "read") {
      if (code === 0 && meta && meta.path)
        applyCacheText(meta.path, stdout);
      return;
    }
    if (kind === "list") {
      const err = Gh.classify(code, stderr);
      if (err) {
        listState = Object.assign({}, listState, { syncing: false, stale: true, error: err });
        Logger.w("gistbar", err);
        return;
      }
      const parsed = Gists.parseList(stdout);
      if (!parsed.ok) {
        listState = Object.assign({}, listState, { syncing: false, stale: true, error: "failed" });
        Logger.w("gistbar", "parse");
        return;
      }
      gists = parsed.gists;
      listFromNetwork = true;
      listState = { syncing: false, error: "", stale: false, fetchedAt: new Date().toISOString() };
      writeJson(cacheDir + "/list.json", JSON.stringify(gists));
      const planned = CacheSync.plan(gists, cachedAt);
      for (const id of planned.drop)
        removeCached(id);
      queue = CacheSync.enqueue(queue, planned.fetch);
      pump();
      return;
    }
    if (kind === "detail") {
      queue = CacheSync.finish(queue, gistId);
      const err = Gh.classify(code, stderr);
      if (!err) {
        const parsed = Gists.parseDetail(stdout);
        if (parsed.ok) {
          acceptEntry(parsed.entry);
          writeJson(cacheFile(parsed.entry.id), JSON.stringify(parsed.entry));
          if (pendingCopy[gistId]) {
            clearPending(gistId);
            const file = parsed.entry.files && parsed.entry.files[0];
            copyText(file ? file.content || "" : "");
            toast("toast.copied");
          }
        } else {
          Logger.w("gistbar", "parse");
          clearPending(gistId);
        }
      } else {
        Logger.w("gistbar", err);
        if (pendingCopy[gistId]) {
          clearPending(gistId);
          toast("toast.failed");
        }
      }
      pump();
      return;
    }
    if (kind === "delete") {
      const err = Gh.classify(code, stderr);
      if (err) {
        Logger.w("gistbar", err);
        toast("toast.failed");
        return;
      }
      gists = Gists.remove(gists, gistId);
      removeCached(gistId);
      writeJson(cacheDir + "/list.json", JSON.stringify(gists));
      toast("toast.deleted");
      if (previewWindow.visible && previewWindow.gistId === gistId)
        previewWindow.closeWindow(false);
      return;
    }
    if (kind === "create") {
      const err = Gh.classify(code, stderr);
      const id = Gh.createdId(stdout);
      if (err || !id) {
        Logger.w("gistbar", err || "failed");
        if (cb)
          cb(false, err || "failed");
        return;
      }
      const url = String(stdout || "").trim().split("\n")[0];
      if (/^https:\/\/gist\.github\.com\/\S+$/.test(url))
        copyText(url);
      toast("toast.created");
      const info = meta || {};
      gists = Gists.prepend(gists, {
        id: id,
        url: url,
        description: String(info.description || ""),
        public: !!info.isPublic,
        updatedAt: new Date().toISOString(),
        files: [{ name: String(info.filename || "snippet.txt"), language: "", size: Number(info.bytes) || 0 }]
      });
      writeJson(cacheDir + "/list.json", JSON.stringify(gists));
      queue = CacheSync.enqueue(queue, [id]);
      pump();
      if (cb)
        cb(true, "");
      return;
    }
    if (kind === "save") {
      const err = Gh.classify(code, stderr);
      if (err) {
        Logger.w("gistbar", err);
        if (cb)
          cb(false, err);
        return;
      }
      const parsed = Gists.parseDetail(stdout);
      if (!parsed.ok) {
        Logger.w("gistbar", "parse");
        if (cb)
          cb(false, "failed");
        return;
      }
      acceptEntry(parsed.entry);
      replaceGist(parsed.gist);
      writeJson(cacheFile(parsed.entry.id), JSON.stringify(parsed.entry));
      writeJson(cacheDir + "/list.json", JSON.stringify(gists));
      toast("toast.saved");
      if (cb)
        cb(true, "");
      return;
    }
    if (kind === "paste") {
      if (cb)
        cb(code === 0 ? String(stdout || "") : "");
      return;
    }
    if (kind === "copy" && code !== 0) {
      Logger.w("gistbar", "failed");
      toast("toast.failed");
      return;
    }
    if ((kind === "write" || kind === "rm" || kind === "open") && code !== 0)
      Logger.w("gistbar", "failed");
  }

  Component.onCompleted: {
    if (cacheDirOk())
      spawn(["mkdir", "-p", cacheDir], { kind: "mkdir" });
    else
      Logger.w("gistbar", "failed");
  }

  Timer {
    interval: Math.max(5, Number(root.setting("listMinutes")) || 15) * 60000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshList()
  }

  IpcHandler {
    target: "plugin:gistbar"

    function toggle(): void {
      if (root.pluginApi)
        root.pluginApi.withCurrentScreen(screen => root.pluginApi.togglePanel(screen));
    }

    function create(): void {
      root.openCreate();
    }
  }

  PreviewWindow {
    id: previewWindow
    pluginApi: root.pluginApi
    mainInstance: root
  }

  Component {
    id: runner
    Process {
      property string kind: ""
      property string gistId: ""
      property int token: 0
      property int epoch: 0
      property string payload: ""
      property bool sendStdin: false
      property var meta: null
      stdout: StdioCollector {
        id: stdOut
        waitForEnd: true
      }
      stderr: StdioCollector {
        id: stdErr
        waitForEnd: true
      }
      onStarted: {
        if (sendStdin) {
          write(payload);
          stdinEnabled = false;
        }
      }
      onExited: function (exitCode) {
        root.finishProcess(kind, gistId, token, epoch, exitCode, stdOut.text, stdErr.text, meta);
        destroy();
      }
    }
  }
}
