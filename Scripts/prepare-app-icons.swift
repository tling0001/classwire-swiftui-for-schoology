import AppKit
import Foundation

let assetCatalog = URL(fileURLWithPath: "Resources/Assets.xcassets", isDirectory: true)
let iosSet = assetCatalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let macSet = assetCatalog.appendingPathComponent("AppIconMac.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iosSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: macSet, withIntermediateDirectories: true)

func renderIcon(size: Int, dark: Bool = false, tinted: Bool = false) throws -> Data {
    let dimension = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "SchoologyIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate app icon bitmap."])
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SchoologyIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create app icon graphics context."])
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    if !tinted {
        (dark
            ? NSColor(calibratedRed: 34.0 / 255, green: 48.0 / 255, blue: 62.0 / 255, alpha: 1)
            : NSColor.white
        ).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: dimension, height: dimension)).fill()
    }

    let ringColor = tinted
        ? NSColor.white
        : NSColor(calibratedRed: 72.0 / 255, green: 175.0 / 255, blue: 236.0 / 255, alpha: 1)
    let ringInset = dimension * 0.0415
    let ring = NSBezierPath(ovalIn: NSRect(
        x: ringInset,
        y: ringInset,
        width: dimension - ringInset * 2,
        height: dimension - ringInset * 2
    ))
    ring.lineWidth = dimension * 0.083
    ringColor.setStroke()
    ring.stroke()

    let glyphSize = dimension * 0.78
    let glyphOffset = (dimension - glyphSize) / 2
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(
            x: glyphOffset + x * glyphSize / 20,
            y: glyphOffset + (20 - y) * glyphSize / 20
        )
    }

    let glyph = NSBezierPath()
    glyph.move(to: point(9.634, 10.54))
    glyph.curve(to: point(6.368, 7.801), controlPoint1: point(8.165, 10.18), controlPoint2: point(6.368, 9.762))
    glyph.curve(to: point(9.885, 5), controlPoint1: point(6.368, 6.08), controlPoint2: point(7.776, 5))
    glyph.curve(to: point(13.789, 8.081), controlPoint1: point(11.624, 5), controlPoint2: point(13.479, 5.859))
    glyph.line(to: point(12.127, 8.301))
    glyph.curve(to: point(11.469, 6.778), controlPoint1: point(12.108, 7.72), controlPoint2: point(12.068, 7.261))
    glyph.curve(to: point(9.713, 6.22), controlPoint1: point(10.869, 6.3), controlPoint2: point(10.174, 6.22))
    glyph.curve(to: point(7.915, 7.6), controlPoint1: point(8.512, 6.22), controlPoint2: point(7.915, 6.959))
    glyph.curve(to: point(10.096, 9.08), controlPoint1: point(7.915, 8.501), controlPoint2: point(8.899, 8.781))
    glyph.line(to: point(10.967, 9.299))
    glyph.curve(to: point(14, 12.021), controlPoint1: point(12.048, 9.559), controlPoint2: point(14, 10.041))
    glyph.curve(to: point(10.174, 15), controlPoint1: point(14, 13.559), controlPoint2: point(12.687, 15))
    glyph.curve(to: point(7.354, 14.241), controlPoint1: point(9.149, 15), controlPoint2: point(8.088, 14.781))
    glyph.curve(to: point(6, 11.681), controlPoint1: point(7.063, 14.019), controlPoint2: point(6.174, 13.26))
    glyph.line(to: point(7.739, 11.401))
    glyph.curve(to: point(8.375, 13.24), controlPoint1: point(7.72, 11.821), controlPoint2: point(7.68, 12.621))
    glyph.curve(to: point(10.214, 13.782), controlPoint1: point(8.915, 13.72), controlPoint2: point(9.594, 13.782))
    glyph.curve(to: point(12.355, 12.22), controlPoint1: point(11.565, 13.782), controlPoint2: point(12.355, 13.24))
    glyph.curve(to: point(10.462, 10.721), controlPoint1: point(12.355, 11.141), controlPoint2: point(11.565, 10.941))
    glyph.line(to: point(9.594, 10.54))
    glyph.close()
    let glyphColor = tinted
        ? NSColor.white
        : (dark ? NSColor.white : NSColor(calibratedRed: 53.0 / 255, green: 63.0 / 255, blue: 75.0 / 255, alpha: 1))
    glyphColor.setFill()
    glyph.fill()

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SchoologyIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode app icon PNG."])
    }
    return png
}

func write(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
}

try write(renderIcon(size: 1024), to: iosSet.appendingPathComponent("ios-1024.png"))
try write(renderIcon(size: 1024, dark: true), to: iosSet.appendingPathComponent("ios-1024-dark.png"))
try write(renderIcon(size: 1024, tinted: true), to: iosSet.appendingPathComponent("ios-1024-tinted.png"))

let macSizes: [(String, Int)] = [
    ("mac-16.png", 16), ("mac-16@2x.png", 32),
    ("mac-32.png", 32), ("mac-32@2x.png", 64),
    ("mac-128.png", 128), ("mac-128@2x.png", 256),
    ("mac-256.png", 256), ("mac-256@2x.png", 512),
    ("mac-512.png", 512), ("mac-512@2x.png", 1024)
]
for (name, size) in macSizes {
    try write(renderIcon(size: size), to: macSet.appendingPathComponent(name))
}

print("Prepared Schoology app icons from the official Tauri SVG ring-and-S mark.")
