.pragma library

var staleAfterMs = 90000
var futureSkewMs = 120000
var maxTextLength = 4096
var maxTimeSeconds = 864000
var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

function parseStatus(text, nowMs) {
  if (typeof text !== "string" || text.length === 0 || text.length > maxTextLength) return null
  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (e) {
    return null
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null
  if (parsed.version !== 1) return null
  if (typeof parsed.present !== "boolean") return null
  if (typeof parsed.acConnected !== "boolean") return null
  if (typeof parsed.updatedAt !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(parsed.updatedAt)) return null
  var updated = Date.parse(parsed.updatedAt)
  if (!isFinite(updated)) return null
  var skew = nowMs - updated
  if (!isFinite(skew)) return null

  var percentage = null
  var state = null
  if (parsed.present) {
    if (!isWholeNumber(parsed.percentage) || parsed.percentage < 0 || parsed.percentage > 100) return null
    if (!allowedState(parsed.state)) return null
    percentage = parsed.percentage
    state = parsed.state
  } else if (parsed.percentage != null || (parsed.state != null && parsed.state !== "")) {
    return null
  }

  var timeToEmptySeconds = optionalSeconds(parsed.timeToEmptySeconds)
  var timeToFullSeconds = optionalSeconds(parsed.timeToFullSeconds)
  if (timeToEmptySeconds === false || timeToFullSeconds === false) return null

  return {
    present: parsed.present,
    percentage: percentage,
    state: state,
    acConnected: parsed.acConnected,
    timeToEmptySeconds: timeToEmptySeconds,
    timeToFullSeconds: timeToFullSeconds,
    stale: skew > staleAfterMs || skew < -futureSkewMs
  }
}

function allowedState(state) {
  return state === "charging"
    || state === "discharging"
    || state === "full"
    || state === "not-charging"
    || state === "unknown"
}

function optionalSeconds(value) {
  if (value == null) return null
  if (!isWholeNumber(value) || value < 0 || value > maxTimeSeconds) return false
  return value
}

function isWholeNumber(value) {
  return typeof value === "number" && isFinite(value) && Math.floor(value) === value
}

function stateKey(state) {
  if (state === "charging") return "battery.charging"
  if (state === "discharging") return "battery.discharging"
  if (state === "full") return "battery.full"
  if (state === "not-charging") return "battery.notCharging"
  return "battery.unknown"
}

function batteryIcon(status) {
  if (!status || status.present !== true || typeof status.percentage !== "number") return ""
  var index = Math.max(0, Math.min(9, Math.floor(status.percentage * 10 / 100)))
  if (status.state === "full") return "󰂅"
  if (status.state === "charging") return chargingIcons[index]
  return defaultIcons[index]
}

function estimate(status) {
  if (!status || status.present !== true || status.stale === true) return null
  var seconds = null
  var kind = ""
  if (status.state === "discharging") {
    seconds = status.timeToEmptySeconds
    kind = "empty"
  } else if (status.state === "charging") {
    seconds = status.timeToFullSeconds
    kind = "full"
  } else {
    return null
  }
  if (!isWholeNumber(seconds)) return null
  var minutesTotal = Math.floor(seconds / 60)
  return {
    kind: kind,
    hours: Math.floor(minutesTotal / 60),
    minutes: minutesTotal % 60
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    stateKey: stateKey,
    batteryIcon: batteryIcon,
    estimate: estimate
  }
}
