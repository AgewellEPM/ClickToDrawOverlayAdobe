#!/bin/bash

echo "🔨 Building ClickToDrawOverlayAdobe..."

swiftc -o ClickToDrawOverlayAdobe ClickToDrawOverlayAdobe.swift \
  -framework Cocoa \
  -framework CoreGraphics \
  -framework UniformTypeIdentifiers \
  -framework QuartzCore \
  -framework ScreenCaptureKit \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Run with: ./ClickToDrawOverlayAdobe"
else
    echo "❌ Build failed!"
    exit 1
fi