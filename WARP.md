# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Auto Tab Discard is a browser extension that automatically reduces memory usage of inactive tabs using the native `chrome.tabs.discard` API. The extension supports both Manifest V2 (legacy) and Manifest V3 (modern) implementations, with versions for Chrome, Firefox, Edge, and Opera.

## Project Structure

```
├── v2/                   # Manifest V2 implementation (legacy)
│   ├── background.js     # Main background script
│   ├── plugins/          # Modular functionality plugins
│   ├── modes/            # Tab discarding strategies
│   └── data/             # UI components (popup, options, inject)
├── v3/                   # Manifest V3 implementation (current)
│   ├── worker/           # Service worker modules
│   │   ├── core.mjs      # Main service worker entry
│   │   ├── core/         # Core functionality modules
│   │   ├── plugins/      # Modular functionality plugins
│   │   └── modes/        # Tab discarding strategies
│   └── data/             # UI components (popup, options, inject)
└── _locales/             # Internationalization files
```

## High-Level Architecture

### Core Module System (v3)

The extension uses ES modules for clean separation of concerns:

```
worker/core.mjs (entry point)
├── core/prefs.mjs        # Preference management
├── core/discard.mjs      # Tab discarding logic
├── core/startup.mjs      # Initialization handlers
├── core/navigate.mjs     # Tab navigation commands
├── core/utils.mjs        # Utility functions
├── modes/number.mjs      # Number-based discard mode
├── menu.mjs              # Context menu management
└── plugins/loader.mjs    # Plugin system loader
```

### Message Flow

1. **Content Script → Service Worker**: Form input detection, visibility changes
   - `data/inject/watch.js` monitors form modifications and tab visibility
   - Sends `discard.on.load` messages for newly loaded tabs

2. **Service Worker → Tabs**: Tab discarding and manipulation
   - Uses `chrome.tabs.discard()` API for native memory management
   - Injects scripts to modify favicon/title for discarded tabs
   - Handles navigation commands (move-next, move-previous, close)

3. **External Extensions → Service Worker**: Remote control API
   - Accepts `discard` method with query parameters
   - Returns array of discarded tab IDs

### Key APIs and Permissions

- `chrome.tabs.discard`: Native tab suspension
- `chrome.idle`: Detect user inactivity
- `chrome.storage`: Preference persistence (local, managed, session)
- `chrome.alarms`: Scheduled discard operations
- `chrome.scripting`: Content script injection (v3)
- `chrome.contextMenus`: Right-click menu options
- `chrome.notifications`: User notifications

## Common Development Commands

### Loading the Extension

```bash
# Chrome/Edge - Manifest V3
# 1. Navigate to chrome://extensions or edge://extensions
# 2. Enable "Developer mode"
# 3. Click "Load unpacked" and select the v3/ directory

# Firefox - Manifest V2 (Firefox doesn't fully support V3 yet)
# 1. Navigate to about:debugging
# 2. Click "This Firefox"
# 3. Click "Load Temporary Add-on" and select v2/manifest.json
```

### Testing Tab Discard Functionality

```bash
# Monitor service worker logs (Chrome/Edge)
# 1. Open chrome://extensions
# 2. Click "service worker" link under the extension
# 3. Console will show logs if prefs.log = true

# Test discarding via console (from service worker console)
chrome.tabs.query({active: false}, tabs => {
  tabs.forEach(tab => chrome.tabs.discard(tab.id));
});

# Verify memory usage
# Chrome: chrome://system/ → "mem_usage"
# Edge: edge://system/ → "mem_usage"
```

### Debugging Service Workers and Content Scripts

```bash
# Service Worker debugging (Manifest V3)
# 1. chrome://extensions → "service worker" link
# 2. Set breakpoints in worker/*.mjs files
# 3. Use chrome.storage.local.set({log: true}) to enable logging

# Content Script debugging
# 1. Open any webpage
# 2. DevTools → Sources → Content Scripts → Auto Tab Discard
# 3. Set breakpoints in data/inject/watch.js
```

### Configuration and Storage

```bash
# View current preferences (from service worker console)
chrome.storage.local.get(null, console.log);

# Modify preferences programmatically
chrome.storage.local.set({
  'number': 10,           # Discard when more than 10 tabs
  'period': 600,          # Check every 10 minutes
  'simultaneous-jobs': 5  # Limit concurrent discards
});

# Reset to defaults
chrome.storage.local.clear();
```

### Testing Discard Modes

```bash
# Number-based mode (default)
chrome.storage.local.set({mode: 'number.based'});

# Time-based mode 
chrome.storage.local.set({mode: 'time.based'});

# URL-based mode
chrome.storage.local.set({mode: 'url.based'});
```

### Keyboard Shortcuts Testing

```bash
# View configured shortcuts
# Chrome: chrome://extensions/shortcuts
# Edge: edge://extensions/shortcuts

# Available commands:
# - discard-tab: Discard active tab
# - discard-window: Discard all tabs in window
# - discard-other-windows: Discard tabs in other windows
# - move-previous/move-next: Navigate between tabs
# - close: Close and move to next tab
```

## Key Configuration Options

The extension uses a comprehensive preference system managed through `schema.json`:

- **Discard Triggers**:
  - `period`: Time interval for checking tabs (seconds)
  - `number`: Maximum tabs before triggering discard
  - `idle-timeout`: User idle time before discarding

- **Discard Prevention**:
  - `audio`: Skip tabs playing audio
  - `pinned`: Skip pinned tabs
  - `form`: Skip tabs with unsaved forms
  - `whitelist`: Hostname/regex patterns to exclude

- **Visual Indicators**:
  - `favicon`: Modify favicon of discarded tabs
  - `prepends`: Prefix text for discarded tab titles (default: 💤)
  - `favicon-delay`: Delay before favicon modification

- **Performance**:
  - `simultaneous-jobs`: Max concurrent discard operations
  - `memory-value`: Memory threshold for discarding (MB)

## Browser Compatibility Notes

### Manifest V3 (v3/ directory)
- **Chrome**: Full support (88+)
- **Edge**: Full support (88+)
- **Firefox**: Partial support (use v2 for full compatibility)
- **Opera**: Full support (74+)

### Manifest V2 (v2/ directory)
- **Firefox**: Recommended version for Firefox
- **Chrome/Edge**: Being phased out, use v3
- Uses background pages instead of service workers
- Different permission model

## Extension Communication API

External extensions can control tab discarding:

```javascript
// From another extension
chrome.runtime.sendMessage(extensionId, {
  method: 'discard',
  query: {url: 'https://*.example.com/*'},
  forced: false  // Respect protection rules
}, response => {
  console.log('Discarded tabs:', response);
});
```

## Plugin System

The extension supports modular plugins in `worker/plugins/`:
- `startup/`: Discard tabs on browser startup
- `trash/`: Auto-close old discarded tabs
- `focus/`: Focus management for tab operations
- `youtube/`: Special handling for YouTube tabs
- `blank/`: Blank tab creation utilities

Each plugin exports handlers for specific extension events.
