# ClickToDrawOverlayAdobe

An Adobe-style drawing overlay tool for macOS with professional drawing capabilities.

## Features

- 🎨 Professional drawing tools (Rectangle, Circle, Arrow, Text, Freehand)
- 🖱️ Click-and-drag drawing interface
- 🎯 Adobe-style floating toolbar
- ⌨️ Keyboard shortcuts (ESC to cancel, Q to deselect tool)
- 💾 Export drawings as images
- 🔧 Tool animations and visual feedback

## Building

```bash
# Compile the application
swiftc -o ClickToDrawOverlayAdobe ClickToDrawOverlayAdobe.swift \
  -framework Cocoa \
  -framework CoreGraphics \
  -framework UniformTypeIdentifiers \
  -framework QuartzCore \
  -framework ScreenCaptureKit \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

# Run the application
./ClickToDrawOverlayAdobe
```

## Usage

1. Launch the application
2. Click the "START" button in the toolbar to begin
3. Select a drawing tool from the toolbar
4. Click and drag on the overlay to draw
5. Use ESC to cancel current drawing or Q to deselect tool
6. Export your drawing when complete

## Requirements

- macOS 11.0+
- Xcode Command Line Tools
- Screen Recording permissions

## License

MIT