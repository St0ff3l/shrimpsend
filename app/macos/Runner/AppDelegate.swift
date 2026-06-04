import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    for window in NSApplication.shared.windows {
      if let flutterViewController = window.contentViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: "dev.ultrasend/desktop_lifecycle",
          binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        channel.invokeMethod("bringToFront", arguments: nil, result: { _ in })
        break
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
