import Foundation

/// SDK environment for APNs
public enum Environment: String {
    case development
    case production

    /// Transport-only APNs endpoint selection; not an application environment.
    public static var automatic: Environment {
        #if targetEnvironment(simulator)
        return .development
        #else
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url),
           let start = data.range(of: Data("<?xml".utf8)),
           let end = data.range(of: Data("</plist>".utf8)),
           start.lowerBound < end.upperBound,
           let document = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
           let entitlements = document["Entitlements"] as? [String: Any],
           let value = entitlements["aps-environment"] as? String,
           let environment = Environment(rawValue: value) { return environment }
        return .production
        #endif
    }
}

/// SDK configuration holder
class Configuration {
    static let shared = Configuration()

    private init() {}

    static let defaultAPIBaseURL = "https://api.pushpilot.ru"

    var serverURL: String = Configuration.defaultAPIBaseURL
    /// Nil means the registration body omits environment and the server uses production.
    var reportedEnvironment: String?
    var environment: Environment = .production
    var debugMode: Bool = false
    /// Seconds to wait for finish() before showing the system banner. Zero waits without a fallback.
    var foregroundBannerFallback: TimeInterval = 0
    private(set) var isConfigured = false

    func apply(baseURL: String, reportedEnvironment: String?, debugMode: Bool, foregroundBannerFallback: TimeInterval = 0) {
        serverURL = baseURL
        self.reportedEnvironment = reportedEnvironment
        environment = Environment(rawValue: reportedEnvironment ?? "") ?? .production
        self.debugMode = debugMode
        self.foregroundBannerFallback = foregroundBannerFallback
        isConfigured = true
    }

    func configure(apiKey: String, serverURL: String, environment: Environment, debugMode: Bool) {
        apply(baseURL: serverURL, reportedEnvironment: environment.rawValue, debugMode: debugMode)
    }

    func reset() {
        serverURL = Configuration.defaultAPIBaseURL
        reportedEnvironment = nil
        environment = .production
        debugMode = false
        foregroundBannerFallback = 0
        isConfigured = false
    }
}
