import AppKit
import Foundation
let assetCatalog = URL(fileURLWithPath: "Resources/Assets.xcassets", isDirectory: true)
let iosSet = assetCatalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let macSet = assetCatalog.appendingPathComponent("AppIconMac.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: iosSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: macSet, withIntermediateDirectories: true)
func renderIcon(size: Int, dark: Bool = false, tinted: Bool = false) throws -> Data {
    let dimension = CGFloat(size)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
        throw NSError(domain: "SchoologyIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate app icon bitmap."])
    }
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "SchoologyIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create app icon graphics context."])
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    if !tinted {
        (dark ? NSColor(calibratedRed: 34.0 / 255, green: 48.0 / 255, blue: 62.0 / 255, alpha: 1) : NSColor.white).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: dimension, height: dimension)).fill()
    }
    let ringColor = tinted ? NSColor.white : NSColor(calibratedRed: 6.0 / 255, green: 119.0 / 255, blue: 186.0 / 255, alpha: 1)
    let inset = dimension * 0.12
    let ring = NSBezierPath(ovalIn: NSRect(x: inset, y: inset, width: dimension - inset * 2, height: dimension - inset * 2))
    ring.lineWidth = dimension * 0.055
    ringColor.setStroke()
    ring.stroke()
    let font = NSFont(name: "Arial", size: dimension * 0.56) ?? NSFont.systemFont(ofSize: dimension * 0.56, weight: .medium)
    let letterColor = tinted ? NSColor.white : (dark ? NSColor.white : NSColor(calibratedWhite: 0.20, alpha: 1))
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: letterColor]
    let letter = "S" as NSString
    let bounds = letter.size(withAttributes: attributes)
    letter.draw(at: NSPoint(x: (dimension - bounds.width) / 2, y: (dimension - bounds.height) / 2 - dimension * 0.008), withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SchoologyIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode app icon PNG."])
    }
    return png
}
func write(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }
try write(renderIcon(size: 1024), to: iosSet.appendingPathComponent("ios-1024.png"))
try write(renderIcon(size: 1024, dark: true), to: iosSet.appendingPathComponent("ios-1024-dark.png"))
try write(renderIcon(size: 1024, tinted: true), to: iosSet.appendingPathComponent("ios-1024-tinted.png"))
let macSizes: [(String, Int)] = [("mac-16.png",16),("mac-16@2x.png",32),("mac-32.png",32),("mac-32@2x.png",64),("mac-128.png",128),("mac-128@2x.png",256),("mac-256.png",256),("mac-256@2x.png",512),("mac-512.png",512),("mac-512@2x.png",1024)]
for (name, size) in macSizes { try write(renderIcon(size: size), to: macSet.appendingPathComponent(name)) }
print("Prepared Schoology app icons from the official Tauri ring-and-S mark.")
