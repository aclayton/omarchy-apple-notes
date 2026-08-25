#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Apple Notes Omarchy Plugin — Install Script (v2.0.0)
# ─────────────────────────────────────────────────────────────────────────────
# Installs the icloud-md CLI dependency, creates the local notes directory,
# and guides the user through enabling the plugin in Omarchy.
#
# Idempotent — safe to run multiple times.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

info()  { printf "${GREEN}✔${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
err()   { printf "${RED}✘${NC} %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

# ── Paths ───────────────────────────────────────────────────────────────────
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/com.omarchy.apple-notes"
NOTES_DIR="${HOME}/.omarchy/apple-notes"
SHELL_JSON="${HOME}/.config/omarchy/shell.json"
PLUGIN_ID="com.omarchy.apple-notes"

# ── Step 1: Check prerequisites ─────────────────────────────────────────────
header "Checking prerequisites"

# Node.js
if ! command -v node &>/dev/null; then
  err "Node.js is not installed."
  err "icloud-md requires Node.js 20 or later."
  err ""
  err "Install it via your package manager, e.g.:"
  err "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  err "  sudo apt-get install -y nodejs"
  err ""
  err "Or use nvm / fnm / asdf to manage Node versions."
  exit 1
fi

NODE_VERSION=$(node --version | sed 's/^v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)

if [ "$NODE_MAJOR" -lt 20 ]; then
  err "Node.js $NODE_VERSION detected — icloud-md requires Node.js 20+."
  err "Please upgrade Node.js and re-run this script."
  exit 1
fi
info "Node.js $NODE_VERSION — OK"

# npm
if ! command -v npm &>/dev/null; then
  err "npm is not available. It should be bundled with Node.js."
  exit 1
fi
info "npm $(npm --version) — OK"

# npx
if ! command -v npx &>/dev/null; then
  err "npx is not available. It should be bundled with Node.js."
  exit 1
fi
info "npx — OK"

# ── Step 2: Install icloud-md ───────────────────────────────────────────────
header "Installing icloud-md"

if command -v icloud-md &>/dev/null; then
  ICLOUD_MD_VERSION=$(icloud-md --version 2>/dev/null || echo "unknown")
  info "icloud-md already installed ($ICLOUD_MD_VERSION)"
else
  info "Installing icloud-md globally via npm …"
  if npm install -g icloud-md; then
    info "icloud-md installed successfully"
  else
    err "Failed to install icloud-md."
    err "Try running with sudo if you hit permission errors:"
    err "  sudo npm install -g icloud-md"
    exit 1
  fi
fi

# Verify the binary is on PATH
if ! command -v icloud-md &>/dev/null; then
  warn "icloud-md binary not found on PATH after install."
  warn "This can happen if your npm global bin directory is not in PATH."
  NPM_GLOBAL_BIN=$(npm config get prefix 2>/dev/null || echo "")
  if [ -n "$NPM_GLOBAL_BIN" ]; then
    warn "npm global prefix is: $NPM_GLOBAL_BIN"
    warn "Try adding this to your shell profile:"
    warn "  export PATH=\"$NPM_GLOBAL_BIN/bin:\$PATH\""
  fi
  exit 1
fi

# ── Step 3: Create notes directory ──────────────────────────────────────────
header "Creating notes directory"

if [ -d "$NOTES_DIR" ]; then
  info "Notes directory already exists: $NOTES_DIR"
else
  mkdir -p "$NOTES_DIR"
  info "Created notes directory: $NOTES_DIR"
fi

# ── Step 4: Check plugin enablement ─────────────────────────────────────────
header "Plugin enablement"

PLUGIN_ENABLED=false

if [ -f "$SHELL_JSON" ]; then
  # Try to detect if the plugin ID appears in shell.json (basic grep — works
  # for both array-of-strings and object-with-id formats).
  if grep -qF "\"$PLUGIN_ID\"" "$SHELL_JSON" 2>/dev/null; then
    PLUGIN_ENABLED=true
    info "Plugin is already listed in shell.json"
  fi
fi

if [ "$PLUGIN_ENABLED" = false ]; then
  warn "Plugin is not yet enabled in Omarchy."
  echo ""
  echo "  Enable it with:"
  echo ""
  echo "    ${BOLD}omarchy plugin enable $PLUGIN_ID${NC}"
  echo ""
  echo "  Or add it manually to ${BOLD}$SHELL_JSON${NC}"
  echo "  under the \"plugins\" key."
fi

# ── Step 5: Next steps ──────────────────────────────────────────────────────
header "Next steps"

echo ""
echo "  1. ${BOLD}Enable the plugin${NC} (if not already done):"
echo "       omarchy plugin enable $PLUGIN_ID"
echo ""
echo "  2. ${BOLD}Restart Omarchy${NC} to load the plugin."
echo ""
echo "  3. ${BOLD}Clone your iCloud Notes${NC} (first-time setup):"
echo "       icloud-md clone $NOTES_DIR"
echo ""
echo "     This will open a browser for iCloud authentication."
echo "     Note: icloud-md downloads Chromium (~150 MB) on first run."
echo ""
echo "  4. ${BOLD}Sync notes${NC} after cloning:"
echo "       icloud-md pull $NOTES_DIR"
echo "       icloud-md push $NOTES_DIR"
echo ""
echo "  ${YELLOW}Important prerequisites for icloud-md:${NC}"
echo "    • An Apple ID with iCloud Notes enabled"
echo "    • Advanced Data Protection must be ${BOLD}DISABLED${NC} on the account"
echo "    • First run downloads Chromium (~150 MB) for Playwright-based auth"
echo ""

info "Installation complete."
exit 0