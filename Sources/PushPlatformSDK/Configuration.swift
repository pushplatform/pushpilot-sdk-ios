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

    var apiBaseURL: String = Configuration.defaultAPIBaseURL
    /// Nil means the registration body omits environment and the server uses production.
    var reportedEnvironment: String?
    var environment: Environment = .production
    var debugMode: Bool = false
    private(set) var isConfigured = false

    func apply(baseURL: String, reportedEnvironment: String?, debugMode: Bool) {
        apiBaseURL = baseURL
        self.reportedEnvironment = reportedEnvironment
        environment = Environment(rawValue: reportedEnvironment ?? "") ?? .production
        self.debugMode = debugMode
        isConfigured = true
    }

    func configure(apiKey: String, apiBaseURL: String, environment: Environment, debugMode: Bool) {
        apply(baseURL: apiBaseURL, reportedEnvironment: environment.rawValue, debugMode: debugMode)
    }

    func reset() {
        apiBaseURL = Configuration.defaultAPIBaseURL
        reportedEnvironment = nil
        environment = .production
        debugMode = false
        isConfigured = false
    }
}
