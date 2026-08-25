# Apple Notes for Omarchy

![Version](https://img.shields.io/badge/version-2.0.0-blue)

Menu bar widget for Omarchy that shows iCloud connection status, syncs Apple Notes via [icloud-md](https://github.com/icloud-md/icloud-md), and opens your notes directory in the file manager.

## Features

- 📔 Menu bar icon showing connection status
- 🔄 One-click iCloud sync (pull + push)
- 🔐 Browser-based iCloud authentication (via icloud-md)
- 📂 Open notes directory in Nautilus
- 📋 Recently changed notes list
- 🔁 Automatic status polling (every 60s)

## Requirements

- Omarchy Linux
- Node.js 20+
- `icloud-md` installed globally (`npm install -g icloud-md`)
- Apple ID with iCloud Notes enabled
- Advanced Data Protection must be **DISABLED**

## Installation

```bash
git clone https://github.com/YOUR_USER/omarchy-apple-notes.git ~/.config/omarchy/plugins/com.omarchy.apple-notes
./install.sh
omarchy plugin enable com.omarchy.apple-notes
```

## First-time setup

After enabling, click the 📔 icon in the menu bar, then click **Connect** and sign in via your browser. Once authenticated, click **Sync Now** to pull your notes from iCloud.

## Usage

- **Click** the 📔 icon to open the panel
- **Connect / Reconnect** — authenticate with iCloud
- **Sync Now** — pull and push notes to iCloud
- **Open Directory** — browse your notes in Nautilus

## Architecture

Pure QML service using `Quickshell.Process` to drive the `icloud-md` CLI. No external daemon, no HTTP bridge.

## License

MIT — see [LICENSE](LICENSE) for details.