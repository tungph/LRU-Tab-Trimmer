# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

LRU Tab Trimmer is a browser extension that automatically reduces memory usage of inactive tabs using Firefox's native `browser.tabs.discard` API with an LRU (Least Recently Used) strategy. This extension is optimized specifically for Firefox using Manifest V2.

## Project Structure

```
├── background.js         # Main background script
├── firefox.js           # Firefox-specific implementations
├── hidden.js            # Hidden tab management
├── menu.js              # Context menu management
├── plugins.js           # Plugin system loader
├── plugins/             # Modular functionality plugins
│   ├── startup/         # Discard tabs on browser startup
│   ├── trash/           # Auto-close old discarded tabs
│   ├── focus/           # Focus management for tab operations
│   └── youtube/         # Special handling for YouTube tabs
├── modes/               # Tab discarding strategies
│   └── number.js        # Number-based discard mode
├── data/                # UI components
│   ├── popup/           # Popup interface
│   ├── options/         # Options page
│   └── inject/          # Content scripts
└── _locales/            # Internationalization files
```

## High-Level Architecture

### Core Module System

The extension uses a modular background script architecture:

```
background.js (main entry)
├── firefox.js            # Firefox-specific API polyfills
├── hidden.js             # Hidden tab management
├── plugins.js            # Plugin system loader
├── modes/number.js       # Number-based discard mode
└── menu.js               # Context menu and commands
```

### Message Flow

1. **Content Script → Background Script**: Form input detection, visibility changes
   - `data/inject/watch.js` monitors form modifications and tab visibility
   - Sends `discard.on.load` messages for newly loaded tabs

2. **Background Script → Tabs**: Tab discarding and manipulation
   - Uses `browser.tabs.discard()` API for native memory management
   - Injects scripts to modify favicon/title for discarded tabs
   - Handles navigation commands (move-next, move-previous, close)

3. **External Extensions → Background Script**: Remote control API
   - Accepts `discard` method with query parameters
   - Returns array of discarded tab IDs

### Key APIs and Permissions

- `browser.tabs.discard`: Native tab suspension (Firefox-specific)
- `browser.idle`: Detect user inactivity
- `browser.storage`: Preference persistence (local, managed)
- `browser.alarms`: Scheduled discard operations
- `browser.tabs.executeScript`: Content script injection
- `browser.contextMenus`: Right-click menu options
- `browser.notifications`: User notifications

## Common Development Commands

### Quick Start with Makefile

```bash
# Install development tools (web-ext)
make install-tools

# Run extension in Firefox with auto-reload (development mode)
make dev

# Build and package the extension
make package

# Run linting and validation
make lint

# Check your development environment
make doctor

# View all available commands
make help
```

### Loading the Extension

```bash
# Firefox Development
# 1. Navigate to about:debugging
# 2. Click "This Firefox"
# 3. Click "Load Temporary Add-on"
# 4. Select manifest.json from the repository root

# Firefox Permanent Installation
# 1. Build the extension: zip -r extension.xpi * -x ".*" -x "misc/*"
# 2. Navigate to about:addons
# 3. Click the gear icon → "Install Add-on From File"
# 4. Select the extension.xpi file
```

### Testing Tab Discard Functionality

```bash
# Monitor background script logs
# 1. Open about:debugging
# 2. Click "Inspect" next to the extension
# 3. Console will show logs if prefs.log = true

# Test discarding via console (from extension console)
browser.tabs.query({active: false}, tabs => {
  tabs.forEach(tab => browser.tabs.discard(tab.id));
});

# Verify memory usage
# Firefox: about:memory → "Measure"
# Firefox: about:performance → View tab memory usage
```

### Debugging Background and Content Scripts

```bash
# Background Script debugging
# 1. about:debugging → "Inspect" button
# 2. Set breakpoints in background.js, menu.js, etc.
# 3. Use browser.storage.local.set({log: true}) to enable logging

# Content Script debugging
# 1. Open any webpage
# 2. DevTools → Debugger → Search for "watch.js"
# 3. Set breakpoints in data/inject/watch.js
```

### Configuration and Storage

```bash
# View current preferences (from extension console)
browser.storage.local.get(null, console.log);

# Modify preferences programmatically
browser.storage.local.set({
  'number': 10,           # Discard when more than 10 tabs
  'period': 600,          # Check every 10 minutes
  'simultaneous-jobs': 5  # Limit concurrent discards
});

# Reset to defaults
browser.storage.local.clear();
```

### Testing Discard Modes

```bash
# Number-based mode (default)
browser.storage.local.set({mode: 'number.based'});

# Time-based mode 
browser.storage.local.set({mode: 'time.based'});

# URL-based mode
browser.storage.local.set({mode: 'url.based'});
```

### Keyboard Shortcuts Testing

```bash
# View configured shortcuts
# Firefox: about:addons → Manage Extension → Manage Extension Shortcuts

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

## Firefox-Specific Implementation Notes

- Uses Manifest V2 with event pages (non-persistent background scripts)
- Implements `autoDiscardable` property via firefox.js polyfill
- Supports Tree Style Tab integration for tree-based discarding
- Uses `browser.tabs.executeScript` for content script injection
- Handles about:blank tabs with special Firefox-specific logic

## Extension Communication API

External Firefox extensions can control tab discarding:

```javascript
// From another Firefox extension
browser.runtime.sendMessage(extensionId, {
  method: 'discard',
  query: {url: 'https://*.example.com/*'},
  forced: false  // Respect protection rules
}, response => {
  console.log('Discarded tabs:', response);
});
```

## Plugin System

The extension supports modular plugins in `plugins/`:
- `startup/`: Discard tabs on browser startup
- `trash/`: Auto-close old discarded tabs
- `focus/`: Focus management for tab operations
- `youtube/`: Special handling for YouTube tabs
- `previous/`: Previous tab restoration
- `next/`: Next tab navigation
- `new/`: New tab creation with discard

Each plugin exports handlers for specific extension events and can be enabled/disabled via options.
