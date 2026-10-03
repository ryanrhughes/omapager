// The bar indicator, and the panel behind it.
//
// Nothing held back, no sharing offer, nothing on the bar. omapager takes a
// slot when it is keeping something from you - the desktop is silenced,
// everything is snoozed, or one source is - and while a detected share is
// waiting for a snooze decision. Otherwise it follows Omarchy's convention
// for inactive status icons and appears only while the bar centre is revealed.
// A bell that is always there, always showing zero, is a permanent reminder of
// nothing.
//
// The states worth a glyph are the ones you cannot discover any other way, and
// the ones you can forget you are in. What is on screen needs no icon: it is
// on screen.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: pager
  moduleName: "njpatel.omapager"

  // The daemon, if it is up. Everything that reads it degrades to empty rather
  // than breaking the bar.
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("njpatel.omapager") : null
  readonly property bool silenced: service ? service.doNotDisturb : false
  readonly property bool sharingActive: service ? service.sharingActive : false
  readonly property bool sharingOfferPending: service ? service.sharingOfferPending : false

  // liveSnoozes() reads a plain map, which nothing re-evaluates on its own, so
  // the service bumps a revision whenever that map moves. This is what every
  // binding below actually depends on.
  readonly property int snoozeRevision: service ? service.snoozeRevision : 0
  readonly property int heldRevision: service ? service.heldRevision : 0
  readonly property int historyRevision: service ? service.historyRevision : 0
  readonly property var snoozed: {
    snoozeRevision
    return service ? service.liveSnoozes() : []
  }
  readonly property double globalUntil: {
    snoozeRevision
    return service ? service.globalSnoozeUntil : 0
  }
  readonly property bool globalSnoozed: globalUntil > 0

  // Quiet by decision, as opposed to quiet because nothing happened.
  readonly property bool codesLetThrough: service ? service.codesBypassQuiet : true
  readonly property bool quiet: silenced || globalSnoozed
  readonly property bool hasState: quiet || snoozed.length > 0

  // Shown when there is something to say, while the panel is open, and on the
  // same bar-centre gesture that reveals Omarchy's own inactive indicators -
  // otherwise there would be no way back to silence once you left it.
  // `alwaysShow` keeps the slot whether or not there is anything to report -
  // the same setting, and the same name, Omarchy's own Indicators widget has.
  // The icon appearing at all is the one moment the bar's centre still shifts,
  // because a widget that was not there is now taking a slot; holding the slot
  // open costs a permanently dim bell and buys a clock that never moves.
  readonly property bool alwaysShow: setting("alwaysShow", false) === true
  readonly property bool revealed: hasState || sharingOfferPending || opened || alwaysShow
    || (bar && bar.centerSectionRevealHeld === true && bar.centerHoverRevealSuppressed !== true)

  readonly property string configuredDisplayMode: {
    var mode = String(setting("displayMode", "active"))
    return mode === "specific" || mode === "all" ? mode : "active"
  }
  readonly property string configuredDisplayName: String(setting("displayName", "") || "")
  readonly property bool configuredOfferSnoozeWhenSharing: setting("offerSnoozeWhenSharing", true) !== false
  readonly property bool configuredShowCountdown: setting("showCountdown", false) === true
  readonly property string configuredFullscreenOverlay: {
    var mode = String(setting("fullscreenOverlay", "off"))
    return ["all", "steam", "all-away", "steam-away"].indexOf(mode) >= 0 ? mode : "off"
  }
  readonly property var fullscreenOverlayOptions: [
    { value: "off", label: "Nothing" },
    { value: "all", label: "Fullscreen windows" },
    { value: "steam", label: "Fullscreen Steam games" },
    { value: "all-away", label: "Fullscreen windows, never over them" },
    { value: "steam-away", label: "Fullscreen Steam games, never over them" }
  ]
  readonly property string fullscreenOverlayExplanation: {
    switch (configuredFullscreenOverlay) {
    case "all": return "Get out of the way of fullscreen windows, so they go straight to the display. A new notification still appears over them, then it steps aside again."
    case "steam": return "Get out of the way of fullscreen Steam games, so they go straight to the display. A new notification still appears over them, then it steps aside again."
    case "all-away": return "Never appear over a fullscreen window. New notifications go to another display instead, or wait in Recent if there is no other display."
    case "steam-away": return "Never appear over a fullscreen Steam game. New notifications go to another display instead, or wait in Recent if there is no other display."
    default: return "Stay over fullscreen windows. Hyprland then has to redraw every frame of a fullscreen game."
    }
  }
  readonly property bool configuredFetchRemoteIcons: setting("fetchRemoteIcons", true) !== false
  readonly property bool configuredRequireSandbox: setting("requireSandbox", false) === true
  readonly property int configuredEdgeSpacing: {
    var spacing = Number(setting("edgeSpacing", 12))
    return isFinite(spacing) ? Math.max(0, Math.min(64, Math.round(spacing))) : 12
  }
  readonly property var availableScreens: Quickshell.screens || []
  readonly property bool configuredDisplayPresent: {
    if (configuredDisplayName === "") return false
    var screens = availableScreens
    for (var i = 0; i < screens.length; i++)
      if (screens[i] && String(screens[i].name || "") === configuredDisplayName) return true
    return false
  }
  readonly property string displayChoice: configuredDisplayMode === "specific"
    ? "output:" + configuredDisplayName : configuredDisplayMode
  readonly property var displayOptions: {
    var options = [
      { value: "active", label: "Active display" },
      { value: "all", label: "All displays" }
    ]
    for (var i = 0; i < availableScreens.length; i++) {
      var name = String(availableScreens[i].name || "")
      if (name) options.push({ value: "output:" + name, label: name })
    }
    if (configuredDisplayMode === "specific" && !configuredDisplayPresent)
      options.push({ value: displayChoice, label: configuredDisplayName
        ? configuredDisplayName + " (disconnected)" : "Select a display" })
    return options
  }
  readonly property string displayExplanation: configuredDisplayMode === "all"
    ? "Show notifications on all connected displays."
    : configuredDisplayMode === "specific" && configuredDisplayPresent
      ? "Show notifications on " + configuredDisplayName + "."
      : configuredDisplayMode === "specific"
        ? "Selected display disconnected. Using the active display."
        : "Use the focused display for new notification groups."
  readonly property string sharingDetectionStatus: service && service.sharingDetectionStatus
    ? String(service.sharingDetectionStatus) : "Sharing detection unavailable: service not ready"

  function persistSettings(values) {
    var entry = { id: pager.moduleName }
    for (var existing in pager.settings) if (existing !== "id") entry[existing] = pager.settings[existing]
    for (var key in values) entry[key] = values[key]

    // Apply to this live widget first; the shell.json write comes back through
    // the bar with the same entry, including fields this view does not own.
    pager.settings = entry
    if (pager.bar && pager.bar.shell && typeof pager.bar.shell.updateEntryInline === "function")
      pager.bar.shell.updateEntryInline(pager.moduleName, entry)
  }

  function selectDisplay(value) {
    if (value === "active" || value === "all") {
      persistSettings({ displayMode: value })
      return
    }
    for (var i = 0; i < displayOptions.length; i++) {
      if (displayOptions[i].value !== value || value.indexOf("output:") !== 0) continue
      var name = value.slice(7)
      if (name) persistSettings({ displayMode: "specific", displayName: name })
      return
    }
  }

  function toggleSharingOfferSetting() {
    persistSettings({ offerSnoozeWhenSharing: !configuredOfferSnoozeWhenSharing })
  }

  readonly property int recentCount: {
    var count = Number(setting("recentCount", 5))
    return isFinite(count) ? Math.max(1, Math.min(20, Math.floor(count))) : 5
  }
  readonly property var recent: {
    snoozeRevision
    return service ? service.recentForPanel(recentCount) : []
  }

  // The persisted log, unlike recent above: everything the store still has on
  // disk, up to its own 100-entry ceiling, regardless of what is currently
  // snoozed or quiet.
  readonly property var history: {
    historyRevision
    return service ? service.historyRows : []
  }

  // ------------------------------------------------------------- settings
  //
  // The settings plumbing the daemon has been doing without. Only a bar widget
  // is handed its shell.json entry, and the daemon is a sibling with no way to
  // read one - so this is the single place that can, and it pushes them over.
  function applySettings() {
    if (!service) return
    service.requireSandbox = configuredRequireSandbox
    var stacking = String(setting("stacking", "source"))
    if (stacking === "all" || stacking === "source" && service.stacking !== stacking)
      service.commit(function() { service.stacking = stacking })
    var fontScale = Number(setting("fontScale", 100))
    service.fontScale = isFinite(fontScale) ? Math.max(75, Math.min(200, fontScale)) / 100 : 1
    service.edgeSpacing = configuredEdgeSpacing
    service.showCountdown = configuredShowCountdown
    service.fullscreenOverlay = configuredFullscreenOverlay
    var align = String(setting("actionsAlign", "right"))
    if (align === "left" || align === "right") service.actionsAlign = align
    service.setFetchRemoteIcons(configuredFetchRemoteIcons)
    service.allowDefaultActionOnCardClick = setting("allowDefaultActionOnCardClick", false) === true
    var lifetime = Number(setting("clipboardTimeout", 60))
    service.clipboardTimeout = [30, 60, 90].indexOf(lifetime) >= 0 ? lifetime : 60
    var hours = Number(setting("historyHours", 24))
    service.setHistoryHours([0, 1, 24, 168].indexOf(hours) >= 0 ? hours : 24)
    service.hideSettingsAction = setting("hideSettingsAction", true) !== false
    // Only when it has actually been configured. An explicit setting is an
    // instruction; the default is not one - and the panel's own key toggle is
    // persisted, so applying the default on every reload would quietly undo it.
    var codes = setting("codesBypassQuiet", null)
    if (codes !== null) service.setCodesBypassQuiet(codes !== false)
    service.smartRaise = setting("smartRaise", true) !== false
    service.wakeHour = Number(setting("wakeHour", 8)) || 8
    service.sourceLimit = Number(setting("sourceLimit", 8)) || 8
    service.heldPerSource = Number(setting("heldPerSource", 10)) || 10
    // Empty means "none chosen", not "no snoozing" - fall back rather than
    // leaving a menu with nothing in it.
    var chosen = setting("snoozeDurations", null)
    if (chosen && chosen.length > 0) service.snoozeChoices = chosen

    // The bar widget is the only object with the plugin's shell.json entry.
    // Keep the output name before the mode so selecting a present monitor does
    // not pass through a transient specific-without-a-name state.
    service.displayName = configuredDisplayName
    service.displayMode = configuredDisplayMode
    service.offerSnoozeWhenSharing = configuredOfferSnoozeWhenSharing
    service.helperSettingsReady = true
  }

  // Derived settings bindings may still hold the previous entry in the
  // settingsChanged handler. Apply after they settle, including config reloads.
  onSettingsChanged: Qt.callLater(applySettings)
  onServiceChanged: Qt.callLater(applySettings)
  Component.onCompleted: Qt.callLater(applySettings)

  // ------------------------------------------------------------- looks
  readonly property color panelFg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(panelFg, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Native semantic roles keep the two quiet states distinct across themes:
  // urgent for do-not-disturb, accent for a snooze that will end.
  readonly property color silencedColour: Color.urgent
  readonly property color snoozedColour: Color.accent

  // nf-md-bell-off, the glyph Omarchy's own Dnd indicator uses, so a silenced
  // desktop looks the same whichever service is running; nf-md-bell-sleep, a
  // bell with a Z in it, for a snooze - which is a bell that will ring later
  // rather than one that has been switched off.
  // The same key the cards wear when they are carrying a code, so the control
  // that decides whether codes get through is wearing the thing it is about.
  readonly property string keyGlyph: "\u{f0306}"
  readonly property string keyOff: "\u{f0308}"

  // nf-md-timer-sand. An hourglass says "time left" where a clock says "a
  // time", and it is not the clock button sitting at the other end of the same
  // row, which would read as the same control twice.
  readonly property string hourglass: "\u{f051f}"

  readonly property string bellOff: "\u{f009b}"
  readonly property string bellSleep: "\u{f00a0}"
  readonly property string bell: "\u{f009a}"

  // nf-md-monitor-share: an offer prompted by an active portal share, not a
  // quiet state. It must not look like the snoozed bell beside it.
  readonly property string sharingGlyph: "\u{f1483}"

  // Collapsed to nothing when there is nothing to report: an empty slot in the
  // bar is still a gap in the bar. Never animated, and every state is exactly
  // one slot wide, so nothing beside it ever slides - the clock stepping
  // sideways because a notification was snoozed is a worse offence than the
  // icon appearing at all.
  clip: true
  implicitWidth: vertical ? Math.max(glyphs.implicitWidth, barSize)
                          : (revealed ? glyphs.implicitWidth : 0)
  implicitHeight: vertical ? (revealed ? glyphs.implicitHeight : 0)
                           : Math.max(glyphs.implicitHeight, barSize)

  // ------------------------------------------------------------- state
  PanelController { id: controller }
  readonly property bool opened: controller.open
  property bool settingsView: false
  onSettingsViewChanged: {
    if (!settingsView) { displayDropdown.close(); fullscreenDropdown.close() }
    // The shared panel focuses its target only when it opens. A view switch
    // inside an already-open panel must transfer focus after bindings settle.
    Qt.callLater(function() {
      if (pager.opened) (pager.settingsView ? settingsPage : keys).forceActiveFocus()
    })
  }

  // KeyboardPanel dismisses itself by calling close() on its owner, and falls
  // back to writing its own `open` property when the owner has no such
  // function - which breaks the binding to this controller and leaves the
  // panel stuck shut. Omarchy's Panel base exposes these three; a bar widget
  // acting as its own panel has to as well.
  function open() {
    settingsView = false
    controller.show()
  }
  function openSettings() {
    settingsView = true
    controller.show()
  }
  function close() { controller.hide() }
  function toggle() { togglePanel() }

  function togglePanel() {
    if (controller.open) controller.hide()
    else {
      settingsView = false
      controller.show()
    }
  }

  function toggleSilence() { if (service) service.setDoNotDisturb(!service.doNotDisturb) }

  // The switch reads as "notifications are on", so turning it back on has to
  // undo every reason they were off: being silenced and having snoozed the lot
  // are the same promise from where the switch is sitting.
  function letEverythingThrough() {
    if (!service) return
    service.setDoNotDisturb(false)
    service.unsnooze(service.globalKey)
  }

  // Left silences, right opens the panel. The fastest thing anyone wants from
  // a notification indicator is for it to stop - and, once it has stopped, for
  // it to start again - so that is the plain click; the panel is where you go
  // to look at something rather than change it, which is what a right-click
  // means everywhere else.
  function pressed(buttonCode) {
    if (buttonCode === Qt.RightButton) togglePanel()
    else if (quiet) letEverythingThrough()
    else toggleSilence()
  }

  // The system's own clock, not one hardcoded here: 24-hour on this desktop,
  // "8:00 am" on a locale that does it that way. Qt takes it from LC_TIME.
  // "system" follows LC_TIME, which is what "12 or 24 hour" means on a Linux
  // desktop. It is worth knowing that Omarchy's clock widget does not: it
  // takes an explicit format string, so a bar pinned to 24-hour on a 12-hour
  // locale is a normal thing to have. Hence the override.
  readonly property string timeFormat: String(setting("timeFormat", "system"))

  function clockTime(when) {
    if (timeFormat === "24h") return Qt.formatTime(when, "HH:mm")
    if (timeFormat === "12h") return Qt.formatTime(when, "h:mm ap")
    // Through the locale object, not by handing Qt.formatTime an enum: that
    // takes its second argument as a format string, quietly makes nothing of
    // it, and falls back to a full clock - which is how a wake time came out
    // as "10:05:21". Nobody snoozes to the second.
    return when.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
  }

  // A wake time on another day carries the day offset the way a flight arrival
  // does. The question anyone is actually asking is "which night", and a date
  // answers a question nobody asked.
  function dayOffset(when) {
    var today = new Date(); today.setHours(0, 0, 0, 0)
    var then = new Date(when.getTime()); then.setHours(0, 0, 0, 0)
    var days = Math.round((then.getTime() - today.getTime()) / 86400000)
    // Written out rather than set in superscript: at caption size the
    // superscript form was there but not legible, which is the worst of both.
    return days <= 0 ? "" : " +" + days
  }

  // "in 24m", "in 3h", and then the time itself once the remaining minutes
  // stop being the useful half of the answer.
  function waking(until) {
    var when = new Date(until * 1000)
    var left = Math.max(0, until - Date.now() / 1000)
    // Rounded minutes, unless rounding them lands on the hour - an hour's
    // snooze read "back in 60m" for its first few seconds, which is a strange
    // way to say something nobody would ever say out loud.
    var minutes = Math.max(1, Math.round(left / 60))
    if (minutes < 60) return "in " + minutes + "m"
    if (left < 8 * 3600) return "in " + Math.max(1, Math.round(left / 3600)) + "h"
    return "until " + clockTime(when) + dayOffset(when)
  }

  // Without the leading word, for places that put a glyph in front of it
  // instead: an hourglass and "28m" says what "back in 28m" says, in a third
  // of the width.
  function waitingFor(until) { return waking(until).replace(/^in /, "").replace(/^until /, "") }

  // The same, said as a time rather than as a wait - which is what the line
  // under the title wants when the wait is the whole story.
  function wakingAt(until) {
    var when = new Date(until * 1000)
    return "Snoozed until " + clockTime(when) + dayOffset(when)
  }

  readonly property string stateLine: {
    if (globalSnoozed) return wakingAt(globalUntil)
    if (silenced) return "Do Not Disturb on"
    if (snoozed.length === 1) return "1 source snoozed"
    if (snoozed.length > 1) return snoozed.length + " sources snoozed"
    return "Notifications enabled"
  }


  // Return types are spelled out because Quickshell wants them, and `string`
  // rather than `void` because this Qt's QML grammar rejects `void` outright.
  IpcHandler {
    target: "omapager.panel"
    function open(): string { pager.open(); return "open" }
    function openSettings(): string { pager.openSettings(); return "settings" }
    // Current notification status for scripts, without opening the panel.
    function line(): string {
      return JSON.stringify({ line: pager.stateLine })
    }
    function close(): string { controller.hide(); return "closed" }
    function toggle(): string { pager.togglePanel(); return controller.open ? "open" : "closed" }
    // Open a source's held list without a pointer, the same way the deck's
    // `expand` stands in for hovering it. No argument closes whatever is open.
    function expand(key: string): string {
      var wanted = String(key || "")
      if (!wanted) { pager.expandedKey = ""; return "closed" }
      for (var i = 0; i < pager.sources.length; i++) {
        if (pager.sources[i].key.indexOf(wanted) >= 0 ||
            pager.sources[i].label.indexOf(wanted) >= 0) {
          pager.expandedKey = pager.sources[i].key
          return pager.sources[i].label
        }
      }
      return "no such source"
    }

    function state(): string {
      var held = []
      for (var i = 0; i < pager.sources.length; i++)
        held.push(pager.sources[i].label + "=" + pager.sources[i].held.length)
      return JSON.stringify({ opened: pager.opened, panelVisible: panel.visible,
                              view: pager.settingsView ? "settings" : "notifications",
                              settingsView: pager.settingsView,
                              silenced: pager.silenced, globalSnoozed: pager.globalSnoozed,
                              sharingActive: pager.sharingActive,
                              sharingOfferPending: pager.sharingOfferPending,
                              sharingDetectionStatus: pager.sharingDetectionStatus,
                              settings: { displayMode: pager.configuredDisplayMode,
                                          displayName: pager.configuredDisplayName,
                                          offerSnoozeWhenSharing: pager.configuredOfferSnoozeWhenSharing },
                              displayPresent: pager.configuredDisplayPresent,
                              displayMenuOpen: displayDropdown.popupOpen,
                              sources: held, expanded: pager.expandedKey,
                              recentCount: pager.recent.length, recentLimit: pager.recentCount,
                              recentExpanded: pager.recentExpanded,
                              historyCount: pager.history.length, historyExpanded: pager.historyExpanded,
                              cardX: panel.cardOrigin.x, cardY: panel.cardOrigin.y,
                              cw: panel.contentWidth, ch: panel.contentHeight })
    }
  }

  // ------------------------------------------------------------- the bar
  Row {
    id: glyphs
    anchors.centerIn: parent
    spacing: 0

    Indicator {
      visible: pager.sharingOfferPending
      text: pager.sharingGlyph
      colour: pager.snoozedColour
      openPanelOnly: true
      tooltipText: "Screen sharing detected. Open snooze controls."
    }

    Indicator {
      visible: !pager.sharingOfferPending && pager.silenced
      text: pager.bellOff
      colour: pager.silencedColour
      tooltipText: "Disable Do Not Disturb. Right-click for notifications."
    }

    Indicator {
      visible: !pager.sharingOfferPending && !pager.silenced && (pager.globalSnoozed || pager.snoozed.length > 0)
      text: pager.bellSleep
      colour: pager.snoozedColour
      tooltipText: pager.stateLine + ". Right-click for controls."
    }

    // The resting state, which only appears while the bar's inactive
    // indicators are being revealed. Same glyph and same dimming as Omarchy's
    // own, so it sits in that row without announcing itself.
    Indicator {
      visible: !pager.hasState && !pager.sharingOfferPending
      text: pager.bellOff
      colour: pager.bar ? pager.bar.barForeground : Color.foreground
      quiet: true
      tooltipText: "Enable Do Not Disturb. Right-click for notifications."
    }
  }

  component Indicator: BarIconButton {
    property bool quiet: false
    property bool openPanelOnly: false
    property color colour: pager.panelFg
    bar: pager.bar
    foreground: colour
    // BarIndicator's metrics, not BarIconButton's: caption font in a status
    // slot. These are smaller than a bar widget's - the weather's sun and the
    // update check's refresh sit at icon-font in an icon-slot - and next to
    // those this looks undersized. It is not: the things it belongs with are
    // the other status glyphs, which are all this size, and the one to reach
    // for a comparison against is whichever of those happens to be showing.
    fontSize: Style.font.caption
    horizontalMargin: 5
    verticalPadding: 5
    fixedWidth: pager.vertical ? -1 : Style.bar.statusSlot
    fixedHeight: pager.vertical ? Style.bar.statusSlot : -1
    useActiveColor: false
    dimmed: quiet
    onPressed: function(buttonCode) {
      if (openPanelOnly) pager.open()
      else pager.pressed(buttonCode)
    }
  }

  // ------------------------------------------------------------- the panel
  //
  // What is being kept from you, and what it has cost so far. Sources snoozed
  // by name come first, with their own wake time; then, when the whole desktop
  // is quiet, whichever other sources have actually had something held. Each
  // one opens to show what it caught.
  readonly property var sources: {
    snoozeRevision; heldRevision
    return service ? service.quietSources(service.sourceLimit) : []
  }

  property string expandedKey: ""
  property bool recentExpanded: false
  property bool historyExpanded: false
  onQuietChanged: if (quiet) recentExpanded = false
  property int cursorAt: 0
  property bool cursorLive: false
  property bool globalChoosing: false
  onOpenedChanged: {
    cursorAt = 0; cursorLive = false; expandedKey = ""; globalChoosing = false
    recentExpanded = false
    historyExpanded = false
    if (!opened) settingsView = false
    // What has been held back, as of now - read on opening rather than kept
    // up to date, because the panel is the only thing that ever asks.
    if (opened && service) service.refreshHeld()
    // Same story for the persisted log: read fresh each time the panel opens.
    if (opened && service) service.refreshHistory()
  }

  function snoozeEverything(seconds) {
    if (service) service.snoozeSource(service.globalKey, "Everything", seconds, true)
    globalChoosing = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: glyphs
    owner: pager
    bar: pager.bar
    gap: pager.configuredEdgeSpacing
    margin: pager.configuredEdgeSpacing
    open: pager.opened
    focusTarget: pager.settingsView ? settingsPage : keys
    // 380 is what every core Omarchy panel is, bar the two that need to be
    // wider (the clock's calendar, the weather's forecast). A panel that is
    // its own width is the thing you notice about it.
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: pager.settingsView
      onCloseRequested: controller.hide()
      // Tab/shift-tab cycle through the bar's panels the way every first-party
      // panel does. This widget is its own panel (see the open/close/opened
      // comment above), so it drives the bar's switcher directly instead of
      // going through Ui/Panel's switchPanel().
      onTabRequested: function(direction) {
        if (pager.bar && typeof pager.bar.switchPanelFrom === "function")
          return pager.bar.switchPanelFrom(pager, direction)
        return false
      }
      onMoveRequested: function(dx, dy) {
        if (pager.settingsView || dy === 0 || pager.sources.length === 0) return
        pager.cursorAt = Math.max(0, Math.min(pager.sources.length - 1, pager.cursorAt + dy))
        pager.cursorLive = true
      }
      // Every key here acts on the row the cursor is on, and nothing acts
      // without one. An open panel holds the keyboard exclusively, so anything
      // typed at another window while it happens to be open arrives here
      // instead - and this panel's shortcuts used to include silencing the
      // desktop. It did exactly what you would fear: someone typing a sentence
      // silenced their notifications, with nothing on screen to say why.
      // Navigation is safe to leave on a stray key. State changes are not.
      onActivateRequested: {
        if (pager.settingsView || !pager.cursorLive || pager.cursorAt >= pager.sources.length) return
        var key = pager.sources[pager.cursorAt].key
        pager.expandedKey = pager.expandedKey === key ? "" : key
      }
      onDeleteRequested: {
        if (!pager.settingsView && pager.cursorLive && pager.cursorAt < pager.sources.length && pager.service)
          pager.service.unsnooze(pager.sources[pager.cursorAt].key)
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { id: panelScrollBar; policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: parent.width
          spacing: Style.space(12)

          Column {
            id: settingsPage
            visible: pager.settingsView
            width: parent.width
            spacing: Style.spacing.huge
            Keys.onEscapePressed: controller.hide()

            PanelHero {
              width: parent.width
              title: "Notifications"
              meta: "Preferences"
              foreground: pager.panelFg
              fontFamily: pager.fontFamily
              trailingControl: Component {
                PanelActionButton {
                  iconText: "\u{f00d}"
                  tooltipText: "Close preferences"
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  focusable: true
                  onClicked: controller.hide()
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.spacing.lg

              // Picker, not the kit's Dropdown: see Picker.qml for why.
              Picker {
                id: displayDropdown
                width: parent.width
                label: "Notification display"
                value: pager.displayChoice
                options: pager.displayOptions
                foreground: pager.panelFg
                fontFamily: pager.fontFamily
                onPicked: function(value) { pager.selectDisplay(value) }
              }

              Text {
                width: parent.width
                text: pager.displayExplanation
                textFormat: Text.PlainText
                color: Qt.darker(pager.panelFg, 1.4)
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }

            PanelSeparator { foreground: pager.panelFg }

            Column {
              width: parent.width
              spacing: Style.spacing.lg

              Picker {
                id: fullscreenDropdown
                width: parent.width
                label: "Step aside for"
                value: pager.configuredFullscreenOverlay
                options: pager.fullscreenOverlayOptions
                foreground: pager.panelFg
                fontFamily: pager.fontFamily
                onPicked: function(value) { pager.persistSettings({ fullscreenOverlay: value }) }
              }

              Text {
                width: parent.width
                text: pager.fullscreenOverlayExplanation
                textFormat: Text.PlainText
                color: Qt.darker(pager.panelFg, 1.4)
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }

            PanelSeparator { foreground: pager.panelFg }

            Column {
              width: parent.width
              spacing: Style.spacing.lg

              Row {
                width: parent.width
                spacing: Style.spacing.controlGap

                Text {
                  width: parent.width - countdownSwitch.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Show countdown animation"
                  textFormat: Text.PlainText
                  color: pager.panelFg
                  font.family: pager.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }

                ToggleSwitch {
                  id: countdownSwitch
                  anchors.verticalCenter: parent.verticalCenter
                  checked: pager.configuredShowCountdown
                  foreground: pager.panelFg
                  onToggled: pager.persistSettings({ showCountdown: !pager.configuredShowCountdown })
                }
              }

              Text {
                width: parent.width
                text: "Show time remaining before a notification expires."
                textFormat: Text.PlainText
                color: Qt.darker(pager.panelFg, 1.4)
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }

            PanelSeparator { foreground: pager.panelFg }

            Column {
              width: parent.width
              spacing: Style.spacing.lg

              Row {
                width: parent.width
                spacing: Style.spacing.controlGap

                Text {
                  width: parent.width - sharingOfferSwitch.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Suggest snooze during screen sharing"
                  textFormat: Text.PlainText
                  color: pager.panelFg
                  font.family: pager.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }

                ToggleSwitch {
                  id: sharingOfferSwitch
                  anchors.verticalCenter: parent.verticalCenter
                  checked: pager.configuredOfferSnoozeWhenSharing
                  foreground: pager.panelFg
                  onToggled: pager.toggleSharingOfferSetting()
                }
              }

              Text {
                width: parent.width
                text: "Offer a timed snooze when screen sharing starts."
                textFormat: Text.PlainText
                color: Qt.darker(pager.panelFg, 1.4)
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Text {
                visible: pager.sharingDetectionStatus.indexOf("Sharing detection unavailable:") === 0
                width: parent.width
                text: pager.sharingDetectionStatus
                textFormat: Text.PlainText
                color: pager.panelFg
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
              Text {
                width: parent.width
                visible: pager.service && (pager.service.sandboxStatus.mode === "direct"
                                           || pager.service.sandboxStatus.mode === "blocked")
                text: pager.service && pager.service.sandboxStatus.mode === "blocked"
                  ? "Sandbox unavailable: helpers are blocked."
                  : "Sandbox unavailable: helpers run directly as your user."
                textFormat: Text.PlainText
                color: pager.panelFg
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
          }

          PanelHero {
            id: hero
            visible: !pager.settingsView
            width: parent.width
            title: "Notifications"
            meta: pager.stateLine
            foreground: pager.panelFg
            fontFamily: pager.fontFamily
            iconOpacity: pager.hasState ? 1.0 : 0.5
            // A fixed square with the glyph centred in it. The hero anchors
            // its labels to the right edge of whatever the icon loader turns
            // out to be, and a bell, a crossed-out bell and a bell with a Z in
            // it are three different widths - so swapping between them dragged
            // the title back and forth every time the switch was used.
            iconComponent: Component {
              Item {
                implicitWidth: hero.iconSize
                implicitHeight: hero.iconSize

                Text {
            textFormat: Text.PlainText
                  anchors.centerIn: parent
                  text: pager.silenced ? pager.bellOff
                      : (pager.globalSnoozed || pager.snoozed.length > 0) ? pager.bellSleep
                      : pager.bell
                  color: pager.silenced ? pager.silencedColour
                       : (pager.globalSnoozed || pager.snoozed.length > 0) ? pager.snoozedColour
                       : pager.panelFg
                  font.family: pager.fontFamily
                  font.pixelSize: hero.iconSize
                }
              }
            }

            // Snoozing everything sits beside the switch rather than in the
            // list below, because it is not a source: it is the same decision
            // as silencing, with an end time on it - which is the one most
            // people actually want. "Not for the next hour", rather than "not
            // until I remember I turned this off".
            trailingControl: Component {
              Row {
                spacing: Style.space(6)

                // Whether quiet has a hole in it, sitting immediately before
                // the thing that makes it quiet. Not a switch: it is a
                // qualifier on the button beside it, and two switches in one
                // corner is a settings page.
                //
                // Only while there is quiet for it to qualify - and while a
                // length is being chosen, which is the moment before there is.
                // A key on a desktop where everything is coming through anyway
                // is a control for nothing.
                PanelActionButton {
                  visible: pager.hasState || pager.globalChoosing
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: pager.codesLetThrough ? pager.keyGlyph : pager.keyOff
                  tooltipText: pager.codesLetThrough
                    ? "Block verification codes during snooze and Do Not Disturb"
                    : "Allow verification codes during snooze and Do Not Disturb"
                  foreground: pager.codesLetThrough ? pager.panelFg : pager.dim
                  fontFamily: pager.fontFamily
                  onClicked: {
                    if (pager.service) pager.service.setCodesBypassQuiet(!pager.codesLetThrough)
                  }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: pager.globalSnoozed ? pager.bell : pager.bellSleep
                  tooltipText: pager.globalSnoozed ? "End global snooze" : "Snooze all notifications"
                  foreground: pager.globalSnoozed ? pager.snoozedColour : pager.panelFg
                  fontFamily: pager.fontFamily
                  onClicked: {
                    if (pager.globalSnoozed) pager.service.unsnooze(pager.service.globalKey)
                    else pager.globalChoosing = !pager.globalChoosing
                  }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "\u{f0493}"                 // nf-md-cog
                  tooltipText: "Notification settings"
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  onClicked: pager.settingsView = true
                }
                ToggleSwitch {
                  anchors.verticalCenter: parent.verticalCenter
                  // On means notifications are coming through, which is the
                  // way round anyone reads a switch on a thing called
                  // Notifications. Off is a state you chose.
                  checked: !pager.quiet
                  foreground: pager.panelFg
                  onToggled: pager.quiet ? pager.letEverythingThrough() : pager.toggleSilence()
                }

              }
            }
          }

          BorderSurface {
            visible: !pager.settingsView && pager.sharingOfferPending
            width: parent.width
            implicitHeight: sharingOfferContent.implicitHeight + Style.space(16)
            color: "transparent"
            borderSpec: Border.controlSpec("normal", pager.panelFg, Color.accent)
            radius: Style.cornerRadius

            Column {
              id: sharingOfferContent
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(5)

              Text {
                width: parent.width
                text: "Sharing detected"
                textFormat: Text.PlainText
                color: pager.panelFg
                font.family: pager.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                width: parent.width
                text: "Snooze notifications?"
                textFormat: Text.PlainText
                color: pager.dim
                font.family: pager.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                spacing: Style.space(5)

                Button {
                  text: "30 min"
                  bordered: true
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.spacing.hairline
                  onClicked: { if (pager.service) pager.service.snoozeSharingOffer(1800) }
                }

                Button {
                  text: "1 hour"
                  bordered: true
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.spacing.hairline
                  onClicked: { if (pager.service) pager.service.snoozeSharingOffer(3600) }
                }

                Button {
                  text: "4 hours"
                  bordered: true
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.spacing.hairline
                  onClicked: { if (pager.service) pager.service.snoozeSharingOffer(14400) }
                }

                Button {
                  text: "Not now"
                  bordered: true
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.spacing.hairline
                  onClicked: { if (pager.service) pager.service.dismissSharingOffer() }
                }
              }
            }
          }

          // The lengths, revealed by the snooze button rather than sitting
          // under the title the whole time - with a note about the one thing
          // that still gets through, because a snooze you cannot predict is
          // one you will not use.
          Column {
            width: parent.width
            spacing: Style.space(5)
            visible: !pager.settingsView && pager.globalChoosing && !pager.globalSnoozed

            Text {
            textFormat: Text.PlainText
              visible: pager.codesLetThrough
              width: parent.width
              text: "Verification-code exception enabled."
              color: pager.dim
              font.family: pager.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              width: parent.width
              spacing: Style.space(5)

              Repeater {
                model: pager.globalChoosing && pager.service ? pager.service.snoozeOptions : []

                Button {
                  required property var modelData
                  text: String(modelData.short)
                  bordered: true
                  foreground: pager.panelFg
                  fontFamily: pager.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.spacing.hairline
                  onClicked: pager.snoozeEverything(Number(modelData.seconds))
                }
              }
            }
          }

          PanelSeparator { visible: !pager.settingsView && !pager.quiet; foreground: pager.panelFg }

          Item {
            visible: !pager.settingsView && !pager.quiet
            width: parent.width
            height: Math.max(recentHeading.implicitHeight, recentToggle.implicitHeight)

            PanelSectionHeader {
              id: recentHeading
              anchors.left: parent.left
              anchors.right: recentToggle.left
              anchors.verticalCenter: parent.verticalCenter
              text: "RECENT · " + pager.recent.length
              foreground: pager.panelFg
              fontFamily: pager.fontFamily
            }

            MouseArea {
              anchors.left: parent.left
              anchors.right: recentToggle.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              cursorShape: Qt.PointingHandCursor
              onClicked: pager.recentExpanded = !pager.recentExpanded
            }

            PanelActionButton {
              id: recentToggle
              anchors.right: parent.right
              // The scrollbar owns the right-edge hit area even over this row.
              anchors.rightMargin: panelScrollBar.width
              anchors.verticalCenter: parent.verticalCenter
              iconText: pager.recentExpanded ? "\u{f0143}" : "\u{f0140}"
              tooltipText: pager.recentExpanded ? "Hide recent notifications" : "Show recent notifications"
              foreground: pager.panelFg
              fontFamily: pager.fontFamily
              focusable: true
              onClicked: pager.recentExpanded = !pager.recentExpanded
            }
          }

          Text {
            visible: !pager.settingsView && !pager.quiet && pager.recentExpanded && pager.recent.length === 0
            width: parent.width
            text: "No recent notifications."
            textFormat: Text.PlainText
            color: pager.dim
            font.family: pager.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !pager.settingsView && !pager.quiet && pager.recentExpanded
            width: parent.width
            spacing: Style.spacing.md

            Repeater {
              model: !pager.settingsView && !pager.quiet && pager.recentExpanded ? pager.recent : []

              BorderSurface {
                id: recentCard
                required property var modelData
                width: parent.width
                leftPadding: Style.spacing.controlPaddingX
                rightPadding: Style.spacing.controlPaddingX
                topPadding: Style.spacing.md
                bottomPadding: Style.spacing.md
                height: recentText.implicitHeight + contentTopInset + contentBottomInset
                radius: Style.cornerRadius
                color: Style.normalFillFor(pager.panelFg, Color.accent)
                borderSpec: Border.controlSpec("normal", pager.panelFg, Color.accent)

                Column {
                  id: recentText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: recentCard.contentLeftInset
                  anchors.rightMargin: recentCard.contentRightInset
                  anchors.topMargin: recentCard.contentTopInset
                  spacing: Style.spacing.xs

                  Text {
                    width: parent.width
                    text: recentCard.modelData.source + " · "
                          + pager.clockTime(new Date(recentCard.modelData.ts * 1000))
                    textFormat: Text.PlainText
                    color: pager.dim
                    font.family: pager.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: recentCard.modelData.summary
                    textFormat: Text.PlainText
                    color: pager.panelFg
                    font.family: "Liberation Sans"
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: text !== ""
                    width: parent.width
                    text: recentCard.modelData.bodyLine
                    textFormat: Text.PlainText
                    color: Qt.darker(pager.panelFg, 1.15)
                    font.family: "Liberation Sans"
                    font.pixelSize: Style.font.title
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          PanelSeparator { visible: !pager.settingsView; foreground: pager.panelFg }

          PanelSectionHeader {
            visible: !pager.settingsView
            text: pager.quiet ? "HELD BACK" : "SNOOZED SOURCES"
            foreground: pager.panelFg
            fontFamily: pager.fontFamily
          }

          Text {
            textFormat: Text.PlainText
            visible: !pager.settingsView && pager.sources.length === 0
            width: parent.width
            text: pager.quiet
                  ? "No held notifications."
                  : "No snoozed sources. Right-click a notification to snooze its source."
            color: pager.dim
            font.family: pager.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !pager.settingsView
            width: parent.width
            spacing: Style.spacing.sm

            Repeater {
              model: pager.sources

              Column {
                id: line
                required property var modelData
                required property int index
                readonly property bool expanded: pager.expandedKey === modelData.key
                readonly property bool snoozedByName: modelData.until > 0
                property bool choosing: false
                width: parent.width
                spacing: 0

                CursorSurface {
                  width: parent.width
                  height: Math.max(label.implicitHeight, controls.implicitHeight, Style.spacing.controlHeight)
                  hasCursor: pager.cursorLive && pager.cursorAt === line.index
                  foreground: pager.panelFg

                  Column {
                    id: label
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - controls.width - Style.spacing.xl

                    Text {
            textFormat: Text.PlainText
                      width: parent.width
                      text: line.modelData.label
                      color: pager.panelFg
                      font.family: pager.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                    }

                    // Two facts, and both are worth saying: when it comes
                    // back, and what it has cost so far. Split into two so the
                    // wake time carries the same accent role as the snoozed
                    // bell in the bar.
                    Row {
                      width: parent.width
                      spacing: Style.spacing.sm

                      // The glyph in a box the height of the line, one size
                      // down. A Nerd Font mark is drawn taller than the text it
                      // sits in at the same nominal size, so matching the
                      // numbers means asking for slightly less.
                      Item {
                        visible: line.snoozedByName
                        width: sand.implicitWidth
                        height: waitFor.implicitHeight

                        Text {
            textFormat: Text.PlainText
                          id: sand
                          anchors.centerIn: parent
                          text: pager.hourglass
                          color: pager.snoozedColour
                          font.family: pager.fontFamily
                          font.pixelSize: Math.round(Style.font.caption * 0.85)
                        }
                      }

                      Text {
            textFormat: Text.PlainText
                        id: waitFor
                        visible: line.snoozedByName
                        text: pager.waitingFor(line.modelData.until)
                        color: pager.snoozedColour
                        font.family: pager.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
            textFormat: Text.PlainText
                        readonly property int count: line.modelData.held.length
                        visible: count > 0
                        width: Math.min(implicitWidth, Math.max(0, parent.width - x))
                        text: (line.snoozedByName ? "· " : "")
                              + (count === 1 ? "1 held" : count + " held")
                        color: pager.dim
                        font.family: pager.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: label
                    enabled: line.modelData.held.length > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) {
                      pager.cursorAt = line.index
                      // Hover selects visually, but only keyboard navigation
                      // may arm state-changing shortcuts on this row.
                      pager.cursorLive = false
                    }
                    onClicked: pager.expandedKey = line.expanded ? "" : line.modelData.key
                  }

                  Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing.xs

                    // The lengths on offer, revealed rather than always
                    // present: four numbers on every row is a wall, and most
                    // of the time the button you want is the one that wakes it.
                    Row {
                      spacing: Style.spacing.xs
                      visible: line.choosing

                      Repeater {
                        model: line.choosing && pager.service ? pager.service.snoozeOptions : []

                        Button {
                          required property var modelData
                          text: String(modelData.short)
                          bordered: true
                          foreground: pager.panelFg
                          fontFamily: pager.fontFamily
                          fontSize: Style.font.caption
                          verticalPadding: Style.spacing.hairline
                          // From now, not on top of what is left: the button
                          // says four hours, so it had better mean four hours.
                          onClicked: {
                            pager.service.snoozeSource(line.modelData.key, line.modelData.label,
                                                       Number(modelData.seconds), true)
                            line.choosing = false
                          }
                        }
                      }
                    }

                    PanelActionButton {
                      visible: line.modelData.held.length > 0
                      iconText: line.expanded ? "\u{f0143}" : "\u{f0140}"   // chevron up / down
                      tooltipText: line.expanded ? "Hide held notifications" : "Show held notifications"
                      foreground: pager.panelFg
                      fontFamily: pager.fontFamily
                      onClicked: pager.expandedKey = line.expanded ? "" : line.modelData.key
                    }

                    PanelActionButton {
                      iconText: line.choosing ? "✕" : "\u{f0150}"     // close / clock
                      tooltipText: line.choosing ? "Close snooze options"
                                 : (line.snoozedByName ? "Extend snooze" : "Snooze source")
                      foreground: pager.panelFg
                      fontFamily: pager.fontFamily
                      onClicked: line.choosing = !line.choosing
                    }

                    PanelActionButton {
                      visible: line.snoozedByName
                      iconText: "\u{f009a}"                 // nf-md-bell
                      tooltipText: "Resume notifications from this source"
                      foreground: pager.panelFg
                      fontFamily: pager.fontFamily
                      onClicked: pager.service.unsnooze(line.modelData.key)
                    }
                  }
                }

                // What it caught while you were not being told. Capped, and
                // one line each: this is for recognising what you missed, not
                // for reading it - those notifications are gone.
                Item {
                  width: parent.width
                  height: line.expanded ? heldList.implicitHeight + Style.spacing.lg : 0
                  visible: height > 0
                  clip: true
                  Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                  Column {
                    id: heldList
                    width: parent.width - Style.spacing.xxl
                    x: Style.spacing.xxl
                    y: Style.spacing.sm
                    spacing: Style.spacing.hairline

                    Repeater {
                      model: line.expanded ? line.modelData.held : []

                      // The time, the headline, and as much of the message as
                      // fits. Three notifications from the same person all say
                      // that person's name and nothing else, so the headline
                      // alone is not enough to tell them apart.
                      Text {
            textFormat: Text.PlainText
                        required property var modelData
                        width: parent.width
                        text: {
                          var when = Qt.formatDateTime(new Date(Number(modelData.ts) * 1000), "HH:mm")
                          var head = String(modelData.summary || "")
                          var rest = String(modelData.bodyLine || "")
                          if (head && rest) return when + "  " + head + " · " + rest
                          return when + "  " + (head || rest)
                        }
                        color: pager.dim
                        font.family: pager.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { visible: !pager.settingsView; foreground: pager.panelFg }

          Item {
            visible: !pager.settingsView
            width: parent.width
            height: Math.max(historyHeading.implicitHeight, historyToggle.implicitHeight)

            PanelSectionHeader {
              id: historyHeading
              anchors.left: parent.left
              anchors.right: historyToggle.left
              anchors.verticalCenter: parent.verticalCenter
              text: "HISTORY · " + pager.history.length
              foreground: pager.panelFg
              fontFamily: pager.fontFamily
            }

            MouseArea {
              anchors.left: parent.left
              anchors.right: historyToggle.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              cursorShape: Qt.PointingHandCursor
              onClicked: pager.historyExpanded = !pager.historyExpanded
            }

            PanelActionButton {
              id: historyToggle
              anchors.right: parent.right
              // The scrollbar owns the right-edge hit area even over this row.
              anchors.rightMargin: panelScrollBar.width
              anchors.verticalCenter: parent.verticalCenter
              iconText: pager.historyExpanded ? "\u{f0143}" : "\u{f0140}"
              tooltipText: pager.historyExpanded ? "Hide notification history" : "Show notification history"
              foreground: pager.panelFg
              fontFamily: pager.fontFamily
              focusable: true
              onClicked: pager.historyExpanded = !pager.historyExpanded
            }
          }

          Text {
            visible: !pager.settingsView && pager.historyExpanded && pager.history.length === 0
            width: parent.width
            text: "No notification history."
            textFormat: Text.PlainText
            color: pager.dim
            font.family: pager.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !pager.settingsView && pager.historyExpanded
            width: parent.width
            spacing: Style.spacing.md

            // Collapsed instantiates no delegates, same as Recent - up to 100
            // cards is real weight to carry only while this is open.
            Repeater {
              model: !pager.settingsView && pager.historyExpanded ? pager.history : []

              BorderSurface {
                id: historyCard
                required property var modelData
                property bool expanded: false
                width: parent.width
                leftPadding: Style.spacing.controlPaddingX
                rightPadding: Style.spacing.controlPaddingX
                topPadding: Style.spacing.md
                bottomPadding: Style.spacing.md
                height: historyText.implicitHeight + contentTopInset + contentBottomInset
                radius: Style.cornerRadius
                color: Style.normalFillFor(pager.panelFg, Color.accent)
                borderSpec: Border.controlSpec("normal", pager.panelFg, Color.accent)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: historyCard.expanded = !historyCard.expanded
                }

                Column {
                  id: historyText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: historyCard.contentLeftInset
                  anchors.rightMargin: historyCard.contentRightInset
                  anchors.topMargin: historyCard.contentTopInset
                  spacing: Style.spacing.xs

                  Text {
                    width: parent.width
                    text: historyCard.modelData.source + " · "
                          + pager.clockTime(new Date(historyCard.modelData.ts * 1000))
                    textFormat: Text.PlainText
                    color: pager.dim
                    font.family: pager.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: historyCard.modelData.summary
                    textFormat: Text.PlainText
                    color: pager.panelFg
                    font.family: "Liberation Sans"
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: text !== ""
                    width: parent.width
                    text: historyCard.modelData.bodyLine
                    textFormat: Text.PlainText
                    color: Qt.darker(pager.panelFg, 1.15)
                    font.family: "Liberation Sans"
                    font.pixelSize: Style.font.title
                    wrapMode: Text.WordWrap
                    // Store already bounds the text; expanded cards show all of it.
                    maximumLineCount: historyCard.expanded ? 2147483647 : 2
                    elide: historyCard.expanded ? Text.ElideNone : Text.ElideRight
                  }
                }
              }
            }
          }

          Button {
            visible: !pager.settingsView && (pager.quiet || pager.snoozed.length > 1)
            width: parent.width
            text: "Resume all notifications"
            bordered: true
            foreground: pager.panelFg
            fontFamily: pager.fontFamily
            fontSize: Style.font.caption
            onClicked: {
              pager.letEverythingThrough()
              if (pager.service) pager.service.unsnoozeAll()
            }
          }
        }
      }
    }
  }

}
