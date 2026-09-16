import Foundation

/// APNs token manager with automatic registration and token change detection
class APNsTokenManager {
    private let tokenRegistry: TokenRegistry
    private var currentToken: Data?

    weak var delegate: APNsTokenManagerDelegate?

    init(tokenRegistry: TokenRegistry) {
        self.tokenRegistry = tokenRegistry
        self.tokenRegistry.delegate = self
    }

    /// Handle APNs token registration
    /// - Parameter token: Device token from didRegisterForRemoteNotifications
    func didReceiveAPNsToken(_ token: Data) {
        // Check if token changed
        if currentToken == token {
            Logger.debug("APNs token unchanged, skipping re-registration")
            return
        }

        currentToken = token

        let environment = Configuration.shared.environment.rawValue
        Logger.info("APNs token received: \(Logger.tokenMasked(token)), environment: \(environment)")

        // Register with backend
        tokenRegistry.registerToken(token, provider: "apns", environment: environment)
    }

    /// Handle APNs registration failure
    /// - Parameter error: Registration error
    func didFailToRegisterAPNs(_ error: Error) {
        Logger.error("APNs registration failed: \(error.localizedDescription)")
        delegate?.didFailToRegisterAPNsToken(error: error)
    }
}

// MARK: - TokenRegistryDelegate

extension APNsTokenManager: TokenRegistryDelegate {
    func didRegisterToken(provider: String) {
        guard provider == "apns" else { return }
        delegate?.didRegisterAPNsToken()
    }

    func didFailToRegisterToken(provider: String, error: SDKError) {
        guard provider == "apns" else { return }
        delegate?.didFailToRegisterAPNsToken(error: error)
    }
}

// MARK: - Delegate Protocol

protocol APNsTokenManagerDelegate: AnyObject {
    func didRegisterAPNsToken()
    func didFailToRegisterAPNsToken(error: Error)
}
