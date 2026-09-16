import Foundation

/// Internal logger with token masking for security
class Logger {
    static var debugMode: Bool {
        get { Configuration.shared.debugMode }
        set { Configuration.shared.debugMode = newValue }
    }

    static func debug(_ message: String) {
        guard debugMode else { return }
        print("[PushPlatform DEBUG] \(message)")
    }

    static func info(_ message: String) {
        print("[PushPlatform INFO] \(message)")
    }

    static func error(_ message: String) {
        print("[PushPlatform ERROR] \(message)")
    }

    // MARK: - Token Masking

    /// Masks token to show only first 8 hex characters
    /// - Parameter token: Device token data
    /// - Returns: Masked string like "a1b2c3d4..."
    static func tokenMasked(_ token: Data) -> String {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        guard hex.count >= 8 else {
            return "***"
        }
        let prefix = String(hex.prefix(8))
        return "\(prefix)..."
    }

    /// Masks API key to show only first 8 characters
    /// - Parameter apiKey: API key string
    /// - Returns: Masked string like "pk_test_..."
    static func apiKeyMasked(_ apiKey: String) -> String {
        guard apiKey.count > 8 else { return "***" }
        let prefix = String(apiKey.prefix(8))
        return "\(prefix)..."
    }
}
