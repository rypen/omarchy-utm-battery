import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "BatteryStatus.js" as Status

Panel {
  id: root
  moduleName: "ryan.utm-battery"

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property bool showPercentage: setting("showPercentage", true) === true
  readonly property bool verticalBar: bar ? bar.vertical : false
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string mountHelper: {
    var url = Qt.resolvedUrl("mount-share").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }
  readonly property string memoryPath: home === "" ? "" : home + "/.local/state/omarchy-utm-battery/last.json"
  readonly property var dirChoices: {
    var found = []
    if (home !== "") {
      found.push(home + "/Mac")
      found.push(home + "/.local/state/omarchy-utm-battery/share")
    }
    return found
  }

  property string shareDir: ""
  property string shareState: "none"
  property string mountDir: ""
  property bool wantMounted: false
  property bool mountRunning: false
  property string mountMessage: ""
  property string watchPath: ""
  property var probeList: []
  property int probeIndex: 0
  property int generation: 0
  property int inflight: 0
  property double probeStarted: 0
  property bool probing: false
  property var status: null
  property string savedText: ""

  readonly property var remaining: Status.estimate(status)
  readonly property string idleIcon: "󰁺"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: {
    if (home !== "") {
      mountDir = home + "/Mac"
      mkdirProcess.command = ["mkdir", "-p", home + "/.local/state/omarchy-utm-battery"]
      mkdirProcess.running = true
    }
    refreshShare()
  }

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

  function remember(content, parsed) {
    if (!parsed || parsed.present !== true) return
    status = parsed
    if (content === savedText || memoryPath === "") return
    savedText = content
    memoryFile.setText(content)
  }

  function apply(content) {
    if (!currentProbe()) return
    var parsed = Status.parseStatus(String(content || ""), Date.now())
    if (probing && (!parsed || parsed.present !== true)) {
      probeIndex += 1
      openProbe()
      return
    }
    watchPath = statusFile.path
    probing = false
    remember(String(content || ""), parsed)
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
      return
    }
    var path = probeList[probeIndex]
    if (statusFile.path === path) statusFile.reload()
    else statusFile.path = path
  }

  function miss() {
    if (statusFile.path === "") return
    if (!currentProbe()) return
    if (!probing) return
    probeIndex += 1
    openProbe()
  }

  function refreshShare() {
    if (mountRunning || mountHelper === "") return
    if (shareProcess.running) return
    shareProcess.command = [mountHelper, "status"]
    shareProcess.running = true
  }

  function mountChosen() {
    if (mountRunning || shareState !== "unmounted" || mountDir === "") return
    wantMounted = true
    mountRunning = true
    mountMessage = ""
    mountProcess.command = [mountHelper, "mount", mountDir]
    mountProcess.running = true
  }

  function unmountShare() {
    if (mountRunning || shareState !== "mounted") return
    wantMounted = false
    mountRunning = true
    mountMessage = ""
    mountProcess.command = [mountHelper, "unmount"]
    mountProcess.running = true
  }

  function toggleShare() {
    if (mountRunning || shareState === "none") return
    if (shareState === "mounted") unmountShare()
    else mountChosen()
  }

  function pathFromUrl(url) {
    var text = String(url || "")
    if (text.indexOf("file://") === 0) text = decodeURIComponent(text.substring(7))
    return text
  }

  function chooseMountDir() {
    close()
    var start = mountDir !== "" ? mountDir : home
    if (start !== "") folderDialog.currentFolder = "file://" + start
    folderDialog.open()
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
    if (!showPercentage || verticalBar || !status || status.percentage == null) return ""
    return strings.t("battery.percent").arg(I18n.formatNumber(status.percentage))
  }

  readonly property string tooltipLabel: {
    if (!status || status.present !== true) return strings.t("battery.notMounted")
    var lines = [strings.t(Status.stateKey(status.state))]
    lines.push(strings.t("battery.percent").arg(I18n.formatNumber(status.percentage)))
    var left = remaining
    if (left) {
      var hoursKey = left.kind === "full" ? "battery.untilFullHours" : "battery.untilEmptyHours"
      var minutesKey = left.kind === "full" ? "battery.untilFullMinutes" : "battery.untilEmptyMinutes"
      if (left.hours > 0) {
        lines.push(strings.t(hoursKey)
          .arg(I18n.formatNumber(left.hours))
          .arg(I18n.formatNumber(left.minutes)))
      } else {
        lines.push(strings.t(minutesKey).arg(I18n.formatNumber(left.minutes)))
      }
    }
    return lines.join("\n")
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refreshShare()
      root.poll()
    }
  }

  Process {
    id: mkdirProcess
    running: false
  }

  Process {
    id: shareProcess
    running: false
    stdout: StdioCollector {
      id: shareOut
      waitForEnd: true
    }
    onExited: function(code) {
      var line = shareOut.text.trim().split("\n")[0]
      if (code === 0 && line.indexOf("mounted ") === 0) {
        root.shareState = "mounted"
        root.shareDir = line.substring(8)
      } else if (code === 0 && line.indexOf("unmounted ") === 0) {
        root.shareState = "unmounted"
        root.shareDir = ""
      } else {
        root.shareState = "none"
        root.shareDir = ""
      }
    }
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
      var line = mountOut.text.trim().split("\n")[0]
      if (code === 0 && line.indexOf("mounted ") === 0) {
        root.shareState = "mounted"
        root.shareDir = line.substring(8)
        root.wantMounted = true
        root.mountMessage = ""
        root.poll()
      } else if (code === 0 && line === "unmounted") {
        root.shareState = "unmounted"
        root.shareDir = ""
        root.wantMounted = false
        root.mountMessage = ""
      } else if (code === 2) {
        root.mountMessage = strings.t("battery.directoryNotEmpty")
      } else {
        root.mountMessage = strings.t("battery.mountFailed")
      }
    }
  }

  FileView {
    id: memoryFile
    path: root.memoryPath
    watchChanges: true
    blockLoading: false
    printErrors: false
    onLoaded: {
      if (root.status) return
      var parsed = Status.parseStatus(text(), Date.now())
      if (parsed && parsed.present === true) {
        root.status = parsed
        root.savedText = text()
      }
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
    text: root.status && root.status.present === true ? Status.batteryIcon(root.status) : root.idleIcon
    labelText: root.percentageLabel
    tooltipText: root.tooltipLabel
    active: root.status && root.status.state === "discharging" && root.status.percentage <= 15
    slotSize: Style.bar.iconSlot * (root.showPercentage && !root.verticalBar ? 2 : 1)
    onPressed: function(button) {
      if (button === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: Style.space(320)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(280))

    content: PanelKeyCatcher {
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Item {
          id: header
          width: parent.width
          implicitHeight: hero.implicitHeight
          readonly property bool ringVisible: false

          PanelHero {
            id: hero
            width: parent.width
            title: strings.t("battery.shareTitle")
            meta: root.shareState === "mounted"
              ? strings.t("battery.mountedAt").arg(root.shareDir)
              : (root.shareState === "unmounted" ? strings.t("battery.notMounted") : strings.t("battery.noShare"))
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: root.status && root.status.present === true ? Status.batteryIcon(root.status) : root.idleIcon
                color: root.foreground
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: powerSwitch
                checked: root.mountRunning ? root.wantMounted : root.shareState === "mounted"
                busy: root.mountRunning
                interactive: root.shareState !== "none"
                foreground: hero.foreground
                onToggled: root.toggleShare()

                PanelToolTip {
                  visible: powerSwitch.containsMouse
                  text: powerSwitch.checked ? strings.t("battery.unmount") : strings.t("battery.mount")
                  fontFamily: hero.fontFamily
                }
              }
            }
          }
        }

        Text {
          visible: root.status && root.status.present === true
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          text: root.tooltipLabel
        }

        Text {
          visible: root.shareState === "unmounted" && root.mountDir !== ""
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          elide: Text.ElideMiddle
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          text: root.mountDir
        }

        Button {
          visible: root.shareState === "unmounted"
          width: parent.width
          enabled: !root.mountRunning
          text: strings.t("battery.chooseMountDir")
          foreground: root.foreground
          onClicked: root.chooseMountDir()
        }

        Text {
          visible: root.mountMessage !== ""
          width: parent.width
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          text: root.mountMessage
        }
      }
    }
  }

  FolderDialog {
    id: folderDialog
    title: strings.t("battery.chooseMountDir")
    onAccepted: {
      root.mountDir = root.pathFromUrl(selectedFolder)
      root.open()
    }
    onRejected: root.open()
  }
}
