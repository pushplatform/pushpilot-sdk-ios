import Foundation

/// Installation data model
public struct Installation: Codable {
    public let installationID: UUID
    public let platform: String
    public let osVersion: String
    public let appVersion: String
    public let sdkVersion: String
    public let locale: String
    public let timezone: String
    public var externalUserID: String?

    enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
        case platform
        case osVersion = "os_version"
        case appVersion = "app_version"
        case sdkVersion = "sdk_version"
        case locale
        case timezone
        case externalUserID = "external_user_id"
    }

    public init(
        installationID: UUID,
        platform: String = "ios",
        osVersion: String,
        appVersion: String,
        sdkVersion: String,
        locale: String,
        timezone: String,
        externalUserID: String? = nil
    ) {
        self.installationID = installationID
        self.platform = platform
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.sdkVersion = sdkVersion
        self.locale = locale
        self.timezone = timezone
        self.externalUserID = externalUserID
    }
}

/// Subscription data model
public struct Subscription: Codable {
    public let provider: String
    public let environment: String
    public let token: String
    public let bundleID: String

    enum CodingKeys: String, CodingKey {
        case provider
        case environment
        case token
        case bundleID = "bundle_id"
    }

    public init(
        provider: String,
        environment: String,
        token: String,
        bundleID: String
    ) {
        self.provider = provider
        self.environment = environment
        self.token = token
        self.bundleID = bundleID
    }
}

/// User association update model
struct UserUpdate: Codable {
    let externalUserID: String?

    enum CodingKeys: String, CodingKey {
        case externalUserID = "external_user_id"
    }
}

/// Wire contract for POST /v1/installations (separate from the public model).
struct InstallationRegistration: Encodable {
    let applicationID: UUID
    let deviceID: String
    let environment: String
    let osVersion: String
    let appVersion: String?
    let deviceModel: String
    let platform = "ios"
    let sdkVersion = "1.0.0"

    enum CodingKeys: String, CodingKey {
        case applicationID = "application_id", deviceID = "device_id"
        case environment, platform
        case osVersion = "os_version", appVersion = "app_version"
        case deviceModel = "device_model", sdkVersion = "sdk_version"
    }
}

struct InstallationRegistrationResponse: Decodable {
    let id: UUID
}
