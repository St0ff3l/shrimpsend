import AppKit
import CoreImage

// MARK: - Model

private enum MarkupTool {
    case pen
    case rect
    case arrow
    case mosaic
}

private enum MarkupItem {
    case pen([NSPoint])
    case rect(NSRect)
    case arrow(from: NSPoint, to: NSPoint)
    case mosaic(NSRect)
}

// MARK: - Canvas

private final class MarkupCanvasView: NSView {
    var backgroundImage: NSImage?
    var items: [MarkupItem] = []
    var tool: MarkupTool = .pen
    var strokeColor: NSColor = NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 1)
    var lineWidth: CGFloat = 3
    /// 马赛克像素块边长（与截图分辨率无关，为图像空间像素单位）
    var mosaicBlockSize: CGFloat = 12

    private lazy var ciContext = CIContext(options: nil)

    private var penPoints: [NSPoint]?
    private var dragStart: NSPoint?
    private var dragCurrent: NSPoint?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        bounds.fill()

        if let img = backgroundImage {
            img.draw(
                in: bounds,
                from: NSRect(origin: .zero, size: img.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }

        let ctx = NSGraphicsContext.current?.cgContext
        ctx?.setLineCap(.round)
        ctx?.setLineJoin(.round)
        ctx?.setLineWidth(lineWidth)
        strokeColor.setStroke()

        for item in items {
            drawItem(item, in: ctx)
        }

        if let pts = penPoints, pts.count >= 2 {
            drawPen(pts, in: ctx)
        }
        if tool == .rect, let a = dragStart, let b = dragCurrent {
            NSBezierPath(rect: rectFromPoints(a, b)).stroke()
        }
        if tool == .mosaic, let a = dragStart, let b = dragCurrent {
            NSBezierPath(rect: rectFromPoints(a, b)).stroke()
        }
        if tool == .arrow, let a = dragStart, let b = dragCurrent {
            drawArrow(from: a, to: b, in: ctx)
        }
    }

    private func rectFromPoints(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private func drawItem(_ item: MarkupItem, in ctx: CGContext?) {
        switch item {
        case .pen(let pts):
            drawPen(pts, in: ctx)
        case .rect(let r):
            NSBezierPath(rect: r).stroke()
        case .arrow(let from, let to):
            drawArrow(from: from, to: to, in: ctx)
        case .mosaic(let r):
            drawMosaic(rect: r, in: ctx)
        }
    }

    private func drawPen(_ pts: [NSPoint], in ctx: CGContext?) {
        guard pts.count >= 2 else { return }
        let path = NSBezierPath()
        path.move(to: pts[0])
        for i in 1..<pts.count {
            path.line(to: pts[i])
        }
        path.lineWidth = lineWidth
        strokeColor.setStroke()
        path.stroke()
    }

    private func drawArrow(from: NSPoint, to: NSPoint, in ctx: CGContext?) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = lineWidth
        strokeColor.setStroke()
        path.stroke()

        let headLen: CGFloat = 14
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = hypot(dx, dy)
        guard len > 1 else { return }
        let ux = dx / len
        let uy = dy / len
        let bx = to.x - ux * headLen
        let by = to.y - uy * headLen
        let px = -uy * (headLen * 0.45)
        let py = ux * (headLen * 0.45)

        let head = NSBezierPath()
        head.move(to: to)
        head.line(to: NSPoint(x: bx + px, y: by + py))
        head.move(to: to)
        head.line(to: NSPoint(x: bx - px, y: by - py))
        head.lineWidth = lineWidth
        strokeColor.setStroke()
        head.stroke()
    }

    /// 在画布逻辑坐标（与 `rect` 工具相同，origin 左上、y 向下）下绘制马赛克。
    private func drawMosaic(rect r: NSRect, in ctx: CGContext?) {
        guard let cg = ctx, let img = backgroundImage,
              let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let W = CGFloat(cgImg.width)
        let H = CGFloat(cgImg.height)
        let bw = bounds.width
        let bh = bounds.height
        guard bw > 0, bh > 0, r.width > 0, r.height > 0 else { return }

        let crop = CGRect(
            x: r.minX / bw * W,
            y: (bh - r.maxY) / bh * H,
            width: r.width / bw * W,
            height: r.height / bh * H
        )
        guard crop.width >= 1, crop.height >= 1 else { return }

        let ci = CIImage(cgImage: cgImg).cropped(to: crop)
        guard let filter = CIFilter(name: "CIPixellate") else { return }
        filter.setValue(ci, forKey: kCIInputImageKey)
        let scale = max(4, min(32, mosaicBlockSize))
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: crop.midX, y: crop.midY), forKey: kCIInputCenterKey)
        guard let out = filter.outputImage else { return }
        let outExtent = out.extent.intersection(ci.extent)
        guard !outExtent.isEmpty,
              let outCG = ciContext.createCGImage(out, from: outExtent) else { return }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let nsgc = NSGraphicsContext(cgContext: cg, flipped: true)
        NSGraphicsContext.current = nsgc
        let piece = NSImage(cgImage: outCG, size: NSSize(width: outExtent.width, height: outExtent.height))
        piece.draw(
            in: r,
            from: NSRect(origin: .zero, size: piece.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch tool {
        case .pen:
            penPoints = [p]
        case .rect, .arrow, .mosaic:
            dragStart = p
            dragCurrent = p
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch tool {
        case .pen:
            penPoints?.append(p)
        case .rect, .arrow, .mosaic:
            dragCurrent = p
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch tool {
        case .pen:
            if var pts = penPoints {
                pts.append(p)
                if pts.count >= 2 {
                    items.append(.pen(pts))
                }
            }
            penPoints = nil
        case .rect:
            if let a = dragStart {
                let r = rectFromPoints(a, p)
                if r.width > 3, r.height > 3 {
                    items.append(.rect(r))
                }
            }
            dragStart = nil
            dragCurrent = nil
        case .arrow:
            if let a = dragStart {
                if hypot(p.x - a.x, p.y - a.y) > 3 {
                    items.append(.arrow(from: a, to: p))
                }
            }
            dragStart = nil
            dragCurrent = nil
        case .mosaic:
            if let a = dragStart {
                let r = rectFromPoints(a, p)
                if r.width > 3, r.height > 3 {
                    items.append(.mosaic(r))
                }
            }
            dragStart = nil
            dragCurrent = nil
        }
        needsDisplay = true
    }

    func undo() {
        guard !items.isEmpty else { return }
        items.removeLast()
        needsDisplay = true
    }

    func clearMarkup() {
        items.removeAll()
        needsDisplay = true
    }

    /// 导出与画布显示一致的 PNG：像素尺寸与底图位图一致，不再额外乘屏幕 `backingScaleFactor`（避免「放大」），坐标系与 `isFlipped` 视图一致（避免上下镜像）。
    func pngData() -> Data? {
        guard let img = backgroundImage,
              let cgSource = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let pw = max(1, cgSource.width)
        let ph = max(1, cgSource.height)
        let bw = max(bounds.width, 1)
        let bh = max(bounds.height, 1)
        let sx = CGFloat(pw) / bw
        let sy = CGFloat(ph) / bh

        let rendered = NSImage(size: NSSize(width: CGFloat(pw), height: CGFloat(ph)), flipped: true) { [weak self] _ in
            guard let self = self else { return false }
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.saveGState()
            cg.scaleBy(x: sx, y: sy)

            NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: bw, height: bh).fill()

            img.draw(
                in: NSRect(x: 0, y: 0, width: bw, height: bh),
                from: NSRect(origin: .zero, size: img.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )

            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setLineWidth(self.lineWidth)
            self.strokeColor.setStroke()
            for item in self.items {
                self.drawItem(item, in: cg)
            }

            cg.restoreGState()
            return true
        }

        guard let tiff = rendered.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Window

private final class ScreenshotMarkupWindowController: NSWindowController, NSWindowDelegate {
    private let canvas: MarkupCanvasView
    private var retainCycle: ScreenshotMarkupWindowController?
    private let onDispose: () -> Void

    init(image: NSImage, onDispose: @escaping () -> Void) {
        self.onDispose = onDispose
        let toolbarH: CGFloat = 52
        let imgSize = image.size
        let contentW = min(max(480, imgSize.width), 1600)
        let contentH = min(max(360, imgSize.height), 1200) + toolbarH

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentW, height: contentH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "截图标注"
        window.minSize = NSSize(width: 400, height: 320)
        window.center()

        let canvasView = MarkupCanvasView(frame: NSRect(origin: .zero, size: imgSize))
        canvasView.backgroundImage = image
        canvas = canvasView

        super.init(window: window)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: contentW, height: contentH))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scroll = NSScrollView(frame: .zero)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.documentView = canvasView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bar.translatesAutoresizingMaskIntoConstraints = false

        func sep() -> NSView {
            let v = NSBox()
            v.boxType = .separator
            return v
        }

        func makeBtn(_ title: String, _ sel: Selector) -> NSButton {
            let b = NSButton(frame: .zero)
            b.title = title
            b.bezelStyle = .rounded
            b.controlSize = .regular
            b.target = self
            b.action = sel
            return b
        }

        bar.addArrangedSubview(makeBtn("画笔", #selector(tPen)))
        bar.addArrangedSubview(makeBtn("矩形", #selector(tRect)))
        bar.addArrangedSubview(makeBtn("箭头", #selector(tArrow)))
        bar.addArrangedSubview(makeBtn("马赛克", #selector(tMosaic)))
        bar.addArrangedSubview(sep())
        bar.addArrangedSubview(makeBtn("撤销", #selector(tUndo)))
        bar.addArrangedSubview(makeBtn("清除标注", #selector(tClear)))
        bar.addArrangedSubview(sep())
        bar.addArrangedSubview(makeBtn("复制", #selector(tCopy)))
        bar.addArrangedSubview(makeBtn("保存…", #selector(tSave)))
        bar.addArrangedSubview(sep())
        bar.addArrangedSubview(makeBtn("完成", #selector(tClose)))

        root.addSubview(bar)
        root.addSubview(scroll)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bar.topAnchor.constraint(equalTo: root.topAnchor),

            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        window.contentView = root
        window.delegate = self
        retainCycle = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showEditor() {
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        retainCycle = nil
        onDispose()
    }

    @objc private func tPen() { canvas.tool = .pen }
    @objc private func tRect() { canvas.tool = .rect }
    @objc private func tArrow() { canvas.tool = .arrow }
    @objc private func tMosaic() { canvas.tool = .mosaic }
    @objc private func tUndo() { canvas.undo() }
    @objc private func tClear() { canvas.clearMarkup() }

    @objc private func tCopy() {
        guard let data = canvas.pngData() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }

    @objc private func tSave() {
        guard let data = canvas.pngData(), let win = window else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["png"]
        panel.nameFieldStringValue = "screenshot.png"
        panel.beginSheetModal(for: win) { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    @objc private func tClose() {
        window?.close()
    }
}

// MARK: - Public entry

enum ScreenshotMarkupEditor {
    private static var current: ScreenshotMarkupWindowController?

    static func present(imagePath: String, flutterVisibilitySnapshot: [(NSWindow, Bool)]? = nil) {
        DispatchQueue.main.async {
            let snap = flutterVisibilitySnapshot ?? TrayCaptureFlutterWindow.snapshotMainVisibility()
            guard let img = NSImage(contentsOfFile: imagePath) else { return }
            NSApp.activate(ignoringOtherApps: true)
            TrayCaptureFlutterWindow.reapplyHiddenAfterActivate(snap)
            let wc = ScreenshotMarkupWindowController(image: img) {
                current = nil
            }
            current = wc
            wc.showEditor()
            TrayCaptureFlutterWindow.reapplyHiddenAfterActivate(snap)
        }
    }
}
