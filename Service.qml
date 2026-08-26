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
  property string connectionStatus: "Disconnected"  // Disconnected | Connecting… | Connected | Syncing… | Cloning…
  property string errorMessage: ""

  // ── Internal state ─────────────────────────────────────────────────

  readonly property bool busy:
    verifyAuthProcess.running || reauthProcess.running ||
    pullProcess.running || pushProcess.running ||
    statusProcess.running || cloneProcess.running

  property string _pendingAction: ""   // "authenticate" | "sync"

  property string _authOutput: ""
  property string _authError: ""
  property string _syncOutput: ""
  property string _syncError: ""
  property string _statusOutput: ""
  property string _statusError: ""
  property string _cloneOutput: ""
  property string _cloneError: ""

  // ── Public methods ─────────────────────────────────────────────────

  function clearError() {
    root.errorMessage = ""
  }

  function authenticate() {
    if (verifyAuthProcess.running || reauthProcess.running) return
    console.log("[apple-notes] authenticate(): verifying auth")
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
    console.log("[apple-notes] syncNotes(): isAuthenticated=" + root.isAuthenticated)
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
    console.log("[apple-notes] pulling from iCloud…")
    root.connectionStatus = "Syncing..."
    root._syncOutput = ""
    root._syncError = ""
    pullProcess.command = ["icloud-md", "pull", root._notesDir]
    pullProcess.running = true
  }

  function _startPush() {
    console.log("[apple-notes] pushing to iCloud…")
    root._syncOutput = ""
    root._syncError = ""
    pushProcess.command = ["icloud-md", "push", root._notesDir]
    pushProcess.running = true
  }

  function getStatus() {
    if (statusProcess.running) return
    console.log("[apple-notes] refreshing status")
    root._statusOutput = ""
    root._statusError = ""
    statusProcess.command = ["icloud-md", "status", root._notesDir, "--json"]
    statusProcess.running = true
  }

  function cloneNotes() {
    if (cloneProcess.running) return
    console.log("[apple-notes] cloneNotes(): initial clone requested")
    root.clearError()
    root.connectionStatus = "Cloning..."
    root._cloneOutput = ""
    root._cloneError = ""
    cloneProcess.command = ["icloud-md", "clone", root._notesDir]
    cloneProcess.running = true
  }

  // ── Helpers ────────────────────────────────────────────────────────

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
      console.warn("[apple-notes] failed to parse status JSON:", e.message)
    }
  }

  // ── Processes ──────────────────────────────────────────────────────

  Process {
    id: mkdirProcess
    running: false
    command: []
    onExited: function(exitCode) {
      if (exitCode === 0) {
        console.log("[apple-notes] notes directory ready:", root._notesDir)
      } else {
        console.warn("[apple-notes] could not create notes directory (exit " + exitCode + ")")
      }
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
        console.log("[apple-notes] verify-auth OK (authenticated)")
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""

        if (action === "sync") {
          root._startPull()
        }
      } else {
        console.warn("[apple-notes] verify-auth failed (exit " + exitCode + "), action=" + action)
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
        console.log("[apple-notes] reauthenticate OK")
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""
      } else {
        console.warn("[apple-notes] reauthenticate failed (exit " + exitCode + ")")
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
        console.log("[apple-notes] pull OK")
        root._startPush()
      } else {
        console.warn("[apple-notes] pull failed (exit " + exitCode + "): " + (root._syncError || root._syncOutput))
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
        console.log("[apple-notes] push OK — sync complete")
        root.lastSyncTime = new Date().toLocaleString()
        root.connectionStatus = "Connected"
        root.errorMessage = ""
      } else {
        console.warn("[apple-notes] push failed (exit " + exitCode + "): " + (root._syncError || root._syncOutput))
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
      } else {
        // Non-zero exit is not necessarily fatal — may just mean the
        // directory hasn't been set up yet.
        console.log("[apple-notes] status exited " + exitCode + " (vault may not be set up yet)")
      }
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
        console.log("[apple-notes] clone OK")
        root.isAuthenticated = true
        root.connectionStatus = "Connected"
        root.lastSyncTime = new Date().toLocaleString()
        root.errorMessage = ""
      } else {
        console.warn("[apple-notes] clone failed (exit " + exitCode + "): " + (root._cloneError || root._cloneOutput))
        root.connectionStatus = "Disconnected"
        root.errorMessage = root._cloneError || root._cloneOutput || "Clone failed"
      }
    }
  }

  // ── Initialization ─────────────────────────────────────────────────

  Component.onCompleted: {
    console.log("[apple-notes] service initialized, notes dir = " + root._notesDir)
    mkdirProcess.command = ["mkdir", "-p", root._notesDir]
    mkdirProcess.running = true
  }
}
