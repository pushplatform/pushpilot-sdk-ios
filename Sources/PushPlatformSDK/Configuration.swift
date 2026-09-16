import Foundation

/// SDK environment for APNs
public enum Environment: String {
    case development
    case production
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
