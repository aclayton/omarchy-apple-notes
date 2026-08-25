# Apple Notes for Omarchy

![Version](https://img.shields.io/badge/version-2.0.0-blue)

Menu bar widget for Omarchy that shows iCloud connection status, syncs Apple Notes via [icloud-md](https://github.com/coddingtonbear/icloud-md), and opens your notes directory in the file manager.

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
omarchy plugin add https://github.com/aclayton/omarchy-apple-notes.git --enable
```

This clones the plugin into `~/.config/omarchy/plugins/com.omarchy.apple-notes/` and enables it. The shell hot-reloads automatically — no restart needed.

Then install the `icloud-md` dependency:

```bash
~/.config/omarchy/plugins/com.omarchy.apple-notes/install.sh
```

## First-time setup

After enabling, click the 📔 icon in the menu bar, then click **Connect** and sign in via your browser. Once authenticated, click **Sync Now** to pull your notes from iCloud.

If this is your first time using icloud-md with this account, run the initial clone first:

```bash
icloud-md clone ~/.omarchy/apple-notes
```

## Usage

- **Click** the 📔 icon to open the panel
- **Connect / Reconnect** — authenticate with iCloud
- **Sync Now** — pull and push notes to iCloud
- **Open Directory** — browse your notes in Nautilus

## Manual installation

If you prefer to install by hand:

```bash
git clone https://github.com/aclayton/omarchy-apple-notes.git ~/.config/omarchy/plugins/com.omarchy.apple-notes
omarchy plugin enable com.omarchy.apple-notes
```

## Architecture

Pure QML service using `Quickshell.Process` to drive the `icloud-md` CLI. No external daemon, no HTTP bridge.

## License

MIT — see [LICENSE](LICENSE) for details.