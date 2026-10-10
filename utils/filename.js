.pragma library

var SHEBANG = [[/\b(bash|sh|zsh)\b/, "sh"], [/\bpython/, "py"], [/\bnode\b/, "js"], [/\bruby\b/, "rb"]];

function suggestName(text) {
  const s = String(text || "").trim();
  if (s.indexOf("#!") === 0) {
    const first = s.split("\n")[0];
    for (const [re, ext] of SHEBANG) if (re.test(first)) return "script." + ext;
    return "script.sh";
  }
  if (s.charAt(0) === "{" || s.charAt(0) === "[") {
    try {
      JSON.parse(s);
      return "data.json";
    } catch (e) {}
  }
  if (/^(#{1,6}\s|[-*]\s)/.test(s)) return "notes.md";
  if (/^<[a-zA-Z!]/.test(s)) return "snippet.html";
  return "snippet.txt";
}
