# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

Pre-implementation: only docs and fixtures exist until plan task T1. Source of truth:

- Spec: `docs/specs/gistbar/SPEC.md` (REQ-001..015, grilling log, verified claims)
- Plan: `docs/plans/2026-10-10-gistbar.md` (16 TDD tasks with file contents and batches)
- State: `docs/specs/gistbar/STATE.md` (next step: `/rpi:implement gistbar`)

## What it is

`gistbar` is a personal Noctalia Shell **v4** plugin (QML, run as `qs -c noctalia-shell`)
for the user's GitHub gists: search (description, file names, language, content), copy,
create from the clipboard, preview, edit and delete. Noctalia v5 is not a target.
Sibling and architecture/look reference: `~/dev/projects/noctalia-daybar`
(`vitest.config.js`, `components/ui/`, `utils/text.js`, `utils/mdrender.js`,
`utils/markdown.js`, `utils/url.js` are copied from it in T1).

## Commands

```bash
npm install
npm test                          # full vitest suite
npm test -- tests/search.test.js  # single file
```

Read the `Tests  N passed` line; never trust the exit code of a piped command.

## Architecture

- `utils/**/*.js`: all logic as QML JavaScript libraries (`.pragma library`, `.import`,
  top-level declarations at column 0 so the vitest transform exports them). Modules:
  `gists` (normalize list/detail), `search` (rank/filter/counts), `filename`, `gh` (argv
  builders, PATCH body, error classification), `cachesync` (fetch/drop plan, queue of 2),
  `format` (relative time).
- QML (`Main.qml`, `BarWidget.qml`, `Panel.qml`, `PreviewWindow.qml`, `Settings.qml`,
  `components/`): I/O and rendering only; services live in `Main.qml`.
- Cache: `~/.cache/noctalia-gistbar/list.json` + `<id>.json` (mode 0600), refetched only
  when a gist's `updated_at` changes.

## Hard constraints

- GitHub access only through the `gh` CLI; the plugin never reads or stores a token.
- Every command is an argv array. Gist content, JSON bodies and clipboard writes go
  through `Process.write()` then `stdinEnabled = false` (EOF), never argv (secret gists,
  up to ~69 KB).
- New gists are secret unless the user turns Public on.
- No `eval`/`Function`. UI strings through `pluginApi?.tr()` with `i18n/pt.json` and
  `i18n/en.json` in sync (a coverage test enforces it).
- Never write absolute home paths (`/home/...`) in files: a global pre-commit hook
  rejects them. Use `/data/u` in fixtures.
