import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

// OmaIndicators — every Omarchy indicator behind one bar icon.
//
// The built-in indicators widget spreads its set along the bar and only reveals
// the idle ones on hover. This is the opposite trade: one icon, and a panel
// that lists every indicator with a switch. Each switch shows that indicator's
// live state and flipping it performs the indicator's own action — the night
// light switch toggles night light, the recording switch starts and stops the
// recorder — so the panel is the whole surface and the bar stays at one glyph.
//
// The icon lights up while anything is active, so the bar still says whether
// something is running without spending any width on it.
//
// (qs.Ui is imported under a namespace because this file is itself named
// BarWidget.qml — a bare `BarWidget` would resolve back to this file.)
Ui.BarWidget {
  id: root
  moduleName: "io.github.twiking.omaindicators"

  // The indicator implementations live in indicators/ and are loaded by id, so
  // this catalog is the only place a new one has to be named. Each entry maps
  // one-to-one onto indicators/<id>.qml.
  readonly property var catalog: [
    { "id": "Dictation",       "label": "Dictation",        "description": "Voice typing status" },
    { "id": "ScreenRecording", "label": "Screen recording", "description": "GPU screen recorder status" },
    { "id": "Reminder",        "label": "Reminder",         "description": "Queued reminder status" },
    { "id": "NightLight",      "label": "Night light",      "description": "Blue-light filter" },
    { "id": "Dnd",             "label": "Do not disturb",   "description": "Notification silencing" },
    { "id": "StayAwake",       "label": "Stay awake",       "description": "Idle lock and screensaver override" }
  ]

  property bool opened: false
  property int cursorIndex: -1
  property bool cursorActive: false
  property int activeCount: 0
  // id -> true for every indicator currently active. The panel switches bind
  // to this rather than to the indicator objects: those resolve once, while
  // the loaders are still filling in, so a direct binding would never update.
  property var activeStates: ({})

  readonly property bool showLabels: setting("showLabels", true) === true

  // The loaded indicators read this off their host to decide whether an
  // inactive one is drawn dimmed or hidden. Nothing here is drawn in the bar,
  // but the property has to exist for those bindings to resolve.
  readonly property bool revealInactiveIndicators: true

  // Indicators that poll (Reminder, ScreenRecording) refresh on this.
  signal refreshRequested()

  function indicatorItem(id) {
    for (var i = 0; i < hosts.count; i++) {
      var host = hosts.itemAt(i)
      if (host && host.indicatorId === id) return host.item
    }
    return null
  }

  function isActive(id) {
    var item = indicatorItem(id)
    return !!item && item.active === true
  }

  // Every indicator does its work in its own `onPressed` handler — some toggle
  // a service, some launch a menu — so the panel emits that signal rather than
  // reimplementing six different actions. Emitting is also what the bar does
  // when the indicator is clicked there, which keeps the two paths identical.
  function press(id) {
    var item = indicatorItem(id)
    if (!item) {
      console.warn("omaindicators: indicator not loaded yet", id)
      return
    }
    item.pressed(Qt.LeftButton)
    // Poll-backed indicators only learn their new state on the next read.
    root.refreshRequested()
  }

  function recountActive() {
    var states = {}
    var count = 0
    for (var i = 0; i < catalog.length; i++) {
      var id = catalog[i].id
      if (isActive(id)) {
        states[id] = true
        count++
      }
    }
    // Assigned whole so the change signal fires: mutating the existing object
    // in place would leave every switch bound to a value QML thinks is stale.
    activeStates = states
    activeCount = count
  }

  function open() {
    cursorActive = false
    cursorIndex = -1
    opened = true
    root.refreshRequested()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }
  function toggle() { opened ? close() : open() }
  function refresh() { root.refreshRequested() }

  function moveCursor(delta) {
    if (catalog.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      if (cursorIndex < 0) cursorIndex = 0
      return
    }
    var next = cursorIndex + delta
    if (next < 0) next = catalog.length - 1
    else if (next >= catalog.length) next = 0
    cursorIndex = next
  }

  function activateCursor() {
    if (!cursorActive || cursorIndex < 0 || cursorIndex >= catalog.length) return
    press(catalog[cursorIndex].id)
  }

  // --------------------------------------------------------------------- bar

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // One IPC route per verb, so the panel can be bound to a key:
  //   omarchy-shell io.github.twiking.omaindicators toggle
  IpcHandler {
    target: "io.github.twiking.omaindicators"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.broadcast("refresh") }

    // Scriptable equivalent of flipping a switch in the panel, so an
    // indicator's own action can be bound to a key. Unknown ids are ignored.
    function press(id: string): void {
      for (var i = 0; i < root.catalog.length; i++) {
        if (root.catalog[i].id === id) {
          root.press(id)
          return
        }
      }
      console.warn("omaindicators: unknown indicator", id)
    }
  }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-sliders, a themed glyph so it takes the bar foreground like every
    // other icon instead of a fixed-colour emoji. Written as an escape rather
    // than the literal character: the codepoint is in the Private Use Area,
    // where a tool that mangles encodings drops it silently and the button
    // renders empty — which reads as "the widget isn't there" in the bar.
    text: "\uF1DE"
    tooltipText: root.activeCount > 0
      ? ("Indicators — " + root.activeCount + " active")
      : "Indicators"
    active: root.opened || root.activeCount > 0
    onPressed: function(pressedButton) { root.toggle() }
  }

  // The indicators themselves, instantiated but never shown: the panel needs
  // their live `active` state and their press handlers, not their glyphs. They
  // are the stock Omarchy files and expect their host to inject the same
  // properties the built-in widget injects, so that is what happens here.
  Item {
    id: indicatorHosts
    visible: false
    width: 0
    height: 0

    Repeater {
      id: hosts
      model: root.catalog

      Item {
        id: host
        required property var modelData

        readonly property string indicatorId: modelData.id
        readonly property var item: loader.item

        Loader {
          id: loader
          source: Qt.resolvedUrl("indicators/" + host.indicatorId + ".qml")
          onLoaded: {
            host.injectProps()
            root.recountActive()
          }
          onStatusChanged: if (status === Loader.Error) console.warn("omaindicators: failed to load indicator", host.indicatorId)
        }

        function injectProps() {
          var target = loader.item
          if (!target) return
          if ("bar" in target) target.bar = root.bar
          if ("moduleName" in target) target.moduleName = host.indicatorId
          if ("settings" in target) target.settings = ({})
          if ("indicatorBlock" in target) target.indicatorBlock = "single"
          if ("indicatorHost" in target) target.indicatorHost = root
        }

        // The slot is built before the bar host arrives, and several
        // indicators refuse to poll until they have it.
        Connections {
          target: root
          function onBarChanged() { host.injectProps() }
        }

        Connections {
          target: loader.item
          ignoreUnknownSignals: true
          function onActiveChanged() { root.recountActive() }
        }
      }
    }
  }

  // ------------------------------------------------------------------- panel

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Ui.PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      // Tab hands off to the next bar popup, the way the first-party panels
      // do. Ui.Panel owns this helper; a bar widget has to ask the host.
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root, direction)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(6)

        Ui.PanelSectionHeader {
          width: parent.width
          text: "Indicators"
        }

        Repeater {
          model: root.catalog

          Ui.Toggle {
            id: row
            required property var modelData
            required property int index

            width: column.width
            label: modelData.label
            description: root.showLabels ? modelData.description : ""
            checked: root.activeStates[modelData.id] === true
            hasCursor: root.cursorActive && root.cursorIndex === index
            onClicked: root.press(modelData.id)
            onHovered: function(isHovered) {
              if (!isHovered) return
              root.cursorActive = true
              root.cursorIndex = index
            }
          }
        }
      }
    }
  }
}
