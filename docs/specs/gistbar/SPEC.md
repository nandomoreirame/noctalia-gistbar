# SPEC: gistbar

**Status:** approved (2026-10-10) · **Depth:** Deep (15 REQs) · **Repo:** `noctalia-gistbar`

## Summary

`gistbar` is a personal Noctalia Shell v4 plugin (QML, run as `qs -c noctalia-shell`)
for the user's GitHub gists: search them (description, file names, language and
content), copy and use them, create a new gist from the clipboard, preview, edit and
delete. It follows the Daybar architecture and look: pure `utils/**/*.js` QML
libraries tested with vitest, services in `Main.qml`, thin views, and a copy of
Daybar's `components/ui/` kit with the same fine-tuning (pointer cursor on clickable
rows, italic dimmed empty states, confirmation bubble, counts on chips).

All GitHub access goes through the `gh` CLI: the plugin never handles a token.

## Goals

- Find any gist in seconds by typing, then copy its content or link without the
  mouse (`Mod+G`, type, Enter).
- Turn what is in the clipboard into a (secret by default) gist in one short form.
- Fix a gist's description or a file's content without opening the browser.

## Non-goals (out of scope)

- Adding/removing files of an existing gist, changing visibility, stars, forks,
  comments. A Noctalia launcher provider (possible later).
- Other users' gists. Noctalia v5.

## Grilling Log

| # | Decision | Resolution | Rationale |
|---|----------|------------|-----------|
| 1 | Where it lives | Separate plugin `noctalia-gistbar`, id `gistbar` | Own domain, cache and shortcut; publishable alone |
| 2 | UI kit | Copy Daybar's `components/ui/` (also into `noctalia-aibar`) | No shared-module mechanism between plugins; simplest |
| 3 | GitHub access | `gh` CLI only; content/JSON through stdin | No token handling; argv carries ids and short text only |
| 4 | Surface | Bar panel, search focused, no tabs; "New from clipboard" in the header | Fits a list + preview; same pattern as Daybar |
| 5 | Search scope | Description, file names, language, content; accent-insensitive; description/name rank above content | Content is why gists exist |
| 6 | Cache | List every 15 min and on panel open; contents in `~/.cache/noctalia-gistbar/<id>.json` (0600), refetched only when `updated_at` changes; clear-cache button | ~300 KB once, then near zero |
| 7 | Create | Form prefilled from clipboard, suggested filename, secret by default, `gh gist create ... -`, link to clipboard + toast | Publishing by mistake is the worst failure |
| 8 | Actions | Enter copies first file, Shift+Enter copies link; row: copy, link, browser, delete (confirm) | Keyboard-first copy flow |
| 9 | Preview/edit | Note-window pattern: one tab per file, selectable text, Markdown via mdrender, Ctrl+E edit description + current file, Ctrl+S saves via `gh api PATCH` (stdin) | `gh gist edit` only reads content from a local file |
| 10 | List | `updated_at` desc; chips All / Public / Secret with counts; language chip per row, not a filter | Most recent work on top |
| 11 | Bar | `brand-github` icon only; tooltip total + last sync; pulses while syncing; error color when `gh` is not logged in | No number worth the space |
| 12 | Shortcuts | `Mod+G` → `toggle`, `Mod+Ctrl+G` → `create`; middle click → create form | Both free in the user's niri config |

## Verified Claims

