# ClickToDrawOverlayAdobe

An Adobe-style drawing overlay tool for macOS with professional drawing capabilities.

## Features

- 🎨 Professional drawing tools (Rectangle, Circle, Arrow, Text, Freehand)
- 🖱️ Click-and-drag drawing interface
- 🎯 Adobe-style floating toolbar
- ✂️ Image slicing - Open images and slice them into draggable pieces
- 🧩 Draggable image pieces with visual feedback
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

### Image Slicing Feature

1. Click the "SLICE" button in the toolbar
2. Select an image file to open
3. The image will be automatically sliced into a 4x4 grid (16 pieces)
4. Each piece can be dragged around the screen independently
5. Pieces have visual feedback when being dragged (highlighted border)

## Requirements

- macOS 11.0+
- Xcode Command Line Tools
- Screen Recording permissions

## License

MIT