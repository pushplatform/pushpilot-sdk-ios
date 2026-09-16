import Foundation

/// Errors that can occur in PushPlatform SDK
public enum SDKError: Error {
    case notConfigured
    case invalidAPIKey
    case networkError(underlying: Error)
    case apiError(statusCode: Int, message: String)
    case invalidToken
    case maxRetriesExceeded
    case keychainAccessDenied
}

extension SDKError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SDK not configured. Call PushPlatform.shared.configure() first."
        case .invalidAPIKey:
            return "Invalid API key provided."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .invalidToken:
            return "Invalid token format."
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded."
        case .keychainAccessDenied:
            return "Keychain access denied. Check device security settings."
        }
    }
}
