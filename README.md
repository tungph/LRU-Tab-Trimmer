# LRU Tab Trimmer

A Firefox extension that uses the native tab discarding method (`browser.tabs.discard`) to automatically reduce memory usage of inactive tabs using an LRU (Least Recently Used) strategy. This extension is optimized specifically for Firefox and provides efficient tab management without DOM replacement.

## Features

- **Native Tab Discarding**: Uses Firefox's built-in tab discarding API for efficient memory management
- **Smart Detection**: Prevents discarding tabs with unsaved forms, playing audio, or pinned tabs
- **Visual Indicators**: Adds emoji (💤) to discarded tab titles and modifies favicons
- **Flexible Configuration**: Customize discarding behavior based on tab count, idle time, or memory usage
- **Whitelist Support**: Exclude specific domains from auto-discarding
- **Keyboard Shortcuts**: Quick commands for manual tab management

## Installation

### From Source (Development)
1. Clone this repository
2. Open Firefox and navigate to `about:debugging`
3. Click "This Firefox" on the left panel
4. Click "Load Temporary Add-on"
5. Select the `manifest.json` file from the cloned repository

### From Firefox Add-ons Store
Visit: https://addons.mozilla.org/firefox/addon/lru-tab-trimmer/
