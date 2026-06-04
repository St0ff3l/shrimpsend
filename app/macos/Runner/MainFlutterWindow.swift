import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let fileTimesChannel = FlutterMethodChannel(
      name: "dev.ultrasend/file_times",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileTimesChannel.setMethodCallHandler { call, result in
      guard call.method == "applyReceived" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let modifiedMs = args["modifiedMs"] as? Int,
            let createdMs = args["createdMs"] as? Int else {
        result(FlutterError(code: "INVALID_ARG", message: "missing args", details: nil))
        return
      }
      let url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.creationDate = Date(timeIntervalSince1970: Double(createdMs) / 1000.0)
      values.contentModificationDate = Date(timeIntervalSince1970: Double(modifiedMs) / 1000.0)
      do {
        var mutableUrl = url
        try mutableUrl.setResourceValues(values)
        result(true)
      } catch {
        result(FlutterError(code: "SET_FAILED", message: error.localizedDescription, details: nil))
      }
    }

    super.awakeFromNib()
  }
}
