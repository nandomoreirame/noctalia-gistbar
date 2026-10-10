.pragma library

// gh api JSON -> normalized gists. List items have no content; details do.

function filesOf(files, withContent) {
  return Object.keys(files || {}).map((k) => {
    const f = files[k] || {};
    const base = { name: String(f.filename || k), language: String(f.language || "") };
    if (withContent) return Object.assign(base, { content: String(f.content || ""), truncated: !!f.truncated });
    return Object.assign(base, { size: Number(f.size) || 0 });
  });
}

function normalize(g) {
  return {
    id: String(g.id),
    url: String(g.html_url || ""),
    description: String(g.description || ""),
    public: !!g.public,
    updatedAt: String(g.updated_at || ""),
    files: filesOf(g.files, false)
  };
}

function byUpdatedDesc(a, b) {
  return a.updatedAt < b.updatedAt ? 1 : a.updatedAt > b.updatedAt ? -1 : 0;
}

// `gh api gists --paginate --slurp` -> [[page], [page]]; a plain page also works.
function parseList(text) {
  let o;
  try {
    o = JSON.parse(String(text || ""));
  } catch (e) {
    return { ok: false, error: "parse" };
  }
  if (!Array.isArray(o)) return { ok: false, error: "parse" };
  const items = o.length > 0 && Array.isArray(o[0]) ? [].concat.apply([], o) : o;
  const gists = items.filter((g) => g && g.id !== undefined && g.id !== null).map(normalize);
  gists.sort(byUpdatedDesc);
  return { ok: true, gists: gists };
}

function parseDetail(text) {
  let g;
  try {
    g = JSON.parse(String(text || ""));
  } catch (e) {
    return { ok: false, error: "parse" };
  }
  if (!g || !g.id) return { ok: false, error: "parse" };
  return { ok: true, gist: normalize(g), entry: { id: String(g.id), updatedAt: String(g.updated_at || ""), files: filesOf(g.files, true) } };
}

function title(g) {
  return g.description || (g.files[0] ? g.files[0].name : g.id);
}

function prepend(list, gist) {
  return [gist].concat(list.filter((g) => g.id !== gist.id));
}

function remove(list, id) {
  return list.filter((g) => g.id !== id);
}
