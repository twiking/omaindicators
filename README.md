# OmaIndicators

An [Omarchy](https://omarchy.org) shell plugin: the indicators, but you pick them from the bar.

The built-in `omarchy.indicators` widget decides its set in `shell.json` and only reveals
the inactive ones on hover. OmaIndicators puts a button in the bar instead — press it and a
window opens listing every indicator with a switch. Whatever is switched on is rendered in
the bar right beside the button, and stays there whether or not it is currently active.

Indicators available:

| Indicator | What it shows |
| --- | --- |
| Dictation | Voice typing status |
| Screen recording | GPU screen recorder status |
| Reminder | Queued reminder status |
| Night light | Blue-light filter |
| Do not disturb | Notification silencing |
| Stay awake | Idle lock and screensaver override |

Each one keeps its stock behaviour, including its click action — pressing the night light
indicator still toggles night light.

## Install

```bash
omarchy plugin add https://github.com/twiking/omaindicators --enable
```

Or from a checkout:

```bash
git clone https://github.com/twiking/omaindicators ~/.config/omarchy/plugins/io.github.twiking.omaindicators
omarchy plugin enable io.github.twiking.omaindicators
```

## Settings

One widget setting, in the bar widget editor:

- **Descriptions in the toggle window** — show the one-line description under each
  indicator name. On by default.

The selection itself is not a widget setting; it is the widget's own state, persisted to
`$XDG_STATE_HOME/omaindicators/state.json` (`~/.local/state/omaindicators/state.json`), so
it survives a shell restart without editing any config by hand.

## IPC

```bash
omarchy-shell io.github.twiking.omaindicators toggle    # open/close the window
omarchy-shell io.github.twiking.omaindicators open
omarchy-shell io.github.twiking.omaindicators close
omarchy-shell io.github.twiking.omaindicators refresh   # re-poll the indicators

# Flip one indicator without opening the window — bind it, or restore a
# selection from a setup script. Unknown ids are ignored.
omarchy-shell io.github.twiking.omaindicators setIndicator NightLight true
omarchy-shell io.github.twiking.omaindicators setIndicator Dnd false
```

`toggle` is the one worth binding to a key.

## Development

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell -I /usr/lib/qt6/qml BarWidget.qml indicators/*.qml
```

Both import paths are needed — the shell for `qs.Ui` / `qs.Commons`, `/usr/lib/qt6/qml`
for `Quickshell`. Note that qmllint 1.0 exits 255 without printing anything on any file
carrying a typed `IpcHandler` function, including Omarchy's own `shell.qml`; check the
printed warnings, not the exit code.

See the [plugin development guide](https://omarchyplugins.com/develop.html).

## Credits

The files in `indicators/` are the stock Omarchy indicator implementations, vendored from
`/usr/share/omarchy/shell/plugins/bar/indicators` so the plugin is self-contained.
Omarchy is MIT-licensed, © Basecamp.

## License

MIT