| # | Claim | Evidence |
|---|-------|----------|
| V1 | `gh` 2.102 logged in as the user with scope `gist` | `gh auth status`, 2026-10-10 |
| V2 | The user has 95 gists: 70 public, 25 secret, 14 multi-file, avg ~3 KB, max ~69 KB | `gh api gists --paginate`, 2026-10-10 |
| V3 | List items (`GET gists`) carry `id, html_url, description (nullable), public, updated_at, files{ name: { filename, language, size, raw_url, type } }` but **no content** | `gh api 'gists?per_page=1'` keys; `tests/fixtures/gists-list.json` (shape copy, fake data) |
| V4 | Detail (`GET gists/<id>`) adds `files.*.content` and `files.*.truncated` | `gh api gists/<id>` keys; `tests/fixtures/gist-detail.json` |
| V5 | `gh api <ep> --paginate --slurp` prints one JSON array of pages (`[[...],[...]]`); `--slurp` cannot be combined with `--jq` | `gh api --help` |
| V6 | `gh gist create -` reads content from stdin with `--filename`, `--desc`, `--public` (default secret) and prints the gist URL | `gh gist create --help` |
| V7 | `gh gist edit` replaces a file only from a local file path, so edits use `gh api --method PATCH gists/<id> --input -` with the JSON body on stdin | `gh gist edit --help`, `gh api --help` |
| V8 | Quickshell `Process` with `stdinEnabled: true`, `write(text)` then `stdinEnabled = false` delivers the text and EOF (70 000 bytes tested) | live test with `wc -c`, 2026-10-10 |
| V9 | `Mod+G` and `Mod+Ctrl+G` are unused in `~/.dotfiles/configs/niri/config.kdl` (`Mod+Shift+G`, `Mod+Alt+G` are taken) | grep of the config |
| V10 | Daybar has the reusable pieces: `utils/text.js` (`fold`, `matches`), `utils/mdrender.js` + `utils/markdown.js`, `components/ui/*` | Daybar repo |
| V11 | Daybar's `copyText` passes text in argv to `wl-copy`; gist contents (secret, up to 69 KB) must go through stdin instead | `noctalia-daybar/Main.qml` `copyText` |

## Requirements

### Data

- **REQ-001** The system SHALL list gists with `gh api gists?per_page=100 --paginate
  --slurp`, flatten the pages, normalize each item to `{ id, url, description,
  public, updatedAt, files: [{ name, language, size }] }` and sort by `updatedAt`
  descending. It SHALL refresh on startup, every `listMinutes` (default 15) and
  when the panel opens if the last refresh is older than 1 minute.
- **REQ-002** WHEN a listed gist has no cache entry or its `updatedAt` differs from
  the cached one THEN the system SHALL fetch `gh api gists/<id>` in the background
  (at most 2 at a time), store `{ id, updatedAt, files: [{ name, language,
  content, truncated }] }` in `~/.cache/noctalia-gistbar/<id>.json` with mode 0600,
  and delete cache files of gists no longer listed. A settings button SHALL clear
  the whole cache.
- **REQ-003** WHEN `gh` is missing or not logged in (non-zero exit with an auth
  message) THEN the system SHALL show state `auth` with `error.gh-login` in the
  panel and an error-colored bar icon; network failures SHALL keep the last list
  and mark it stale.

### Search and list

- **REQ-004** The search SHALL be accent- and case-insensitive (Daybar's
  `fold`), match every whitespace-separated term, and rank: description or file
  name match first, language next, content-only last; ties keep `updatedAt` order.
  Empty query shows the whole (filtered) list.
- **REQ-005** Chips All / Public / Secret SHALL filter the list and show their
  counts (`Secretos (25)`); the active chip combines with the search.
- **REQ-006** Each row SHALL show the description (or the first file name when
  empty), the file names, a language chip, the relative update time and a lock
  icon for secret gists; rows have a pointer cursor and hover/Tab actions.

### Actions

- **REQ-007** Enter on a row (or the focused search with results) SHALL copy the
  content of the gist's first file to the clipboard through `wl-copy` **stdin**,
  close the panel and show a toast; Shift+Enter SHALL copy the gist URL. Row
  actions: copy content, copy link, open in browser (`xdg-open`), delete.
- **REQ-008** Delete SHALL ask with the confirmation bubble and run `gh gist
  delete <id> --yes`; on success the row disappears and its cache file is removed.
- **REQ-009** Copy before the content is cached SHALL fetch the detail first and
  copy when it arrives (the row shows a busy state).

### Create

