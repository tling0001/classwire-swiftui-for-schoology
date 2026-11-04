import AppKit
import Foundation

let assetCatalog = URL(fileURLWithPath: "Resources/Assets.xcassets", isDirectory: true)
let iosSet = assetCatalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let macSet = assetCatalog.appendingPathComponent("AppIconMac.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iosSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: macSet, withIntermediateDirectories: true)

// Exact vector artwork from assets/icons/ic_sgy_logo.svg in Schoology Tauri port.28.
let ringPath = #"M10 1.868C5.401 1.868 1.659 5.571 1.659 10.122 1.659 14.674 5.401 18.378 10 18.378 14.599 18.378 18.341 14.674 18.341 10.122 18.341 5.571 14.599 1.868 10 1.868M10 20.226C4.486 20.226 0 15.739 0 10.225 0 4.711 4.486 0.226 10 0.226 15.514 0.226 20 4.711 20 10.225"#
let letterPath = #"M9.634 10.54C8.165 10.18 6.368 9.762 6.368 7.801 6.368 6.08 7.776 5 9.885 5c1.739 0 3.594.859 3.904 3.081l-1.662.22c-.019-.581-.059-1.04-.658-1.523-.6-.478-1.295-.558-1.756-.558-1.201 0-1.798.739-1.798 1.38 0 .901.984 1.181 2.181 1.48l.871.219c1.081.26 3.033.742 3.033 2.722 0 1.538-1.313 2.979-3.826 2.979-1.025 0-2.086-.219-2.82-.759-.291-.222-1.18-.981-1.354-2.56l1.739-.28c-.019.42-.059 1.22.636 1.839.54.48 1.219.542 1.839.542 1.351 0 2.141-.542 2.141-1.562 0-1.079-.79-1.279-1.893-1.499l-.868-.181z"#

func svg(dark: Bool = false, tinted: Bool = false) -> String {
    let background = tinted ? "" : #"<rect width="20" height="20" fill="\#(dark ? "#243442" : "#ffffff")"/>"#
    let ring = tinted ? "#ffffff" : "#48afec"
    let letter = tinted ? "#ffffff" : (dark ? "#ffffff" : "#353f4b")
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 20 20">
      \(background)
      <path fill="\(ring)" fill-rule="evenodd" d="\(ringPath)" transform="translate(0 -.226)"/>
      <path fill="\(letter)" fill-rule="evenodd" d="\(letterPath)"/>
    </svg>
    """
}

func renderIcon(size: Int, dark: Bool = false, tinted: Bool = false) throws -> Data {
    guard let image = NSImage(data: Data(svg(dark: dark, tinted: tinted).utf8)) else {
        throw NSError(domain: "SchoologyIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode official Schoology SVG artwork."])
    }
    let dimension = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SchoologyIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate Schoology icon bitmap."])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
               from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SchoologyIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode Schoology icon PNG."])
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
    try write(renderIcon(size: size), to: macSet.appendingPathComponent(name))
    try write(renderIcon(size: size, dark: true), to: macSet.appendingPathComponent("\(stem)-dark.png"))
    try write(renderIcon(size: size, tinted: true), to: macSet.appendingPathComponent("\(stem)-tinted.png"))
}
print("Prepared Schoology light, dark, and tinted icons using the exact Tauri port.28 vector mark.")
