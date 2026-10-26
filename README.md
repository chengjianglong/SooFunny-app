# SooFunny 🖍️

A coloring app for kids on **iPhone and iPad**. Pick any picture, and SooFunny splits it into
blocks. Kids tap (or swipe across) blocks to fill them with color.

**Works completely offline.** All image processing happens on the device. The app makes no
network requests and needs no Wi‑Fi, account or download.

<p align="center"><img src="SooFunny/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="160" alt="SooFunny icon"></p>

## Features

- **Any picture**: choose a photo, snap one with the camera, or start from a built-in drawing
  (House, Fish, Flower, Rocket).
- **Automatic blocks**:
  - *Drawings / coloring pages*: every area enclosed by lines becomes a block.
  - *Photos*: colors are grouped, and each connected area becomes a block. Choose **Big**,
    **Medium** or **Small** blocks.
- **Kid-friendly coloring**: tap a block, or drag a finger to paint several blocks in one stroke.
  Taps on a line snap to the nearest block.
- **Fun tools**: Undo, **Magic** (random colors everywhere), **Real** (each block in its photo
  color), **Peek** (see the original underneath), Clear, Eraser, and a custom color picker.
- **Share / save** the finished picture through the system share sheet.
- Universal layout: a scrolling crayon row on iPhone and a wrapping crayon box on iPad. In iPad
  landscape, the tools move to a sidebar so the picture stays big. Every orientation is supported.

## How the blocks are made

`SooFunny/Engine/ImageSegmenter.swift` runs entirely on the device with no ML models or network:

1. Scale the picture down (1024px for drawings, 512px for photos) and flatten transparency.
2. Detect line art: mostly gray pixels on a mostly white background.
3. **Line art**: dark pixels are lines; each 4-connected light area is a block, and specks are dropped.
4. **Photos**:
   - Box blur, then k-means color quantization (seeded, so results repeat), then a 3×3 majority
     filter to smooth edges.
   - Each connected area becomes a block. Tiny blocks and thin slivers merge into the neighbor
     they share the longest border with, until the block count fits the chosen size.
5. Draw each block with its fill color and dark outlines.

## Building

Requirements: Xcode 16+ and iOS 17+.

```bash
open SooFunny.xcodeproj
```

Select an iPhone or iPad simulator (or your device: set your Team under *Signing &
Capabilities*), then press **Run**.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
After adding or removing files, regenerate it:

```bash
xcodegen generate
```

Run the unit tests:

```bash
xcodebuild test -project SooFunny.xcodeproj -scheme SooFunny -destination 'platform=iOS Simulator,name=<your simulator>'
```

## Project layout

```
SooFunny/
  App/SooFunnyApp.swift          App entry point
  Engine/PixelImage.swift        RGBA bitmap helpers
  Engine/ImageSegmenter.swift    Picture → blocks, plus the renderer
  Engine/ColoringSession.swift   Fill colors, undo, Magic/Real/Clear
  Samples/SampleArt.swift        Built-in drawings, drawn in code
  Views/                         SwiftUI screens
SooFunnyTests/                   Segmentation unit tests
design/soo-icon.png              Source artwork for the app icon
scripts/make_icon.py             Crops the artwork into the 1024px app icon
```
