// FSIShareViewController.swift
// Merged, optimized controller: uses RSI architecture with all FSI features preserved
// Uses model name `SharingFile` (same fields as SharedMediaFile) where `value` = path

import AVFoundation
import MobileCoreServices
import Social
import UIKit
import UniformTypeIdentifiers

public let kSchemePrefix = "SharingMedia"
public let kUserDefaultsKey = "SharingKey"
public let kUserDefaultsMessageKey = "SharingMessageKey"
public let kAppGroupIdKey = "AppGroupId"
public let kAppChannel = "flutter_sharing_intent"

// extension UIViewController {
//     func showToast(_ message: String, duration: Double = 2.0) {
//         let toastLabel = UILabel()
//         toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
//         toastLabel.textColor = UIColor.white
//         toastLabel.textAlignment = .center
//         toastLabel.font = UIFont.systemFont(ofSize: 14)
//         toastLabel.text = message
//         toastLabel.alpha = 0.0
//         toastLabel.numberOfLines = 0
//         toastLabel.layer.cornerRadius = 10
//         toastLabel.clipsToBounds = true
//
//         let maxWidthPercentage: CGFloat = 0.8
//         let maxMessageSize = CGSize(
//             width: self.view.bounds.size.width * maxWidthPercentage,
//             height: self.view.bounds.size.height * maxWidthPercentage
//         )
//
//         var expectedSize = toastLabel.sizeThatFits(maxMessageSize)
//         expectedSize.width += 24
//         expectedSize.height += 16
//
//         toastLabel.frame = CGRect(
//             x: (self.view.frame.size.width - expectedSize.width) / 2,
//             y: self.view.frame.size.height - expectedSize.height - 50,
//             width: expectedSize.width,
//             height: expectedSize.height
//         )
//
//         self.view.addSubview(toastLabel)
//
//         UIView.animate(withDuration: 0.5, animations: {
//             toastLabel.alpha = 1.0
//         }) { _ in
//             UIView.animate(withDuration: 0.5, delay: duration, options: .curveEaseOut, animations: {
//                 toastLabel.alpha = 0.0
//             }) { _ in
//                 toastLabel.removeFromSuperview()
//             }
//         }
//     }
// }

// @objc(FSIShareViewController)
@available(swift, introduced: 5.0)
open class FSIShareViewController: SLComposeServiceViewController {
    // MARK: - Config
    private(set) var hostAppBundleIdentifier: String = ""
    private(set) var appGroupId: String = ""
    
    // Results
    private var sharedMedia: [SharingFile] = []
    
    // Debug — key paths also use print("FSIShare: ...") for device diagnostics
    private let debugLogs = true
    
    // MARK: - Lifecycle
    open override func viewDidLoad() {
        super.viewDidLoad()
        loadIds()
    }
    
    open override func isContentValid() -> Bool {
        return true
    }
    
    open override func didSelectPost() {
        if self.sharedMedia.isEmpty {
            if let text = self.contentText, !text.isEmpty {
                self.sharedMedia.append(
                    SharingFile(value: text, thumbnail: nil, duration: nil, type: .text)
                )
                self.saveAndRedirect(message: text)
                return
            }
            self.completeAndExit()
        } else {
            self.saveAndRedirect()
        }
        // If the UI Post is used, save and redirect using contentText
//        saveAndRedirect(message: contentText)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Process attachments automatically on appear like original FSI
        processAttachments()
    }
    
    // MARK: - Load Ids
    private func loadIds() {
        let shareExtId = Bundle.main.bundleIdentifier ?? ""
        if let idx = shareExtId.lastIndex(of: ".") {
            hostAppBundleIdentifier = String(shareExtId[..<idx])
        } else {
            hostAppBundleIdentifier = shareExtId
        }
        let custom = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
        appGroupId = custom ?? "group.\(hostAppBundleIdentifier)"
        log("loaded host=\(hostAppBundleIdentifier) group=\(appGroupId)")
    }
    
