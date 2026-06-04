import AppKit
import CoreGraphics
import ImageIO

enum ScreenCaptureService {
    static func desktopUnionRect() -> NSRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = CGFloat.leastNormalMagnitude
        var maxY = CGFloat.leastNormalMagnitude
        for s in NSScreen.screens {
            let f = s.frame
            minX = min(minX, f.minX)
            minY = min(minY, f.minY)
            maxX = max(maxX, f.maxX)
            maxY = max(maxY, f.maxY)
        }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func maxBackingScale() -> CGFloat {
        NSScreen.screens.map { $0.backingScaleFactor }.max() ?? 2.0
    }

    /// Composite all displays into one bitmap (global Cocoa coordinates, bottom-left origin).
    static func captureCompositeImage() -> CGImage? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let union = desktopUnionRect()
        let maxScale = maxBackingScale()
        let widthPx = Int(ceil(union.width * maxScale))
        let heightPx = Int(ceil(union.height * maxScale))
        guard widthPx > 0, heightPx > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: widthPx,
            height: heightPx,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.scaleBy(x: maxScale, y: maxScale)

        for screen in screens {
            guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let displayID = CGDirectDisplayID(num.uint32Value)
            guard let shot = CGDisplayCreateImage(displayID) else { continue }
            let sf = screen.frame
            let relX = sf.minX - union.minX
            let relY = sf.minY - union.minY
            ctx.draw(shot, in: CGRect(x: relX, y: relY, width: sf.width, height: sf.height))
        }

        return ctx.makeImage()
    }

    static func writeTempPNG(_ image: CGImage) -> String? {
        let name = "shrimpsend_capture_\(UUID().uuidString).png"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(name)
        let url = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return path
    }
}
