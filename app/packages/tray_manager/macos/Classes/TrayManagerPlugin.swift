import Cocoa
import FlutterMacOS

let kEventOnTrayIconMouseDown = "onTrayIconMouseDown"
let kEventOnTrayIconMouseUp = "onTrayIconMouseUp"
let kEventOnTrayIconRightMouseDown = "onTrayIconRightMouseDown"
let kEventOnTrayIconRightMouseUp = "onTrayIconRightMouseUp"
let kEventOnTrayMenuItemClick = "onTrayMenuItemClick"

extension NSRect {
    var topLeft: CGPoint {
        set {
            let screenFrameRect = NSScreen.main!.frame
            origin.x = newValue.x
            origin.y = screenFrameRect.height - newValue.y - size.height
        }
        get {
            let screenFrameRect = NSScreen.main!.frame
            return CGPoint(x: origin.x, y: screenFrameRect.height - origin.y - size.height)
        }
    }
}

public class TrayManagerPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
    var channel: FlutterMethodChannel!

    var trayIcon: TrayIcon?
    var trayMenu: TrayMenu?
    private var trayPopover: NSPopover?
    private var regionSelectionController: RegionSelectionController?
    //    var statusItem: NSStatusItem = NSStatusItem();
    
    var _inited: Bool = false;
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = TrayManagerPlugin()
        instance.channel = FlutterMethodChannel(name: "tray_manager", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "destroy":
            destroy(call, result: result)
            break
        case "getBounds":
            getBounds(call, result: result)
            break
        case "setIcon":
            setIcon(call, result: result)
            break
        case "setIconPosition":
            setIconPosition(call, result: result)
            break
        case "setToolTip":
            setToolTip(call, result: result)
            break
        case "setTitle":
            setTitle(call, result: result)
            break
        case "setContextMenu":
            setContextMenu(call, result: result)
            break
        case "popUpContextMenu":
            popUpContextMenu(call, result: result)
            break
        case "toggleTrayPopover":
            toggleTrayPopover(call, result: result)
            break
        case "showTrayScreenshotPopover":
            showTrayScreenshotPopover(call, result: result)
            break
        case "startFullScreenCapture":
            startFullScreenCapture(call, result: result)
            break
        case "startRegionCapture":
            startRegionCapture(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    //    private func _init() {
    //        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    //        if let button = statusItem.button {
    //            button.action = #selector(self.statusItemButtonClicked(sender:))
    //            button.target = self
    //            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
    //            _inited = true
    //        }
    //    }
    
    @objc func statusItemButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        var methodName: String?
        
        switch event.type {
        case NSEvent.EventType.leftMouseDown:
            methodName = kEventOnTrayIconMouseDown
            break
        case NSEvent.EventType.leftMouseUp:
            methodName = kEventOnTrayIconMouseUp
            break
        case NSEvent.EventType.rightMouseDown:
            methodName = kEventOnTrayIconRightMouseDown
            break
        case NSEvent.EventType.rightMouseUp:
            methodName = kEventOnTrayIconRightMouseUp
            break
        default:
            break
        }
        if (methodName != nil) {
            channel.invokeMethod(methodName!, arguments: nil, result: nil)
        }
    }
    
    public func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        regionSelectionController?.finish(path: nil)
        regionSelectionController = nil
        trayPopover?.performClose(nil)
        trayPopover = nil
        if (trayIcon?.statusItem != nil) {
            NSStatusBar.system.removeStatusItem((trayIcon?.statusItem)!)
        }
        if (trayIcon != nil) {
            trayIcon?.removeImage()
            trayIcon = nil
        }
        result(true)
    }
    
    public func getBounds(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let button = trayIcon?.statusItem?.button else {
            result(nil)
            return
        }
        let rectInWindow = button.convert(button.bounds, to: nil)
        guard let screenRect = button.window?.convertToScreen(rectInWindow) else {
            result(nil)
            return
        }
        let resultData: NSDictionary = [
            "x": screenRect.topLeft.x,
            "y": screenRect.topLeft.y,
            "width": screenRect.size.width,
            "height": screenRect.size.height,
        ]
        result(resultData)
    }
    
    public func setIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let base64Icon: String =  args["base64Icon"] as! String;
        let isTemplate: Bool =  args["isTemplate"] as! Bool;
        let iconPosition: String =  args["iconPosition"] as! String;
        let iconSize: Int = args["iconSize"] as! Int;
        
        let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters)
        let image = NSImage(data: imageData!)
        image!.size = NSSize(width: iconSize, height: iconSize)
        image!.isTemplate = isTemplate
        
        if (trayIcon == nil) {
            trayIcon = TrayIcon()
            trayIcon?.onTrayIconMouseDown = { () in
                self.channel.invokeMethod(kEventOnTrayIconMouseDown, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconMouseUp = { () in
                self.channel.invokeMethod(kEventOnTrayIconMouseUp, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconRightMouseDown = { () in
                self.channel.invokeMethod(kEventOnTrayIconRightMouseDown, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconRightMouseUp = { () in
                self.channel.invokeMethod(kEventOnTrayIconRightMouseUp, arguments: nil, result: nil)
            }
        }
        
        trayIcon?.setImage(image!, iconPosition)
        
        result(true)
    }
    
    public func setIconPosition(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let iconPosition: String =  args["iconPosition"] as! String;
        
        trayIcon?.setImagePosition(iconPosition)
        
        result(true)
    }
    
    public func setToolTip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let toolTip: String =  args["toolTip"] as! String;
        
        trayIcon?.setToolTip(toolTip)
        
        result(true)
    }
    
    public func setTitle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let title: String =  args["title"] as! String;
        
        trayIcon?.setTitle(title)
        
        result(true)
    }
    
    public func setContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        trayMenu = TrayMenu(args["menu"] as! [String: Any])
        trayMenu?.onMenuItemClick = { [weak self] (menuItem: NSMenuItem) in
            guard let strongSelf = self else { return }
            let args: NSDictionary = [
                "id": menuItem.tag,
            ]
            strongSelf.channel.invokeMethod(kEventOnTrayMenuItemClick, arguments: args, result: nil)
        }
        trayMenu?.delegate = self
        
        result(true)
    }
    
    public func popUpContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let menu = trayMenu, let button = trayIcon?.statusItem?.button else {
            result(true)
            return
        }
        if trayPopover?.isShown == true {
            trayPopover?.performClose(nil)
        }
        let point = NSPoint(x: button.bounds.midX, y: button.bounds.minY)
        menu.popUp(positioning: nil, at: point, in: button)
        result(true)
    }

    private func ensureTrayPopover() -> NSPopover {
        if let existing = trayPopover {
            return existing
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let size = NSSize(width: 360, height: 200)
        let vc = TrayPopoverScreenshotViewController()
        vc.onFullScreen = { [weak self] in
            self?.trayPopover?.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.runFullScreenCapture()
            }
        }
        vc.onRegion = { [weak self] in
            self?.trayPopover?.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.runRegionCapture()
            }
        }
        popover.contentViewController = vc
        popover.contentSize = size
        trayPopover = popover
        return popover
    }

    private func presentMarkup(path: String, flutterVisibilitySnapshot: [(NSWindow, Bool)]? = nil) {
        ScreenshotMarkupEditor.present(imagePath: path, flutterVisibilitySnapshot: flutterVisibilitySnapshot)
    }

    private func runFullScreenCapture() {
        let flutterSnap = TrayCaptureFlutterWindow.snapshotMainVisibility()
        NSApp.activate(ignoringOtherApps: true)
        TrayCaptureFlutterWindow.reapplyHiddenAfterActivate(flutterSnap)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let img = ScreenCaptureService.captureCompositeImage(),
                  let path = ScreenCaptureService.writeTempPNG(img) else {
                return
            }
            DispatchQueue.main.async {
                self?.presentMarkup(path: path, flutterVisibilitySnapshot: flutterSnap)
            }
        }
    }

    private func runRegionCapture() {
        let flutterSnap = TrayCaptureFlutterWindow.snapshotMainVisibility()
        NSApp.activate(ignoringOtherApps: true)
        TrayCaptureFlutterWindow.reapplyHiddenAfterActivate(flutterSnap)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let img = ScreenCaptureService.captureCompositeImage() else {
                return
            }
            let union = ScreenCaptureService.desktopUnionRect()
            DispatchQueue.main.async {
                guard let self = self else { return }
                let c = RegionSelectionController(fullImage: img, unionRect: union) { [weak self] path in
                    self?.regionSelectionController = nil
                    if let p = path {
                        self?.presentMarkup(path: p, flutterVisibilitySnapshot: flutterSnap)
                    }
                }
                self.regionSelectionController = c
                c.show()
                TrayCaptureFlutterWindow.reapplyHiddenAfterActivate(flutterSnap)
            }
        }
    }

    public func toggleTrayPopover(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let button = trayIcon?.statusItem?.button else {
            result(false)
            return
        }
        let popover = ensureTrayPopover()
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        result(true)
    }

    /// 供全局快捷键调用：仅展开截图 Popover（已展开时保持打开），行为与托盘左键一致但不切换关闭。
    public func showTrayScreenshotPopover(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let button = trayIcon?.statusItem?.button else {
            result(false)
            return
        }
        let popover = ensureTrayPopover()
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        result(true)
    }

    /// 快捷键：直接进入全屏截图 → 标注（不经过 Popover）。
    public func startFullScreenCapture(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        runFullScreenCapture()
        result(true)
    }

    /// 快捷键：直接进入区域选区截图 → 标注（不经过 Popover）。
    public func startRegionCapture(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        runRegionCapture()
        result(true)
    }
    
    // NSMenuDelegate
    
    public func menuDidClose(_ menu: NSMenu) {
        trayIcon?.statusItem?.menu = nil
    }
}