    // MARK: - Attachment processing (clean RSI style, preserve FSI features)
    private func processAttachments() {
        loadIds()
        if containerURL() == nil {
            print("FSIShare: App Group containerURL is nil for group=\(appGroupId). Check Apple Developer portal entitlements.")
            completeAndExit()
            return
        }

        guard let content = extensionContext?.inputItems.first as? NSExtensionItem else {
            print("FSIShare: no NSExtensionItem in inputItems")
            completeAndExit()
            return
        }
        
        guard let attachments = content.attachments, !attachments.isEmpty else {
            print("FSIShare: no attachments in extension item")
            completeAndExit()
            return
        }
        
        // Use DispatchGroup to wait for async loads
        let group = DispatchGroup()
        for (index, provider) in attachments.enumerated() {
            group.enter()
            // Try all SharedMediaType options similar to RSI but preserve explicit FSI order
            if provider.isImage {
                provider.loadItem(forTypeIdentifier: UType.image, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleImageItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isMovie {
                provider.loadItem(forTypeIdentifier: UType.movie, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleVideoItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isFile {
                provider.loadItem(forTypeIdentifier: UType.fileURL, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleFileItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isURL {
                provider.loadItem(forTypeIdentifier: UType.url, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleUrlItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isText {
                let id = provider.hasItemConformingToTypeIdentifier(UType.plainText)
                ? UType.plainText
                : UType.text
                provider.loadItem(forTypeIdentifier: id, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleTextItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isData {
                provider.loadItem(forTypeIdentifier: UType.data, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleFileItem(data: data, index: index, total: attachments.count)
                }
                continue
            }
            
            if provider.isItem {
                provider.loadItem(forTypeIdentifier: UType.item, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleFileItem(data: data, index: index, total: attachments.count)
                }
                continue
            }

            if loadProviderFallback(provider: provider, index: index, total: attachments.count, group: group) {
                continue
            }

            print("FSIShare: unknown provider type: \(provider.registeredTypeIdentifiers)")
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            // if we have media -> media, else fallback to complete
            if !self.sharedMedia.isEmpty {
                self.saveAndRedirect()
            } else {
                print("FSIShare: No shared media → stopping.")
                self.completeAndExit()
            }
        }
    }
    
    // MARK: - Individual handlers (preserve FSI behavior)
    private func handleTextItem(data: NSSecureCoding?, index: Int, total: Int) {
        if let s = data as? String {
            sharedMedia.append(SharingFile(value: s, thumbnail: nil, duration: nil, type: .text))
        } else if let url = data as? URL {
            sharedMedia.append(SharingFile(value: url.absoluteString, thumbnail: nil, duration: nil, type: .url))
        }
        
    }
    
    private func handleUrlItem(data: NSSecureCoding?, index: Int, total: Int) {
        if let url = data as? URL {
            sharedMedia.append(SharingFile(value: url.absoluteString, thumbnail: nil, duration: nil, type: .url))
        } else if let s = data as? String {
            sharedMedia.append(SharingFile(value: s, thumbnail: nil, duration: nil, type: .text))
        }
        
    }
    
    private func handleImageItem(data: NSSecureCoding?, index: Int, total: Int) {
        // data can be URL, UIImage, or Data
        if let url = data as? URL {
            let filename = uniqueFileName(from: url, type: .image, index: index, total: total)
            if let dst = containerURL()?.appendingPathComponent(filename) {
                if copyFile(at: url, to: dst) {
                    sharedMedia.append(SharingFile(value: dst.absoluteString, mimeType: url.mimeType(), thumbnail: nil, duration: nil, type: .image))
                }
            }
        } else if let img = data as? UIImage {
            if let saved = writeTempImage(img) {
                sharedMedia.append(saved)
            }
        } else if let raw = data as? Data, let img = UIImage(data: raw) {
            if let saved = writeTempImage(img) {
                sharedMedia.append(saved)
            }
        }
        
    }
    
    private func handleVideoItem(data: NSSecureCoding?, index: Int, total: Int) {
        if let url = data as? URL {
            let filename = uniqueFileName(from: url, type: .video, index: index, total: total)
            if let dst = containerURL()?.appendingPathComponent(filename) {
                if copyFile(at: url, to: dst) {
                    if let m = getSharedMediaFile(forVideo: dst) {
                        sharedMedia.append(m)
                    }
                }
            }
        }
        
    }
    
    private func handleFileItem(data: NSSecureCoding?, index: Int, total: Int) {
        if let url = data as? URL {
            let filename = uniqueFileName(from: url, type: .file, index: index, total: total)
            guard let dst = containerURL()?.appendingPathComponent(filename) else {
                print("FSIShare: handleFileItem[\(index)] containerURL nil")
                return
            }
            if copyFile(at: url, to: dst) {
                sharedMedia.append(SharingFile(value: dst.absoluteString, mimeType: url.mimeType(), thumbnail: nil, duration: nil, type: .file))
            } else {
                print("FSIShare: handleFileItem[\(index)] copyFile failed src=\(url.path)")
            }
        }
        else if let raw = data as? Data {
            let filename = "File_\(UUID().uuidString)"
            if let dst = containerURL()?.appendingPathComponent(filename) {
                do {
                    try raw.write(to: dst)
                    sharedMedia.append(SharingFile(value: dst.absoluteString, mimeType: "application/octet-stream", thumbnail: nil, duration: nil, type: .file))
                } catch {
                    print("FSIShare: handleFileItem[\(index)] write Data failed: \(error)")
                }
            }
        }
        
        
    }

    /// Fallback for providers whose UTType is not covered by the explicit is* checks.
    private func loadProviderFallback(
        provider: NSItemProvider,
        index: Int,
        total: Int,
        group: DispatchGroup
    ) -> Bool {
        let fallbackTypes = [UType.fileURL, UType.data, UType.item]
        for typeId in fallbackTypes {
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] data, error in
                    defer { group.leave() }
                    guard let self = self else { return }
                    if let error = error {
                        self.logAttachmentError(error, index: index)
                        return
                    }
                    self.handleFileItem(data: data, index: index, total: total)
                }
                return true
            }
        }

        guard let firstType = provider.registeredTypeIdentifiers.first else {
            return false
        }

        print("FSIShare: fallback load registered type \(firstType) for provider[\(index)]")
        provider.loadItem(forTypeIdentifier: firstType, options: nil) { [weak self] data, error in
            defer { group.leave() }
            guard let self = self else { return }
            if let error = error {
                self.logAttachmentError(error, index: index)
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UType.image) {
                self.handleImageItem(data: data, index: index, total: total)
            } else if provider.hasItemConformingToTypeIdentifier(UType.movie) {
                self.handleVideoItem(data: data, index: index, total: total)
            } else {
                self.handleFileItem(data: data, index: index, total: total)
            }
        }
        return true
    }
    
    // MARK: - Helpers: write temp image
    private func writeTempImage(_ image: UIImage) -> SharingFile? {
        guard let container = containerURL() else { return nil }
        let tempName = "TempImage_\(UUID().uuidString).png"
        let dst = container.appendingPathComponent(tempName)
        do {
            if let d = image.pngData() {
                try d.write(to: dst)
                let decoded = dst.absoluteString.removingPercentEncoding ?? dst.absoluteString
                return SharingFile(value: decoded, mimeType: "image/png", thumbnail: nil, duration: nil, type: .image)
            }
        } catch {
            log("writeTempImage error: \(error)")
        }
        return nil
    }
    
    
    private func saveAndRedirect(message: String? = nil) {
        let ud = UserDefaults(suiteName: appGroupId)
        if !sharedMedia.isEmpty {
            if let data = try? JSONEncoder().encode(sharedMedia) {
                ud?.set(data, forKey: kUserDefaultsKey)
            }
        }
        ud?.set(message, forKey: kUserDefaultsMessageKey)
        ud?.synchronize()
        print("FSIShare: saveAndRedirect mediaCount=\(sharedMedia.count) group=\(appGroupId)")
        redirectToHostApp()
    }
    
    
    private func redirectToHostApp() {
        loadIds()
        let raw = "\(kSchemePrefix)-\(hostAppBundleIdentifier)://dataUrl=\(kUserDefaultsKey)"
        guard let url = URL(string: raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw) else {
            print("FSIShare: redirectToHostApp failed to build URL raw=\(raw)")
            completeAndExit()
            return
        }

        print("FSIShare: redirect url=\(url.absoluteString) host=\(hostAppBundleIdentifier)")

        extensionContext?.open(url, completionHandler: { [weak self] success in
            guard let self = self else { return }
            if success {
                print("FSIShare: extensionContext.open success")
            } else {
                print("FSIShare: extensionContext.open failed, trying responder chain fallback")
                self.openHostAppViaResponderChain(url: url)
            }
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
    }

    private func openHostAppViaResponderChain(url: URL) {
        var responder: UIResponder? = self
        if #available(iOS 18.0, *) {
            while responder != nil {
                if let app = responder as? UIApplication {
                    app.open(url, options: [:], completionHandler: { success in
                        print("FSIShare: UIApplication.open success=\(success)")
                    })
                    return
                }
                responder = responder?.next
            }
        } else {
            let sel = sel_registerName("openURL:")
            while responder != nil {
                if responder?.responds(to: sel) ?? false {
                    _ = responder?.perform(sel, with: url)
                    print("FSIShare: openURL: via responder chain")
                    return
                }
                responder = responder?.next
            }
        }
        print("FSIShare: responder chain fallback failed")
    }
    
    // MARK: - File / thumbnail / metadata helpers
    func getExtension(from url: URL, type: SharingFileType) -> String {
        let parts = url.lastPathComponent.components(separatedBy: ".")
        var ex: String? = nil
        if parts.count > 1 { ex = parts.last }
        if ex == nil {
            switch type {
            case .image: ex = "png"
            case .video: ex = "mp4"
            case .file: ex = "txt"
            case .text: ex = "txt"
            case .url: ex = "txt"
            }
        }
        return ex ?? "bin"
    }
    
    func getFileName(from url: URL, type: SharingFileType) -> String {
        var name = url.lastPathComponent
        if name.isEmpty { name = UUID().uuidString + "." + getExtension(from: url, type: type) }
        return name
    }

    private func uniqueFileName(from url: URL, type: SharingFileType, index: Int, total: Int) -> String {
        var name = getFileName(from: url, type: type)
        if total > 1 || index > 0 {
            let dotIndex = name.lastIndex(of: ".")
            if let dotIndex = dotIndex, dotIndex != name.startIndex {
                let stem = String(name[..<dotIndex])
                let ext = String(name[dotIndex...])
                name = "\(stem)_\(index + 1)\(ext)"
            } else {
                name = "\(name)_\(index + 1)"
            }
        }
        guard let container = containerURL() else { return name }
        var candidate = name
        var suffix = 1
        while FileManager.default.fileExists(atPath: container.appendingPathComponent(candidate).path) {
            let dotIndex = name.lastIndex(of: ".")
            if let dotIndex = dotIndex, dotIndex != name.startIndex {
                let stem = String(name[..<dotIndex])
                let ext = String(name[dotIndex...])
                candidate = "\(stem)_\(suffix)\(ext)"
            } else {
                candidate = "\(name)_\(suffix)"
            }
            suffix += 1
        }
        return candidate
    }
    
    func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        let accessed = srcURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                srcURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) { try FileManager.default.removeItem(at: dstURL) }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
            return true
        } catch {
            print("FSIShare: copyFile error: \(error)")
            return false
        }
    }
    
    private func getSharedMediaFile(forVideo: URL) -> SharingFile? {
        let asset = AVAsset(url: forVideo)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: forVideo)
        
        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return SharingFile(value: forVideo.absoluteString, mimeType: forVideo.mimeType(), thumbnail: thumbnailPath.absoluteString, duration: Int(duration), type: .video)
        }
        
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 360, height: 360)
        
        // Use first second or zero
        let time = CMTime(seconds: min(1.0, CMTimeGetSeconds(asset.duration)), preferredTimescale: 600)
        do {
            let cg = try gen.copyCGImage(at: time, actualTime: nil)
            if let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8) {
                try data.write(to: thumbnailPath)
                return SharingFile(value: forVideo.absoluteString, mimeType: forVideo.mimeType(), thumbnail: thumbnailPath.absoluteString, duration: Int(duration), type: .video)
            }
        } catch {
            log("getSharedMediaFile thumbnail error: \(error)")
        }
        
        // fallback
        return SharingFile(value: forVideo.absoluteString, mimeType: forVideo.mimeType(), thumbnail: nil, duration: Int(duration), type: .video)
    }
    
    private func getThumbnailPath(for url: URL) -> URL {
        guard let container = containerURL() else { fatalError("App group not configured or missing") }
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        return container.appendingPathComponent("\(fileName).jpg")
    }
    
    private func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    private func completeAndExit() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func logAttachmentError(_ error: Error, index: Int) {
        print("FSIShare: attachment[\(index)] load failed: \(error.localizedDescription)")
    }
    
    private func writeTempFile(_ image: UIImage, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) { try FileManager.default.removeItem(at: dstURL) }
            let pngData = image.pngData()
            try pngData?.write(to: dstURL)
            return true
        } catch (let error) {
            log("writeTempFile error: \(error)")
            return false
        }
    }
    
    private func saveToUserDefaults(data: [SharingFile]) {
        let ud = UserDefaults(suiteName: appGroupId)
        if let enc = try? JSONEncoder().encode(data) { ud?.set(enc, forKey: kUserDefaultsKey); ud?.synchronize() }
    }
    
    // MARK: - Logging
    private func log(_ s: String) { if debugLogs { print("[FSIShareVC] \(s)") } }
    
}

