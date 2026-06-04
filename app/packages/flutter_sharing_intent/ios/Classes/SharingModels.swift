import Foundation

public let kSchemePrefix = "SharingMedia"
public let kUserDefaultsKey = "SharingKey"
public let kUserDefaultsMessageKey = "SharingMessageKey"
public let kAppGroupIdKey = "AppGroupId"
public let kAppChannel = "flutter_sharing_intent"

public class SharingFile: Codable {
    public var value: String
    public var mimeType: String?
    public var thumbnail: String?
    public var duration: Int?
    public var type: SharingFileType
    public var message: String?

    enum CodingKeys: String, CodingKey {
        case value
        case mimeType
        case thumbnail
        case duration
        case type
        case message
    }

    public init(
        value: String,
        mimeType: String? = nil,
        thumbnail: String?,
        duration: Int?,
        type: SharingFileType,
        message: String? = nil
    ) {
        self.value = value
        self.mimeType = mimeType
        self.thumbnail = thumbnail
        self.duration = duration
        self.type = type
        self.message = message
    }
}

public enum SharingFileType: Int, Codable {
    case text
    case url
    case image
    case video
    case file
}
