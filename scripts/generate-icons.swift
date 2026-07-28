#!/usr/bin/env swift

import AppKit
import Foundation

struct IconVariant {
    let filename: String
    let pixels: Int
}

let variants = [
    IconVariant(filename: "icon_16x16.png", pixels: 16),
    IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
    IconVariant(filename: "icon_32x32.png", pixels: 32),
    IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
    IconVariant(filename: "icon_128x128.png", pixels: 128),
    IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
    IconVariant(filename: "icon_256x256.png", pixels: 256),
    IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
    IconVariant(filename: "icon_512x512.png", pixels: 512),
    IconVariant(filename: "icon_512x512@2x.png", pixels: 1_024),
]

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let projectRoot =
    scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outputDirectory =
    projectRoot
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

for variant in variants {
    let size = CGFloat(variant.pixels)
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: variant.pixels,
            pixelsHigh: variant.pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        throw IconGenerationError.couldNotCreateBitmap
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawIcon(size: size)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.couldNotEncodePNG
    }

    try data.write(
        to: outputDirectory.appendingPathComponent(variant.filename),
        options: .atomic
    )
}

func drawIcon(size: CGFloat) {
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let tile = bounds
    let tilePath = NSBezierPath(
        roundedRect: tile,
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    NSColor(
        srgbRed: 0.055,
        green: 0.055,
        blue: 0.055,
        alpha: 1
    ).setFill()
    tilePath.fill()

    let tokenDiameter = size * 0.42
    let token = NSRect(
        x: size * 0.35,
        y: size * 0.29,
        width: tokenDiameter,
        height: tokenDiameter
    )
    NSColor(
        srgbRed: 0.54,
        green: 0.54,
        blue: 0.54,
        alpha: 1
    ).setFill()
    NSBezierPath(ovalIn: token).fill()

    let panel = NSRect(
        x: size * 0.31,
        y: size * 0.25,
        width: size * 0.18,
        height: size * 0.50
    )
    NSColor(
        srgbRed: 1,
        green: 1,
        blue: 1,
        alpha: 1
    ).setFill()
    NSBezierPath(
        roundedRect: panel,
        xRadius: size * 0.09,
        yRadius: size * 0.09
    ).fill()
}

enum IconGenerationError: Error {
    case couldNotCreateBitmap
    case couldNotEncodePNG
}
