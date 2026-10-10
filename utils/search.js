.pragma library
.import "text.js" as Text

// Rank: 0 = description or file name, 1 = language, 2 = content only.
function rank(g, entry, query) {
  const names = [g.description].concat(g.files.map((f) => f.name));
  if (Text.matches(names, query)) return 0;
  const langs = names.concat(g.files.map((f) => f.language));
  if (Text.matches(langs, query)) return 1;
  const body = entry ? entry.files.map((f) => f.content) : [];
  return Text.matches(langs.concat(body), query) ? 2 : -1;
}

function visible(g, filter) {
  return filter === "public" ? g.public : filter === "secret" ? !g.public : true;
}

// gists are already sorted by updatedAt desc; the sort below is stable.
function search(gists, contents, query, filter) {
  const pool = gists.filter((g) => visible(g, filter));
  if (String(query || "").trim() === "") return pool;
  return pool
    .map((g, i) => ({ g: g, i: i, r: rank(g, (contents || {})[g.id], query) }))
    .filter((x) => x.r >= 0)
    .sort((a, b) => a.r - b.r || a.i - b.i)
    .map((x) => x.g);
}

function counts(gists) {
  const pub = gists.filter((g) => g.public).length;
  return { all: gists.length, public: pub, secret: gists.length - pub };
}
