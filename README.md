# Gistbar

A [Noctalia Shell](https://github.com/noctalia-dev/noctalia) plugin for the user's
GitHub gists: search, copy, create from the clipboard, preview, edit and delete,
through the `gh` CLI.

> [!IMPORTANT]
> Gistbar is a **Noctalia Shell v4** plugin (QML, `manifest.json`), tested on
> **noctalia-shell 4.7.7**. It does **not** run on Noctalia v5, whose plugin system
> is a different one (Luau scripts with a `plugin.toml` manifest). A v5 port is
> planned. See [Compatibility](#compatibility).

## Compatibility

| Noctalia | Status |
|----------|--------|
| v4 (`noctalia-shell` 4.7.x, run as `qs -c noctalia-shell`) | Supported, tested on 4.7.7 |
| v4 before 4.7 | Untested |
| v5 (`noctalia` 5.x) | Not supported: v5 plugins are written in Luau, so Gistbar would need a rewrite |

**v5 is planned.** I intend to port Gistbar to Noctalia v5 once I have it installed
and tested on my CachyOS setup. Until then, v4 is the only supported target.

On Arch/CachyOS the v4 shell is the `noctalia-shell` package and v5 is `noctalia`;
both can be installed side by side. Check the installed v4 version with
`pacman -Q noctalia-shell`, and make sure the bar you use is started with
`qs -c noctalia-shell`.

## Requirements

- noctalia-shell 4.7.x (see [Compatibility](#compatibility))
- `gh`, logged in with the `gist` scope (`gh auth login` and `gh auth refresh -s gist`)
- `wl-clipboard`, `xdg-utils`

~~~bash
sudo pacman -S --needed github-cli wl-clipboard xdg-utils
~~~

## Install

~~~bash
git clone https://github.com/nandomoreirame/noctalia-gistbar ~/dev/projects/noctalia-gistbar
ln -s ~/dev/projects/noctalia-gistbar ~/.config/noctalia/plugins/gistbar
~~~

Enable **Gistbar** in Noctalia Settings > Plugins, then add the **Gistbar** widget
to the bar.

## Shortcuts

IPC target `plugin:gistbar`:

~~~bash
qs -c noctalia-shell ipc call plugin:gistbar toggle
qs -c noctalia-shell ipc call plugin:gistbar create
~~~

niri (`~/.config/niri/config.kdl`):

~~~kdl
Mod+G hotkey-overlay-title="Gists" { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:gistbar" "toggle"; }
Mod+Ctrl+G hotkey-overlay-title="New gist from clipboard" { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:gistbar" "create"; }
~~~

## Cache and privacy

Gist contents are cached under `~/.cache/noctalia-gistbar/` (`list.json` plus one
`<id>.json` per gist). Files are written with mode `0600`. Secret gists are
included. **Clear cache** in the plugin settings deletes the downloaded contents;
they are fetched again on the next refresh. The plugin never reads or stores a
GitHub token: every call goes through `gh`.

## Development

~~~bash
npm install
npm test
~~~

Logic lives in `utils/**/*.js` (QML JavaScript libraries, tested with vitest through
a transform in `vitest.config.js`); QML files are thin UI. Manual checks:
[docs/SMOKE.md](docs/SMOKE.md).

## License

MIT.