// MARK: - Extensions
extension URL {
    func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let ut = UTType(filenameExtension: self.pathExtension), let m = ut.preferredMIMEType { return m }
        } else {
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, self.pathExtension as NSString, nil)?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() { return mimetype as String }
            }
        }
        return "application/octet-stream"
    }
}

extension NSItemProvider {
    var isImage: Bool { return hasItemConformingToTypeIdentifier(UType.image) }
    var isMovie: Bool { return hasItemConformingToTypeIdentifier(UType.movie) }
    var isText: Bool {
        hasItemConformingToTypeIdentifier(UType.plainText) || hasItemConformingToTypeIdentifier(UType.text)
    }
    var isURL: Bool { return hasItemConformingToTypeIdentifier(UType.url) }
    var isFile: Bool { return hasItemConformingToTypeIdentifier(UType.fileURL) }
    var isData:Bool { return hasItemConformingToTypeIdentifier(UType.data) }
    var isItem: Bool { hasItemConformingToTypeIdentifier(UType.item) }

}

extension Array {
    subscript(safe index: UInt) -> Element? { return Int(index) < count ? self[Int(index)] : nil }
}


class SharingFile: Codable {
    var value: String
    var mimeType: String?
    var thumbnail: String?; // video thumbnail
    var duration: Int?; // video duration in milliseconds
    var type: SharingFileType;
    var message: String? // post message
    
