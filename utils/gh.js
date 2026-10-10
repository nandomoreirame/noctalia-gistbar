.pragma library

// argv builders for the gh CLI. Payloads (content, JSON) always go on stdin.

var ID = /^[0-9a-zA-Z]+$/;

function checkId(id) {
  if (!ID.test(String(id))) throw new Error("invalid gist id");
  return String(id);
}

function listArgs() {
  return ["gh", "api", "gists?per_page=100", "--paginate", "--slurp"];
}

function detailArgs(id) {
  return ["gh", "api", "gists/" + checkId(id)];
}

function deleteArgs(id) {
  return ["gh", "gist", "delete", checkId(id), "--yes"];
}

function createArgs(filename, description, isPublic) {
  const args = ["gh", "gist", "create", "--filename", String(filename), "--desc", String(description || "")];
  if (isPublic) args.push("--public");
  args.push("-");
  return args;
}

function patchArgs(id) {
  return ["gh", "api", "--method", "PATCH", "gists/" + checkId(id), "--input", "-"];
}

function patchBody(description, filename, content) {
  const files = {};
  files[filename] = { content: String(content) };
  return JSON.stringify({ description: String(description || ""), files: files });
}

// `gh gist create` prints the gist URL on stdout.
function createdId(stdout) {
  const m = /gist\.github\.com\/[^/\s]+\/([0-9a-zA-Z]+)/.exec(String(stdout || ""));
  return m ? m[1] : "";
}

// exit code + stderr -> "" | "gh-login" | "gh-missing" | "network" | "failed"
function classify(code, stderr) {
  if (code === 0) return "";
  const e = String(stderr || "");
  if (code === 127) return "gh-missing";
  if (code === 4 || /gh auth login|HTTP 401|Bad credentials/i.test(e)) return "gh-login";
  if (/error connecting|timeout|could not resolve|network/i.test(e)) return "network";
  return "failed";
}
