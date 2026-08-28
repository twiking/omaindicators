import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui

// OmaIndicators — the indicators, but you pick them from the bar.
//
// Omarchy's built-in indicators widget decides its set in shell.json and only
// reveals the inactive ones on hover. This widget instead carries its own
// button: pressing it opens a window listing every indicator with a switch,
// and whatever is switched on is rendered in the bar right beside the button.
// The selection is the widget's own state, persisted under XDG_STATE_HOME, so
// it survives a shell restart without editing any config by hand.
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
    { "id": "Dictation",       "label": "Dictation",       "description": "Voice typing status" },
    { "id": "ScreenRecording", "label": "Screen recording", "description": "GPU screen recorder status" },
    { "id": "Reminder",        "label": "Reminder",        "description": "Queued reminder status" },
    { "id": "NightLight",      "label": "Night light",     "description": "Blue-light filter" },
    { "id": "Dnd",             "label": "Do not disturb",  "description": "Notification silencing" },
    { "id": "StayAwake",       "label": "Stay awake",      "description": "Idle lock and screensaver override" }
  ]

  property var enabledIds: []
  property bool stateLoaded: false
  property bool opened: false
  property int cursorIndex: -1
  property bool cursorActive: false

  readonly property bool showLabels: setting("showLabels", true) === true

  // BarIndicator reads this off its host to decide whether an inactive
  // indicator is drawn dimmed or hidden entirely. A picked indicator is meant
  // to stay in the bar whatever its state, so it is always true here — the
  // built-in widget gates it on hover, which is the behaviour being replaced.
  readonly property bool revealInactiveIndicators: true

  // Indicators that poll (Reminder, ScreenRecording) refresh on this.
  signal refreshRequested()

  readonly property string stateDir: {
    var base = Quickshell.env("XDG_STATE_HOME")
    return (base ? base : Quickshell.env("HOME") + "/.local/state") + "/omaindicators"
  }
  readonly property string statePath: stateDir + "/state.json"

  function isEnabled(id) { return enabledIds.indexOf(id) !== -1 }

  function catalogIds() {
    var ids = []
    for (var i = 0; i < catalog.length; i++) ids.push(catalog[i].id)
    return ids
  }

  // Kept in catalog order rather than click order, so the bar never reshuffles
  // the indicators already showing when a new one is switched on.
  function setEnabled(id, on) {
    var order = catalogIds()
    var next = []
    for (var i = 0; i < order.length; i++) {
      var candidate = order[i]
      var keep = candidate === id ? on : isEnabled(candidate)
      if (keep) next.push(candidate)
    }
    enabledIds = next
    save()
  }

  function toggleIndicator(id) { setEnabled(id, !isEnabled(id)) }

  function open() {
    cursorActive = false
    cursorIndex = -1
    opened = true
    root.refreshRequested()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }
  function toggle() { opened ? close() : open() }

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
    toggleIndicator(catalog[cursorIndex].id)
  }

  // ------------------------------------------------------------- persistence

  function loadState(raw) {
    // FileView hands back an empty string for a file that isn't there yet, and
    // the shell keeps running for days, so a torn or hand-edited file must not
    // take the widget down with it — an unreadable state is an empty one.
    var ids = []
    if (raw && String(raw).trim() !== "") {
      try {
        var parsed = JSON.parse(raw)
        var list = parsed && parsed.enabled && typeof parsed.enabled.length === "number" ? parsed.enabled : []
        var known = catalogIds()
        for (var i = 0; i < list.length; i++) {
          var id = String(list[i])
          // Drop ids this version no longer ships, and de-duplicate: a stale
          // entry would otherwise load a nonexistent QML file every frame.
          if (known.indexOf(id) !== -1 && ids.indexOf(id) === -1) ids.push(id)
        }
      } catch (error) {
        console.warn("omaindicators: state parse failed:", error)
      }
    }
    enabledIds = ids
    stateLoaded = true
  }

  function save() {
    // Writing before the first load would persist the empty default over a
    // real selection that simply hasn't been read back yet.
    if (!stateLoaded) return
    stateFile.setText(JSON.stringify({ version: 1, enabled: enabledIds }, null, 2) + "\n")
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    // First run: no file yet. Without this the widget would never consider
    // itself loaded and save() would stay a no-op forever.
    onLoadFailed: root.loadState("")
  }

  Process { id: mkdirProc }

  Component.onCompleted: {
    mkdirProc.command = ["mkdir", "-p", root.stateDir]
    mkdirProc.running = true
    Qt.callLater(function() { stateFile.reload() })
  }

  // --------------------------------------------------------------- bar layout

  implicitWidth: root.vertical ? verticalLayout.implicitWidth : horizontalLayout.implicitWidth
  implicitHeight: root.vertical ? verticalLayout.implicitHeight : horizontalLayout.implicitHeight

  // One IPC route per verb, so the window can be bound to a key:
  //   omarchy-shell io.github.twiking.omaindicators toggle
  IpcHandler {
    target: "io.github.twiking.omaindicators"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.broadcast("refresh") }

    // Scriptable equivalent of flipping a switch in the window, so a
    // selection can be bound to a key or restored from a setup script.
    // Unknown ids are ignored rather than persisted.
    function setIndicator(id: string, on: bool): void {
      for (var i = 0; i < root.catalog.length; i++) {
        if (root.catalog[i].id === id) {
          root.broadcastSetIndicator(id, on)
          return
        }
      }
      console.warn("omaindicators: unknown indicator", id)
    }
  }

  // Every monitor has its own bar surface and so its own copy of this widget;
  // an IPC call lands on one of them, which relays to the rest. Otherwise the
  // selection would change on one screen and go stale on the others.
  function broadcastSetIndicator(id, on) {
    var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root]
    for (var i = 0; i < items.length; i++) {
      if (items[i] && typeof items[i].setEnabled === "function") items[i].setEnabled(id, on)
    }
  }

  function refresh() { root.refreshRequested() }

  Row {
    id: horizontalLayout
    visible: !root.vertical
    spacing: 0

    Repeater {
      model: root.enabledIds

      IndicatorSlot {
        required property var modelData
        indicatorId: String(modelData)
      }
    }

    Ui.BarIconButton {
      id: horizontalButton
      bar: root.bar
      // nf-fa-sliders (U+F1DE) — a themed glyph, so it takes the bar
      // foreground like every other icon instead of a fixed-colour emoji.
      text: ""
      tooltipText: "Indicators"
      active: root.opened
      onPressed: function(button) { root.toggle() }
    }
  }

  Column {
    id: verticalLayout
    visible: root.vertical
    spacing: 0

    Repeater {
      model: root.enabledIds

      IndicatorSlot {
        required property var modelData
        indicatorId: String(modelData)
      }
    }

    Ui.BarIconButton {
      id: verticalButton
      bar: root.bar
      text: ""
      tooltipText: "Indicators"
      active: root.opened
      onPressed: function(button) { root.toggle() }
    }
  }

  // ------------------------------------------------------------ toggle window

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.vertical ? verticalButton : horizontalButton
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
            required property var modelData
            required property int index

            width: column.width
            label: modelData.label
            description: root.showLabels ? modelData.description : ""
            checked: root.isEnabled(modelData.id)
            hasCursor: root.cursorActive && root.cursorIndex === index
            onClicked: root.toggleIndicator(modelData.id)
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

  // A single enabled indicator in the bar. The indicator QML files are the
  // stock Omarchy ones and expect their host to inject the same properties the
  // built-in widget injects, so this does exactly that — and re-injects
  // whenever `bar` arrives, because the slot is built before the host is.
  component IndicatorSlot: Item {
    id: slot

    property string indicatorId: ""

    implicitWidth: source.item && source.item.visible ? source.item.implicitWidth : 0
    implicitHeight: source.item && source.item.visible ? source.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    function injectProps() {
      var target = source.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("moduleName" in target) target.moduleName = slot.indicatorId
      if ("settings" in target) target.settings = ({})
      // "single" keeps the indicator in the bar whatever its state; the
      // active/inactive split only exists to let the built-in widget hide the
      // idle ones behind a hover.
      if ("indicatorBlock" in target) target.indicatorBlock = "single"
      if ("indicatorHost" in target) target.indicatorHost = root
    }

    Loader {
      id: source
      anchors.fill: parent
      source: slot.indicatorId ? Qt.resolvedUrl("indicators/" + slot.indicatorId + ".qml") : ""
      onLoaded: slot.injectProps()
      onStatusChanged: if (status === Loader.Error) console.warn("omaindicators: failed to load indicator", slot.indicatorId)
    }

    Connections {
      target: root
      function onBarChanged() { slot.injectProps() }
    }
  }
}
