import AppKit

/// Borderless panel that can become key so Escape / keyboard work without `NSApp.activate` (which would raise the Flutter window).
private final class RegionSelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class RegionOverlayView: NSView {
    weak var controller: RegionSelectionController?
    private var anchor: NSPoint?
    var selectionRect: NSRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.45).setFill()
        let outer = NSBezierPath(rect: bounds)
        if selectionRect.width > 0.5, selectionRect.height > 0.5 {
            outer.appendRect(selectionRect)
            outer.windingRule = .evenOdd
        }
        outer.fill()

        if selectionRect.width > 0.5, selectionRect.height > 0.5 {
            NSColor.systemBlue.setStroke()
            let border = NSBezierPath(rect: selectionRect)
            border.lineWidth = 1
            border.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let a = anchor else { return }
        let p = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(a.x, p.x),
            y: min(a.y, p.y),
            width: abs(p.x - a.x),
            height: abs(p.y - a.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let a = anchor else {
            controller?.finish(path: nil)
            return
        }
        let p = convert(event.locationInWindow, from: nil)
        let rect = NSRect(
            x: min(a.x, p.x),
            y: min(a.y, p.y),
            width: abs(p.x - a.x),
            height: abs(p.y - a.y)
        )
        anchor = nil
        if rect.width < 4 || rect.height < 4 {
            controller?.finish(path: nil)
            return
        }
        controller?.completeSelection(rect)
    }

    override func rightMouseUp(with event: NSEvent) {
        controller?.finish(path: nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            controller?.finish(path: nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class RegionSelectionController: NSObject {
    private let fullImage: CGImage
    private let unionRect: NSRect
    private let onComplete: (String?) -> Void
    private var panel: NSPanel?

    /// 必须在已获得「不含本遮罩」的桌面位图之后再 show；裁剪像素全部来自 fullImage。
    init(fullImage: CGImage, unionRect: NSRect, onComplete: @escaping (String?) -> Void) {
        self.fullImage = fullImage
        self.unionRect = unionRect
        self.onComplete = onComplete
        super.init()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = RegionSelectionPanel(
            contentRect: unionRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true

        let view = RegionOverlayView(frame: NSRect(origin: .zero, size: unionRect.size))
        view.controller = self
        panel.contentView = view
        self.panel = panel
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(view)
    }

    func completeSelection(_ rectInView: NSRect) {
        let snap = fullImage
        let imgW = CGFloat(snap.width)
        let imgH = CGFloat(snap.height)
        let uw = unionRect.width
        let uh = unionRect.height
        guard uw > 0, uh > 0 else {
            finish(path: nil)
            return
        }
        let sx = imgW / uw
        let sy = imgH / uh
        var crop = CGRect(
            x: rectInView.minX * sx,
            y: rectInView.minY * sy,
            width: rectInView.width * sx,
            height: rectInView.height * sy
        )
        crop = crop.intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))
        if crop.width < 1 || crop.height < 1 {
            finish(path: nil)
            return
        }
        let integral = CGRect(
            x: floor(crop.minX),
            y: floor(crop.minY),
            width: ceil(crop.width),
            height: ceil(crop.height)
        )
        guard let cropped = snap.cropping(to: integral) else {
            finish(path: nil)
            return
        }
        let path = ScreenCaptureService.writeTempPNG(cropped)
        finish(path: path)
    }

    func finish(path: String?) {
        panel?.close()
        panel = nil
        onComplete(path)
    }
}
