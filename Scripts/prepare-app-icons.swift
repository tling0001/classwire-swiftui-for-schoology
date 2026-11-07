import AppKit
import Foundation

let assetCatalog = URL(fileURLWithPath: "Resources/Assets.xcassets", isDirectory: true)
let iosSet = assetCatalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let macSet = assetCatalog.appendingPathComponent("AppIconMac.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iosSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: macSet, withIntermediateDirectories: true)

// ClassWire brand mark: the original blue circular ring with a custom C glyph.
let ringPath = #"M10 1.868C5.401 1.868 1.659 5.571 1.659 10.122 1.659 14.674 5.401 18.378 10 18.378 14.599 18.378 18.341 14.674 18.341 10.122 18.341 5.571 14.599 1.868 10 1.868M10 20.226C4.486 20.226 0 15.739 0 10.225 0 4.711 4.486 0.226 10 0.226 15.514 0.226 20 4.711 20 10.225 20 15.739 15.514 20.226 10 20.226Z"#
let letterPath = #"M15.7 4.6C14.1 2.9 12.1 2 9.8 2 5 2 2 5.3 2 10s3 8 7.8 8c2.3 0 4.3-.9 5.9-2.6l-2.2-2.2c-1 1-2.3 1.6-3.7 1.6-3 0-4.7-2-4.7-4.8s1.7-4.8 4.7-4.8c1.4 0 2.7.6 3.7 1.6z"#

func svg(dark: Bool = false, tinted: Bool = false) -> String {
    let background = tinted ? "" : #"<rect width="20" height="20" fill="\#(dark ? "#243442" : "#ffffff")"/>"#
    let ring = tinted ? "#ffffff" : "#48afec"
    let letter = tinted ? "#ffffff" : (dark ? "#ffffff" : "#353f4b")
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 20 20">
      \(background)
      <g transform="translate(1.35 1.35) scale(0.865)">
        <path fill="\(ring)" fill-rule="evenodd" d="\(ringPath)" transform="translate(0 -.226)"/>
        <path fill="\(letter)" fill-rule="evenodd" d="\(letterPath)" transform="translate(3.805 3.0) scale(0.70)"/>
      </g>
    </svg>
    """
}

func renderIcon(size: Int, dark: Bool = false, tinted: Bool = false, roundedCorners: Bool = false) throws -> Data {
    guard let image = NSImage(data: Data(svg(dark: dark, tinted: tinted).utf8)) else {
        throw NSError(domain: "ClassWireIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode official ClassWire SVG artwork."])
    }
    let dimension = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "ClassWireIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate ClassWire icon bitmap."])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    if roundedCorners {
        // Older macOS releases display legacy bitmap icons without applying
        // the modern rounded-rectangle mask. Keep this compatibility mask
        // confined to Mac renditions; iOS assets stay unmasked.
        let cornerRadius = dimension * 0.205
        NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: dimension, height: dimension),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        ).addClip()
    }
    image.draw(in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
               from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ClassWireIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode ClassWire icon PNG."])
    }
    return png
}

func write(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }
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
    let stem = String(name.dropLast(4))
    try write(renderIcon(size: size, roundedCorners: true), to: macSet.appendingPathComponent(name))
    try write(renderIcon(size: size, dark: true, roundedCorners: true), to: macSet.appendingPathComponent("\(stem)-dark.png"))
    try write(renderIcon(size: size, tinted: true, roundedCorners: true), to: macSet.appendingPathComponent("\(stem)-tinted.png"))
}
print("Prepared ClassWire light, dark, and tinted icons using the exact Tauri port.28 vector mark.")
