# HDR Photo Converter for Video Editors

HDR Photo Converter for Video Editors is an open-source macOS application that converts HDR gain-map photos into Rec. 2020 HLG ProRes 4444 MOV files and Final Cut Pro XML (FCPXML).

It is intended for video editors whose HDR photos otherwise import as SDR, including Final Cut Pro users.

## Supported input

- ISO 21496-1 Ultra HDR JPEG
- Apple HDR gain-map HEIC

Standard SDR photos are identified and skipped. Unsupported HDR variants are reported before conversion.

## Output

- HLG, Rec. 2020, 10-bit HEVC `.mov` by default (40 Mb/s)
- Optional HLG, Rec. 2020, ProRes 4444 `.mov` for large intermediate masters
- An FCPXML file that imports the converted media into Final Cut Pro

## Requirements

- macOS 14 or later
- Final Cut Pro, for FCPXML import

The distributed app is self-contained: it does not require Python, FFmpeg, or ImageMagick.

## Build

The app consists of a SwiftUI application plus a short-lived conversion worker. The worker exits after every source photo so ImageIO and AVFoundation allocations do not accumulate during large batches.

Build the app and worker with the system Swift toolchain, then package both executables in the app bundle's `Contents/MacOS` directory.

## Scope

The ISO Ultra HDR JPEG path currently targets the common sRGB-base, monochrome gain-map layout. Full support for every ISO gain-map parameter combination, per-channel gain maps, and non-sRGB ISO inputs remains future work. Apple HDR gain-map HEIC is decoded through Core Image's gain-map support.

Final Cut Pro is a trademark of Apple Inc. This project is independent and is not affiliated with or endorsed by Apple.
