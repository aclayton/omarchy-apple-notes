import QtQuick
import Quickshell
import Quickshell.Io

// Service.qml — Apple Notes iCloud sync service
// Shells out to the icloud-md CLI instead of using an external Node.js bridge.

Item {
  id: root

  readonly property string _home: Quickshell.env("HOME") || ""
  readonly property string _notesDir: _home + "/.omarchy/apple-notes"

  // ── Public properties ──────────────────────────────────────────────

  property bool isAuthenticated: false
  property string lastSyncTime: "Never"
  property string localDirectory: _notesDir
  property int changedNotesCount: 0
  property var changedNotesList: []
  property string connectionStatus: "Disconnected"  // Disconnected | Connecting… | Connected | Syncing… | Cloning…
  property string errorMessage: ""

  // ── Internal state ─────────────────────────────────────────────────

  readonly property bool busy:
    verifyAuthProcess.running || reauthProcess.running ||
    pullProcess.running || pushProcess.running ||
    statusProcess.running || cloneProcess.running ||
    findProcess.running

  property string _pendingAction: ""   // "authenticate" | "sync"

  property string _authOutput: ""
  property string _authError: ""
  property string _syncOutput: ""
  property string _syncError: ""
  property string _statusOutput: ""
  property string _statusError: ""
  property string _cloneOutput: ""
  property string _cloneError: ""
  property string _findOutput: ""
  property string _findError: ""

  // ── Public methods ─────────────────────────────────────────────────

  function clearError() {
    root.errorMessage = ""
  }

  function authenticate() {
    if (verifyAuthProcess.running || reauthProcess.running) return
    root.clearError()
    root.connectionStatus = "Connecting..."
    root._pendingAction = "authenticate"
    root._authOutput = ""
    root._authError = ""
    verifyAuthProcess.command = ["icloud-md", "verify-auth", root._notesDir]
    verifyAuthProcess.running = true
  }

  function syncNotes() {
    if (pullProcess.running || pushProcess.running) return
    root.clearError()
    if (root.isAuthenticated) {
      _startPull()
    } else {
      root._pendingAction = "sync"
      root._authOutput = ""
      root._authError = ""
      verifyAuthProcess.command = ["icloud-md", "verify-auth", root._notesDir]
      verifyAuthProcess.running = true
    }
  }

  function _startPull() {
    root.connectionStatus = "Syncing..."
    root._syncOutput = ""
    root._syncError = ""
    pullProcess.command = ["icloud-md", "pull", root._notesDir]
    pullProcess.running = true
  }

  function _startPush() {
    root._syncOutput = ""
    root._syncError = ""
    pushProcess.command = ["icloud-md", "push", root._notesDir]
    pushProcess.running = true
  }

  function refreshChangedNotes() {
    if (findProcess.running) return
    root._findOutput = ""
    root._findError = ""
    findProcess.command = ["find", root._notesDir, "-name", "*.md", "-printf", "%T@ %p\\n"]
    findProcess.running = true
  }

  function getStatus() {
    if (statusProcess.running) return
    root._statusOutput = ""
    root._statusError = ""
    statusProcess.command = ["icloud-md", "status", root._notesDir, "--json"]
    statusProcess.running = true
  }

  function cloneNotes() {
    if (cloneProcess.running) return
    root.clearError()
    root.connectionStatus = "Cloning..."
    root._cloneOutput = ""
    root._cloneError = ""
    cloneProcess.command = ["icloud-md", "clone", root._notesDir]
    cloneProcess.running = true
  }

  // ── Helpers ────────────────────────────────────────────────────────

  function _formatTime(ts) {
    var secs = parseFloat(ts)
    if (!isFinite(secs) || secs <= 0) return "Unknown"
    var d = new Date(secs * 1000)
    return d.toLocaleString()
  }

  function _parseFindOutput(raw) {
    var list = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "") continue
      var spaceIdx = line.indexOf(" ")
      if (spaceIdx < 0) continue
      var ts = parseFloat(line.substring(0, spaceIdx))
      var path = line.substring(spaceIdx + 1)
      if (!isFinite(ts)) continue
      var parts = path.split("/")
      var fname = parts[parts.length - 1]
      var title = fname.replace(/\.md$/, "")
      list.push({
        title: title,
        fileName: path,
        modified: root._formatTime(ts),
        _ts: ts
      })
    }
    list.sort(function(a, b) { return b._ts - a._ts })
    list = list.slice(0, 10)
    return list
  }

  function _applyStatus(raw) {
    try {
      var status = JSON.parse(String(raw || "{}"))
      if (typeof status.authenticated === "boolean") {
        root.isAuthenticated = status.authenticated
      }
      if (typeof status.lastSync === "string" && status.lastSync !== "") {
        root.lastSyncTime = status.lastSync
      }
      if (root.isAuthenticated && root.connectionStatus === "Disconnected") {
        root.connectionStatus = "Connected"
      }
    } catch (e) {
      console.log("Apple Notes: failed to parse status JSON:", e.message)
    }
  }

  // ── Processes ──────────────────────────────────────────────────────

  Process {
    id: mkdirProcess
    running: false
    command: []
    onExited: {
      root.getStatus()
    }
  }

  Process {
    id: verifyAuthProcess
    running: false
    command: []
    stdout: StdioCollector { id: verifyAuthStdout; waitForEnd: true; onStreamFinished: root._authOutput = text }
    stderr: StdioCollector { id: verifyAuthStderr; waitForEnd: true; onStreamFinished: root._authError = text }
    onExited: function(exitCode) {
      var action = root._pendingAction
      root._pendingAction = ""

      if (exitCode === 0) {
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""

        if (action === "sync") {
          root._startPull()
        }
      } else {
        if (action === "authenticate") {
          root._authOutput = ""
          root._authError = ""
          reauthProcess.command = ["icloud-md", "reauthenticate", root._notesDir]
          reauthProcess.running = true
        } else if (action === "sync") {
          root.errorMessage = "Not authenticated. Please connect first."
          root.connectionStatus = "Disconnected"
        }
      }
    }
  }

  Process {
    id: reauthProcess
    running: false
    command: []
    stdout: StdioCollector { id: reauthStdout; waitForEnd: true; onStreamFinished: root._authOutput = text }
    stderr: StdioCollector { id: reauthStderr; waitForEnd: true; onStreamFinished: root._authError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""
      } else {
        root.isAuthenticated = false
        root.connectionStatus = "Disconnected"
        root.errorMessage = root._authError || root._authOutput || "Authentication failed"
      }
    }
  }

  Process {
    id: pullProcess
    running: false
    command: []
    stdout: StdioCollector { id: pullStdout; waitForEnd: true; onStreamFinished: root._syncOutput = text }
    stderr: StdioCollector { id: pullStderr; waitForEnd: true; onStreamFinished: root._syncError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root._startPush()
      } else {
        root.connectionStatus = "Connected"
        root.errorMessage = root._syncError || root._syncOutput || "Pull failed"
      }
    }
  }

  Process {
    id: pushProcess
    running: false
    command: []
    stdout: StdioCollector { id: pushStdout; waitForEnd: true; onStreamFinished: root._syncOutput = text }
    stderr: StdioCollector { id: pushStderr; waitForEnd: true; onStreamFinished: root._syncError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.lastSyncTime = new Date().toLocaleString()
        root.connectionStatus = "Connected"
        root.errorMessage = ""
        root.refreshChangedNotes()
      } else {
        root.connectionStatus = "Connected"
        root.errorMessage = root._syncError || root._syncOutput || "Push failed"
      }
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root._applyStatus(root._statusOutput)
      }
      // Non-zero exit from status is not necessarily fatal — may just mean
      // the directory hasn't been set up yet.
    }
  }

  Process {
    id: cloneProcess
    running: false
    command: []
    stdout: StdioCollector { id: cloneStdout; waitForEnd: true; onStreamFinished: root._cloneOutput = text }
    stderr: StdioCollector { id: cloneStderr; waitForEnd: true; onStreamFinished: root._cloneError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""
        root.refreshChangedNotes()
      } else {
        root.connectionStatus = "Disconnected"
        root.errorMessage = root._cloneError || root._cloneOutput || "Clone failed"
      }
    }
  }

  Process {
    id: findProcess
    running: false
    command: []
    stdout: StdioCollector { id: findStdout; waitForEnd: true; onStreamFinished: root._findOutput = text }
    stderr: StdioCollector { id: findStderr; waitForEnd: true; onStreamFinished: root._findError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var list = root._parseFindOutput(root._findOutput)
        root.changedNotesList = list
        root.changedNotesCount = list.length
      }
    }
  }

  // ── Initialization ─────────────────────────────────────────────────

  Component.onCompleted: {
    console.log("Apple Notes service initialized")
    mkdirProcess.command = ["mkdir", "-p", root._notesDir]
    mkdirProcess.running = true
  }
}