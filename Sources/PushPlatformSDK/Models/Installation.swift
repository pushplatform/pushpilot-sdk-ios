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
    public let apnsSandbox: Bool
    public let provider: String
    public let environment: String
    public let token: String
    public let bundleID: String

    enum CodingKeys: String, CodingKey {
        case provider
        case apnsSandbox = "apns_sandbox"
        case environment
        case token
        case bundleID = "bundle_id"
    }

    public init(
        provider: String,
        environment: String,
        token: String,
        bundleID: String,
        apnsSandbox: Bool? = nil
    ) {
        // Storage environment is production (or omitted). Sandbox is an explicit transport flag.
        // Legacy callers that still pass environment "development" keep sandbox=true.
        if let apnsSandbox {
            self.apnsSandbox = apnsSandbox
        } else {
            self.apnsSandbox = environment == "development"
        }
        self.provider = provider
        self.environment = environment.isEmpty ? "production" : environment
        self.token = token
        self.bundleID = bundleID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(token, forKey: .token)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(apnsSandbox, forKey: .apnsSandbox)
        if !environment.isEmpty {
            try container.encode(environment, forKey: .environment)
        }
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
    let sdkVersion = "1.1.0"
    var deviceKind: String = DeviceMetadata.kind
    var locale: String = Locale.current.identifier
    var timezone: String = TimeZone.current.identifier
    var notificationPermission: String = "unknown"

    enum CodingKeys: String, CodingKey {
        case applicationID = "application_id", deviceID = "device_id"
        case environment, platform
        case osVersion = "os_version", appVersion = "app_version"
        case deviceModel = "device_model", sdkVersion = "sdk_version"
        case deviceKind = "device_kind", notificationPermission = "notification_permission"
        case locale, timezone
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applicationID, forKey: .applicationID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(platform, forKey: .platform)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(sdkVersion, forKey: .sdkVersion)
        try container.encode(deviceKind, forKey: .deviceKind)
        try container.encode(locale, forKey: .locale)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(notificationPermission, forKey: .notificationPermission)
        if !environment.isEmpty {
            try container.encode(environment, forKey: .environment)
        }
    }
}

struct InstallationRegistrationResponse: Decodable {
    let id: UUID
}

struct TokenRegistrationResponse: Decodable {
    let subscriptionID: String?

    enum CodingKeys: String, CodingKey {
        case subscriptionID = "subscription_id"
    }
}
