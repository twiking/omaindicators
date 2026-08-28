# OmaIndicators

An [Omarchy](https://omarchy.org) shell plugin: every indicator behind one bar icon.

The built-in `omarchy.indicators` widget spreads its set along the bar and only reveals the
idle ones on hover. OmaIndicators makes the opposite trade — **one icon**, and a panel that
lists every indicator with a switch. Each switch shows that indicator's live state, and
flipping it performs the indicator's own action: the night light switch toggles night
light, the recording switch starts and stops the recorder.

When indicators are active, a badge above the icon counts them, so the bar reports how much
is running without spending any extra width on it. The badge sits over the glyph rather
than beside it — widening the slot would shove the whole right section sideways every time
an indicator came on — and takes the theme's bar-active colour, so it works on light
themes too. The glyph itself only highlights while the panel is open.

The panel is split by what pressing an indicator actually does.

**Switches** — these flip their own state, so a switch is an honest control:

| Indicator | Switch does |
| --- | --- |
| Night light | Toggles the blue-light filter |
| Do not disturb | Silences and unsilences notifications |
| Stay awake | Overrides idle lock and screensaver |
| Dictation | Opens voice typing config; shows recording/transcribing |

**Actions**, at the bottom — these perform something rather than holding a state, so a
switch would promise a state the row does not own. They are buttons, labelled with the
action they will perform and lit while the underlying thing is running:

| Action | Button does |
| --- | --- |
| Reminder | Shows the queue, or starts a new reminder |
| Screen recording | Starts, and stops, the GPU screen recorder |

## Install

```bash
omarchy plugin add https://github.com/twiking/omaindicators --enable
```

Or from a checkout:

```bash
git clone https://github.com/twiking/omaindicators ~/.config/omarchy/plugins/io.github.twiking.omaindicators
omarchy plugin enable io.github.twiking.omaindicators right
```

## Settings

One widget setting, in the bar widget editor:

- **Descriptions in the panel** — show the one-line description under each indicator name.
  On by default.

There is nothing else to configure: the panel always lists every indicator, and each one's
state lives where it always did, with the service that owns it.

## Keyboard

The panel takes focus when it opens. Up/down move the cursor, Enter or Space flips the
switch under it, Tab hands off to the next bar panel, Esc closes.

## IPC

```bash
omarchy-shell io.github.twiking.omaindicators toggle    # open/close the panel
omarchy-shell io.github.twiking.omaindicators open
omarchy-shell io.github.twiking.omaindicators close
omarchy-shell io.github.twiking.omaindicators refresh   # re-poll the indicators

# Flip one indicator without opening the panel — the same action its switch
# performs, bindable to a key. Unknown ids are ignored with a warning.
omarchy-shell io.github.twiking.omaindicators press NightLight
omarchy-shell io.github.twiking.omaindicators press Dnd
```

`toggle` is the one worth binding to a key.

## Development

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell -I /usr/lib/qt6/qml BarWidget.qml indicators/*.qml
```

Both import paths are needed — the shell for `qs.Ui` / `qs.Commons`, `/usr/lib/qt6/qml`
for `Quickshell`. Note that qmllint 1.0 exits 255 without printing anything on any file
carrying a typed `IpcHandler` function, including Omarchy's own `shell.qml`; read the
printed warnings, not the exit code.

After editing, restart the shell with `omarchy-restart-shell`. A hot reload leaves the
plugin's IPC target owned by the previous instance, so `omarchy-shell ... press` will keep
running the old code until a restart. (`omarchy-refresh-shell` is a different command —
it **resets `shell.json` to Omarchy defaults**. Don't reach for it by mistake.)

## Credits

The files in `indicators/` are the stock Omarchy indicator implementations, vendored from
`/usr/share/omarchy/shell/plugins/bar/indicators` so the plugin is self-contained.
Omarchy is MIT-licensed, © Basecamp.

## License

MIT
