import AppKit
import FlutterMacOS

/// 托盘截图流程会 `NSApp.activate`，可能把已收到托盘（`orderOut`）的 Flutter 主窗再次带到前台；在关键节点按激活前的可见性恢复隐藏。
enum TrayCaptureFlutterWindow {
    static func snapshotMainVisibility() -> [(NSWindow, Bool)] {
        NSApp.windows.compactMap { w in
            guard w.contentViewController is FlutterViewController else { return nil }
            return (w, w.isVisible)
        }
    }

    static func reapplyHiddenAfterActivate(_ snapshot: [(NSWindow, Bool)]) {
        for (window, wasVisible) in snapshot where !wasVisible {
            window.orderOut(nil)
        }
    }
}
