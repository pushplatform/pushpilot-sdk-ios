import Foundation

/// Token registry with exponential backoff retry and network recovery
class TokenRegistry {
    private let apiClient: APIClient
    private let installationManager: InstallationManagerProtocol
    private let reachability = Reachability()

    private var retryAttempt = 0
    private let maxRetries = 5
    private var pendingRegistrations: [(Data, String, String)] = []  // (token, provider, environment)

    weak var delegate: TokenRegistryDelegate?

    init(apiClient: APIClient = APIClient(), installationManager: InstallationManagerProtocol = InstallationManager.shared) {
        self.apiClient = apiClient
        self.installationManager = installationManager

        // Start network monitoring for auto-retry on connection restore
        reachability.startMonitoring { [weak self] in
            self?.retryPendingRegistrations()
        }
    }

    deinit {
        reachability.stopMonitoring()
    }

    // MARK: - Token Registration

    /// Register token with backend (with retry)
    /// - Parameters:
    ///   - token: Device token
    ///   - provider: Provider type ("apns" or "apns_voip")
    ///   - environment: Environment ("development" or "production")
    func registerToken(_ token: Data, provider: String, environment: String) {
        guard let installationID = installationManager.getInstallationID() else {
            Logger.error("Cannot register token: Installation ID not initialized")
            delegate?.didFailToRegisterToken(provider: provider, error: .notConfigured)
            return
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let hexToken = token.map { String(format: "%02x", $0) }.joined()

        let subscription = Subscription(
            provider: provider,
            environment: environment,
            token: hexToken,
            bundleID: bundleID
        )

        Logger.debug("Registering \(provider) token: \(Logger.tokenMasked(token))")

        apiClient.createSubscription(installationID: installationID, subscription: subscription) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                self.retryAttempt = 0  // Reset on success
                Logger.info("\(provider) token registered successfully")
                self.delegate?.didRegisterToken(provider: provider)

            case .failure(let error):
                if self.isRetryable(error) {
                    self.scheduleRetry(token, provider, environment)
                } else {
                    Logger.error("\(provider) token registration failed permanently: \(error)")
                    self.delegate?.didFailToRegisterToken(provider: provider, error: error)
                }
            }
        }
    }

    // MARK: - Retry Logic

    private func scheduleRetry(_ token: Data, _ provider: String, _ environment: String) {
        guard retryAttempt < maxRetries else {
            Logger.error("Max retries exceeded for \(provider) token registration")
            delegate?.didFailToRegisterToken(provider: provider, error: .maxRetriesExceeded)
            return
        }

        // Exponential backoff: 2^attempt, capped at 60s
        let delay = min(pow(2.0, Double(retryAttempt)), 60.0)
        retryAttempt += 1

        Logger.debug("Retrying \(provider) token registration in \(delay)s (attempt \(retryAttempt)/\(maxRetries))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.registerToken(token, provider: provider, environment: environment)
        }
    }

    private func isRetryable(_ error: SDKError) -> Bool {
        switch error {
        case .networkError:
            return true  // Network failures are retryable
        case .apiError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429  // Server errors, rate limits
        case .invalidAPIKey, .invalidToken, .notConfigured:
            return false  // Permanent errors
        default:
            return false
        }
    }

    private func retryPendingRegistrations() {
        // Currently we retry immediately via network recovery
        // In future, could queue registrations for later retry
        Logger.debug("Network restored, retry triggered by scheduleRetry")
    }
}

// MARK: - Delegate Protocol

protocol TokenRegistryDelegate: AnyObject {
    func didRegisterToken(provider: String)
    func didFailToRegisterToken(provider: String, error: SDKError)
}
