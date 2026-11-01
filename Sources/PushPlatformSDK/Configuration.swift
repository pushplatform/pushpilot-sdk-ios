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

    var apiKey: String?
    var apiBaseURL: String = "https://api.pushplatform.example"
    var environment: Environment = .production
    var debugMode: Bool = false
    var isConfigured: Bool {
        return apiKey != nil
    }

    func configure(apiKey: String, apiBaseURL: String, environment: Environment, debugMode: Bool) {
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
        self.environment = environment
        self.debugMode = debugMode
    }

    func reset() {
        apiKey = nil
        apiBaseURL = "https://api.pushplatform.example"
        environment = .production
        debugMode = false
    }
}
