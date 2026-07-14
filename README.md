# HDR Photo Converter for Video Editors

HDR Photo Converter for Video Editors is an open-source macOS application that converts HDR gain-map photos into Rec. 2020 HLG movie files and editor import XML.

It is intended for video editors whose HDR photos otherwise import as SDR, including Final Cut Pro and DaVinci Resolve users.

## Supported input

- ISO 21496-1 Ultra HDR JPEG
- Apple HDR gain-map HEIC

Standard SDR photos are identified and skipped. Unsupported HDR variants are reported before conversion.

## Output

- HLG, Rec. 2020, 10-bit HEVC `.mov` by default (40 Mb/s)
- Optional HLG, Rec. 2020, ProRes 4444 `.mov` for large intermediate masters
- An FCPXML file for Final Cut Pro import
- A DaVinci Resolve import target that writes Resolve-friendly FCPXML when a timeline is needed

DaVinci Resolve does not require XML when you only need the converted clips in the media pool. Import or drag the generated `.mov` files directly. Use the Resolve FCPXML output when you want the app to recreate a timeline with clip order and still duration.

## Requirements

- macOS 14 or later
- Final Cut Pro or DaVinci Resolve, for XML timeline import

The distributed app is self-contained: it does not require Python, FFmpeg, or ImageMagick.

## Build

The app consists of a SwiftUI application plus a short-lived conversion worker. The worker exits after every source photo so ImageIO and AVFoundation allocations do not accumulate during large batches.

Build the app and worker with the system Swift toolchain, then package both executables in the app bundle's `Contents/MacOS` directory.

To build a local release package:

```zsh
VERSION=0.1.0 scripts/package-release.sh
```

The script creates:

- `build/release/HDR Photo Converter for Video Editors.app`
- `build/release/HDR Photo Converter for Video Editors-<version>-macOS.zip`
- `build/release/HDR Photo Converter for Video Editors-<version>-macOS.dmg`

## GitHub Release

GitHub Actions builds the same release package on every push to `main` and uploads it as a workflow artifact.

To create a GitHub Release with downloadable `.zip` and `.dmg` assets, push a version tag:

```zsh
git tag v0.1.0
git push origin main v0.1.0
```

The tag workflow creates the release automatically.

## Scope

The ISO Ultra HDR JPEG path currently targets the common sRGB-base, monochrome gain-map layout. Full support for every ISO gain-map parameter combination, per-channel gain maps, and non-sRGB ISO inputs remains future work. Apple HDR gain-map HEIC is decoded through Core Image's gain-map support.

Final Cut Pro is a trademark of Apple Inc. DaVinci Resolve is a trademark of Blackmagic Design Pty Ltd. This project is independent and is not affiliated with or endorsed by Apple or Blackmagic Design.
