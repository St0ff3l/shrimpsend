import Flutter
import flutter_sharing_intent
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "dev.ultrasend/file_times",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
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
    }
    return didFinish
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let sharingIntent = SwiftFlutterSharingIntentPlugin.instance
    if sharingIntent.hasSameSchemePrefix(url: url) {
      return sharingIntent.application(app, open: url, options: options)
    }
    return super.application(app, open: url, options: options)
  }
}
