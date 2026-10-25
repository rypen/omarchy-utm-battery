import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "BatteryStatus.js" as Status

BarWidget {
  id: root
  moduleName: "ryan.utm-battery"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property bool showPercentage: setting("showPercentage", true) === true
  readonly property string mountHelper: {
    var url = Qt.resolvedUrl("mount-share").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }
  property string shareDir: ""
  property bool mountRunning: false
  property double nextMountAttempt: 0
  property string watchPath: ""
  property var probeList: []
  property int probeIndex: 0
  property int generation: 0
  property int inflight: 0
  property double probeStarted: 0
  property bool probing: false
  property var status: null

  readonly property bool fresh: status && status.present === true && status.stale !== true
  readonly property var remaining: Status.estimate(status)

  visible: fresh
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function candidates() {
    var configured = String(setting("statusFile", "") || "").trim()
    if (configured !== "") return [configured]
    var found = []
    if (shareDir !== "") found.push(shareDir + "/omarchy-utm-battery.json")
    if (home !== "") {
      found.push(home + "/Mac/omarchy-utm-battery.json")
      found.push(home + "/Shared/omarchy-utm-battery.json")
    }
    found.push("/mnt/utm/omarchy-utm-battery.json")
    found.push("/mnt/share/omarchy-utm-battery.json")
    return found
  }

  function considerMount() {
    if (String(setting("statusFile", "") || "").trim() !== "") return
    if (shareDir !== "" || mountRunning) return
    if (Date.now() < nextMountAttempt) return
    mountRunning = true
    mountProcess.command = [mountHelper]
    mountProcess.running = true
  }

  function poll() {
    if (probing && Date.now() - probeStarted < 4000) return
    probeStarted = Date.now()
    generation += 1
    inflight = generation
    probeList = candidates()
    probeIndex = 0
    probing = true
    openProbe()
  }

  function currentProbe() {
    return inflight === generation
  }

  function openProbe() {
    if (!currentProbe()) return
    if (probeIndex >= probeList.length) {
      probing = false
      watchPath = ""
      status = null
      considerMount()
      return
    }
    var path = probeList[probeIndex]
    if (statusFile.path === path) statusFile.reload()
    else statusFile.path = path
  }

  function apply(content) {
    if (!currentProbe()) return
    var parsed = Status.parseStatus(String(content || ""), Date.now())
    if (probing && (!parsed || parsed.stale === true)) {
      probeIndex += 1
      openProbe()
      return
    }
    watchPath = statusFile.path
    probing = false
    status = parsed
  }

  function miss() {
    if (statusFile.path === "") return
    if (!currentProbe()) return
    if (!probing) {
      watchPath = ""
      status = null
      return
    }
    probeIndex += 1
    openProbe()
  }

  function togglePercentage() {
    var entry = { id: root.moduleName }
    var key
    for (key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.showPercentage = !root.showPercentage
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  readonly property string percentageLabel: {
    if (!fresh || !showPercentage || vertical || status.percentage == null) return ""
    return strings.t("battery.percent").arg(Commons.I18n.formatNumber(status.percentage))
  }

  readonly property string tooltipLabel: {
    if (!fresh) return ""
    var lines = [strings.t(Status.stateKey(status.state))]
    lines.push(strings.t("battery.percent").arg(Commons.I18n.formatNumber(status.percentage)))
    var left = remaining
    if (left) {
      var hoursKey = left.kind === "full" ? "battery.untilFullHours" : "battery.untilEmptyHours"
      var minutesKey = left.kind === "full" ? "battery.untilFullMinutes" : "battery.untilEmptyMinutes"
      if (left.hours > 0) {
        lines.push(strings.t(hoursKey)
          .arg(Commons.I18n.formatNumber(left.hours))
          .arg(Commons.I18n.formatNumber(left.minutes)))
      } else {
        lines.push(strings.t(minutesKey).arg(Commons.I18n.formatNumber(left.minutes)))
      }
    }
    return lines.join("\n")
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }

  Process {
    id: mountProcess
    running: false
    stdout: StdioCollector {
      id: mountOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("ryan.utm-battery", text.trim())
    }
    onExited: function(code) {
      root.mountRunning = false
      var path = mountOut.text.trim().split("\n")[0]
      if (code === 0 && path !== "") root.shareDir = path
      else root.nextMountAttempt = Date.now() + 60000
    }
  }

  FileView {
    id: statusFile
    watchChanges: true
    blockLoading: false
    printErrors: false
    onLoaded: root.apply(text())
    onLoadFailed: root.miss()
    onFileChanged: reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Status.batteryIcon(root.status)
    labelText: root.percentageLabel
    tooltipText: root.tooltipLabel
    active: root.fresh && root.status.state === "discharging" && root.status.percentage <= 15
    slotSize: Style.bar.iconSlot * (root.showPercentage && !root.vertical ? 2 : 1)
    onPressed: function(button) {
      if (button === Qt.RightButton) root.togglePercentage()
      else root.poll()
    }
  }
}
