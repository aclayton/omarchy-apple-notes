import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Widget.qml - Menu bar widget for Apple Notes plugin
// Displays a button in the menu bar and a popup panel with iCloud status

Panel {
  id: root
  moduleName: "com.omarchy.apple-notes"
  ipcTarget: "com.omarchy.apple-notes"
  
  // Access the service
  readonly property var notesService: bar && bar.shell && bar.shell.serviceFor
    ? bar.shell.serviceFor(root.moduleName)
    : null
  
  // Status properties
  readonly property bool isAuthenticated: notesService ? notesService.isAuthenticated : false
  readonly property string lastSyncTime: notesService ? notesService.lastSyncTime : "Never"
  readonly property string localDirectory: notesService ? notesService.localDirectory : "~/.omarchy/apple-notes"
  readonly property int changedNotesCount: notesService ? notesService.changedNotesCount : 0
  readonly property var changedNotesList: notesService ? notesService.changedNotesList : []
  readonly property string connectionStatus: notesService ? notesService.connectionStatus : "Disconnected"
  readonly property string errorMessage: notesService ? notesService.errorMessage : ""
  
  // Widget-local error for when the service itself is missing — that case can't
  // be written into notesService.errorMessage, so it lives here instead.
  property string widgetError: ""
  
  // When the status was last refreshed by the widget's polling.
  property string lastChecked: "Never"
  
  // A sync/connect/clone operation is in flight.
  readonly property bool isBusy: connectionStatus === "Connecting..."
    || connectionStatus === "Syncing..."
    || connectionStatus === "Cloning..."
  
  // Human-facing status, including the transitional states.
  readonly property string connectionStatusText: connectionStatus === "Connecting..." ? "Connecting..."
    : connectionStatus === "Syncing..." ? "Syncing..."
    : connectionStatus === "Cloning..." ? "Cloning..."
    : isAuthenticated ? "Connected" : "Disconnected"
  
  readonly property string statusColor: isBusy ? "#FF9800"
    : isAuthenticated ? "#4CAF50" : "#F44336"
  
  // Connect button reflects state and is disabled while connecting/cloning.
  readonly property string connectButtonText: connectionStatus === "Connecting..." ? "Connecting..."
    : isAuthenticated ? "Reconnect" : "Connect"
  readonly property bool connectButtonEnabled: connectionStatus !== "Connecting..."
    && connectionStatus !== "Cloning..."
  
  // Sync Now is disabled while syncing/cloning.
  readonly property bool syncButtonEnabled: connectionStatus !== "Syncing..."
    && connectionStatus !== "Cloning..."
  
  readonly property string effectiveError: errorMessage !== "" ? errorMessage : widgetError
  
  // Icon (using a notebook emoji as placeholder)
  readonly property string icon: "\ud83d\udcd3"
  readonly property string statusText: isAuthenticated ? "Connected" : "Disconnected"
  
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  
  function syncNotes() {
    if (notesService) {
      widgetError = ""
      notesService.syncNotes()
    } else {
      widgetError = "No notes service available. The Apple Notes service may not be running."
    }
  }
  
  function authenticate() {
    if (notesService) {
      widgetError = ""
      notesService.authenticate()
    } else {
      widgetError = "No notes service available. The Apple Notes service may not be running."
    }
  }
  
  // The service may hand back an ISO string (from icloud-md), an already
  // formatted locale string, or "Never". Normalise the ISO case to a readable
  // date/time and pass everything else through.
  function formatSyncTime(raw) {
    if (!raw || raw === "Never" || raw === "null") return "Never"
    var d = new Date(raw)
    if (isNaN(d.getTime())) return raw
    return d.toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm:ss")
  }
  
  readonly property string formattedLastSyncTime: root.formatSyncTime(lastSyncTime)
  
  // Poll the service for fresh status and stamp when it happened. Falls back
  // to the legacy method name so the widget keeps working across the service
  // rewrite boundary.
  function refreshStatus() {
    if (!notesService) return
    if (typeof notesService.getStatus === "function") notesService.getStatus()
    else if (typeof notesService.getNotesStatus === "function") notesService.getNotesStatus()
    lastChecked = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm:ss")
  }
  
  // Periodic status refresh.
  Timer {
    id: statusRefreshTimer
    interval: 60000
    running: root.notesService !== null
    repeat: true
    onTriggered: root.refreshStatus()
  }
  
  Component.onCompleted: root.refreshStatus()
  
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    slotSize: Style.bar.statusSlot
    dimmed: !root.isAuthenticated
    active: root.opened
    tooltipText: "Apple Notes - " + root.statusText
    onPressed: function (mouseButton) {
      console.log("Menu bar button pressed")
      root.toggle()
    }
  }
  
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)
    
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      
      Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Style.space(14)
        
        // ---------- Hero: icon · title/status ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)
          
          Text {
            id: heroIcon
            text: root.icon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          
          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            
            Text {
              text: "Apple Notes"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }
            
            Text {
              text: root.statusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }
        
        PanelSeparator {
          foreground: root.bar.foreground
        }
        
        // ---------- Connection Status ----------
        Column {
          width: parent.width
          spacing: Style.space(8)
          
          Text {
            text: "iCloud Connection"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          
          Row {
            width: parent.width
            spacing: Style.space(10)
            
            // Small spinning indicator, visible only while an operation runs.
            Text {
              id: busySpinner
              text: "↻"
              visible: root.isBusy
              color: root.statusColor
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
              transformOrigin: Item.Center
              
              RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.isBusy
              }
            }
            
            Text {
              text: root.connectionStatusText
              color: root.statusColor
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
            
            Button {
              text: root.connectButtonText
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              opacity: root.connectButtonEnabled ? 1 : 0.45
              onClicked: {
                if (!root.connectButtonEnabled) return
                root.authenticate()
              }
            }
          }
        }
        
        PanelSeparator {
          foreground: root.bar.foreground
        }
        
        // ---------- Sync Information ----------
        Column {
          width: parent.width
          spacing: Style.space(8)
          
          Text {
            text: "Sync Information"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          
          Grid {
            columns: 2
            width: parent.width
            columnSpacing: Style.space(10)
            rowSpacing: Style.space(4)
            
            Text {
              text: "Last Sync:"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              opacity: 0.7
            }
            
            Text {
              text: root.formattedLastSyncTime
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width * 0.7
            }
            
            Text {
              text: "Local Directory:"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              opacity: 0.7
            }
            
            Text {
              text: root.localDirectory
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width * 0.7
            }
            
            Text {
              text: "Changed Notes:"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              opacity: 0.7
            }
            
            Text {
              text: root.changedNotesCount.toString()
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            
            Text {
              text: "Last Checked:"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              opacity: 0.7
            }
            
            Text {
              text: root.lastChecked
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width * 0.7
            }
          }
        }
        
        // ---------- Changed Notes List ----------
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.changedNotesCount > 0
          
          Text {
            text: "Recently Changed Notes"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
          
          Repeater {
            model: root.changedNotesList
            
            Rectangle {
              width: parent.width
              height: noteColumn.implicitHeight + Style.space(8)
              color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.1)
              radius: 4
              
              Column {
                id: noteColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(4) }
                spacing: Style.space(2)
                
                Text {
                  text: modelData.title
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }
                
                Text {
                  text: "Modified: " + modelData.modified
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }
        }
        
        // ---------- Actions ----------
        Row {
          width: parent.width
          spacing: Style.space(6)
          
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Sync Now"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            opacity: root.syncButtonEnabled ? 1 : 0.45
            onClicked: {
              if (!root.syncButtonEnabled) return
              root.syncNotes()
            }
          }
          
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Open Directory"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: {
              Quickshell.execDetached(["uwsm-app", "--", "nautilus", root.localDirectory])
            }
          }
        }
        
        // ---------- Error Message ----------
        Rectangle {
          width: parent.width
          height: errorText.implicitHeight + Style.space(10)
          color: Qt.rgba(0.94, 0.27, 0.27, 0.14)
          radius: 4
          border.color: "#F44336"
          border.width: 1
          visible: root.effectiveError !== ""
          
          Text {
            id: errorText
            anchors {
              left: parent.left
              right: parent.right
              verticalCenter: parent.verticalCenter
              margins: Style.space(5)
            }
            wrapMode: Text.Wrap
            text: root.effectiveError
            color: "#F44336"
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }
      }
    }
  }
}