    enum CodingKeys: String, CodingKey {
        case value
        case mimeType
        case thumbnail
        case duration
        case type
        case message
    }
    
    init(value: String, mimeType: String? = nil, thumbnail: String?, duration: Int?,
         type: SharingFileType, message: String?=nil) {
        self.value = value
        self.mimeType = mimeType
        self.thumbnail = thumbnail
        self.duration = duration
        self.type = type
        self.message = message
    }
    
    // Debug method to print out SharedMediaFile details in the console
    func toString() {
        print("[SharingFile] \n\tvalue: \(self.value)\n\tthumbnail: \(self.thumbnail ?? "--" )\n\tduration: \(self.duration ?? 0)\n\ttype: \(self.type)\n\tmimeType: \(String(describing: self.mimeType))\n\tmessage: \(String(describing: self.message))")
    }
}


enum SharingFileType: Int, Codable {
    case text
    case url
    case image
    case video
    case file
}

// Unified UTType → works on iOS 11–18
enum UType {
    static var image: String {
        if #available(iOS 14.0, *) {
            return UTType.image.identifier
        } else {
            return kUTTypeImage as String   // old API
        }
    }
    
    static var movie: String {
        if #available(iOS 14.0, *) {
            return UTType.movie.identifier
        } else {
            return kUTTypeMovie as String
        }
    }
    
    
    static var url: String {
        if #available(iOS 14.0, *) {
            return UTType.url.identifier
        } else {
            return kUTTypeURL as String
        }
    }
    
    static var fileURL: String {
        if #available(iOS 14.0, *) {
            return UTType.fileURL.identifier
        } else {
            return kUTTypeFileURL as String
        }
    }
    
    static var text: String {
        if #available(iOS 14.0, *) {
            return UTType.text.identifier
        } else {
            return kUTTypeText as String
        }
    }
    
    static var plainText: String {
        if #available(iOS 14.0, *) {
            return UTType.plainText.identifier
        } else {
            return kUTTypePlainText as String
        }
    }
    
    static var data: String {
        if #available(iOS 14.0, *) {
            return UTType.data.identifier
        } else {
            return kUTTypeData as String
        }
    }
    
    static var item: String {
        if #available(iOS 14.0, *) {
            return UTType.item.identifier
        } else {
            return kUTTypeItem as String
        }
    }
}

