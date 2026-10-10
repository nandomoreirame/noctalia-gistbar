# Smoke test (manual)

Run after `npm test` is green, with the plugin symlinked and enabled. Watch the shell
log in another terminal: `qs log -c noctalia-shell -f | grep -i gistbar`.
Any `gistbar` error or `ReferenceError`/`TypeError` fails the run. The log must not
contain gist contents.

| # | REQ | Step | Expected |
|---|-----|------|----------|
| 1 | REQ-001 | Reload the shell, then open the panel | List appears, newest gist first; opening again within a minute does not refetch |
| 2 | REQ-002 | Delete one cache file under `~/.cache/noctalia-gistbar/`, then refresh | That gist is fetched again; other unchanged files stay; removed gists disappear from the cache |
| 3 | REQ-003 | `gh` logged out (or missing) | Panel shows the auth message with `gh auth login` in a code chip; the bar icon uses the error color; the last list stays on a network failure and reads as stale |
| 4 | REQ-004 | Search `ação` and `Docker CLEAN` | Accents and case fold; every word must match; a name hit ranks above a content-only hit |
| 5 | REQ-005 | Click Secret, then All | The chip shows its count (`Secretos (N)` / `Secret (N)`) and the list filters; search still applies |
| 6 | REQ-006 | Look at a secret gist with no description | Title is the first file name, file names are dim, a language chip and a relative time show, and a lock icon is present; the row uses a pointer cursor |
| 7 | REQ-007 | Focus the search, press Enter, then Shift+Enter on another gist | Enter copies the first file via the clipboard and closes the panel with a toast; Shift+Enter copies the gist URL |
| 8 | REQ-008 | Delete a gist and confirm | The row disappears and its cache file is removed |
| 9 | REQ-009 | Copy a gist whose `<id>.json` is missing | The row stays busy, then the content is copied when the detail arrives |
| 10 | REQ-010 | Copy a shell script, `Mod+Ctrl+G` | Form opens with the clipboard text, filename `script.sh`, Public off, secret gist created, URL in the clipboard, new row on top |
| 11 | REQ-011 | Clipboard is JSON, then a Markdown list, then plain text | Suggested names are `data.json`, `notes.md` and `snippet.txt` until the name is edited |
| 12 | REQ-012 | Click a gist with two files, one of them Markdown | Preview opens (the bar panel closes), one tab per file, Markdown is rendered, other files use the fixed font, text is selectable |
| 13 | REQ-013 | Edit a file, Ctrl+S, then look at the gist in the browser; Esc with unsaved edits | The browser shows the change; a failed save keeps the edits and shows an error; Esc asks before discarding |
| 14 | REQ-014 | Hover the bar icon; left click; middle click | Tooltip is `{n} gists · {when}` and pulses while syncing; left click toggles the panel; middle click opens the create form |
| 15 | REQ-015 | Switch Noctalia's language between pt and en | Every label comes from the catalog; no raw key is shown |