- **REQ-010** "New from clipboard" (header button, middle click, `ipc create`) SHALL
  open a form with the clipboard text (`wl-paste --no-newline`), a suggested
  filename (REQ-011), an empty description and a Public toggle **off**. Save SHALL
  run `gh gist create --filename <name> --desc <desc> [--public] -` with the
  content on stdin, copy the printed URL, show a toast and put the new gist at the
  top of the list without waiting for the next refresh. Empty clipboard or empty
  content SHALL disable Save.
- **REQ-011** Filename suggestion SHALL be: shebang → `script.<sh|py|js|rb>` by
  interpreter; valid JSON object/array → `data.json`; leading Markdown heading or
  list → `notes.md`; leading `<` tag → `snippet.html`; else `snippet.txt`.

### Preview and edit

- **REQ-012** Clicking a row SHALL open a preview window (Daybar note-window
  pattern): title = description, one tab per file, selectable text; Markdown
  files rendered with `mdrender`, others in the fixed font; copy button per tab.
- **REQ-013** Ctrl+E SHALL switch the window to edit mode (description field +
  the current tab's content); Ctrl+S SHALL send `gh api --method PATCH
  gists/<id> --input -` with `{ description, files: { <name>: { content } } }` on
  stdin, update the cache entry and the list on success, and show the error
  without losing the edits on failure. Esc closes (asks to discard unsaved edits).

### Bar, shortcuts, i18n

- **REQ-014** The bar widget SHALL be the `brand-github` icon with a tooltip
  (`N gists · atualizado há N min`), pulse while syncing, use the error color in
  state `auth`; left click toggles the panel, middle click opens the create form.
  IPC target `plugin:gistbar` with `toggle()` and `create()` (`new` is a reserved word); README documents the
  `Mod+G` / `Mod+Ctrl+G` niri binds.
- **REQ-015** All UI strings SHALL go through `pluginApi.tr` with `i18n/pt.json`
  and `i18n/en.json` in sync (coverage test).

## Architecture Decisions

- **AD-001 Pure core.** `utils/gists.js` (normalize list/detail, sort, merge a
  created gist), `utils/search.js` (rank + filter + counts), `utils/text.js`
  (copied from Daybar), `utils/filename.js`, `utils/gh.js` (argv builders, PATCH
  body, create-output parsing, error classification), `utils/cachesync.js` (which
  ids to fetch / delete, queue with concurrency 2), `utils/format.js` (relative
  time). Copied as-is from Daybar: `utils/mdrender.js`, `utils/markdown.js`.
- **AD-002 gh only, stdin for payloads.** No token in the plugin. Content, JSON
  bodies and clipboard writes go through `Process.write` + EOF (V8), never argv.
- **AD-003 Cache as files, list in memory.** One JSON file per gist under
  `~/.cache/noctalia-gistbar/` (created with `mkdir -p` and files chmod 600 through
  `install -m 600 /dev/stdin <path>`); the list itself lives in memory and in
  `list.json` in the same directory for an instant first paint.
- **AD-004 Daybar UI kit copy.** `components/ui/` copied from Daybar at
  implementation time (same files, same fine-tuning). No shared module.

## Edge Cases

- A file with `truncated: true` (> 1 MB) is shown with a note and copied from its
  `raw_url` via `gh api` raw (out of scope to optimize; rare).
- A gist with no description: the first file name is the title.
- The clipboard holds an image or binary data: `wl-paste --type text` fails →
  the form opens empty with a hint.
- Two quick refreshes: list refresh never overlaps itself.
- Editing a gist that changed remotely meanwhile: the PATCH wins (last write);
  the list refresh after it shows the new state.
- Deleting the gist currently open in the preview closes the preview.

## Traceability

| REQ | Plan tasks |
|-----|-----------|
| REQ-001 | T4, T11 |
| REQ-002 | T8, T11 |
| REQ-003 | T7, T11, T13 |
| REQ-004, REQ-005 | T3, T5 |
| REQ-006 | T13 |
| REQ-007, REQ-008, REQ-009 | T7, T11, T13 |
| REQ-010, REQ-011 | T6, T7, T14 |
| REQ-012, REQ-013 | T7, T15 |
| REQ-014 | T12, T16 |
| REQ-015 | T2 |
