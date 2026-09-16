import Foundation

/// Main SDK façade - singleton instance for push platform integration
public class PushPlatform {
    /// Shared singleton instance
    public static let shared = PushPlatform()

    private let configuration = Configuration.shared
    private let installationManager = InstallationManager.shared
    private let tokenRegistry = TokenRegistry()
    private var apnsTokenManager: APNsTokenManager?
    private var pushKitManager: PushKitManager?

    private init() {
        // Initialize APNs token manager
        apnsTokenManager = APNsTokenManager(tokenRegistry: tokenRegistry)
        apnsTokenManager?.delegate = self

        // Initialize PushKit manager
        pushKitManager = PushKitManager(tokenRegistry: tokenRegistry)
        pushKitManager?.delegate = self
    }

    // MARK: - Configuration

    /// Initialize SDK with API key and environment
    /// - Parameters:
    ///   - apiKey: API key from push-platform dashboard (devices:write scope)
    ///   - apiBaseURL: Base URL (default: https://api.pushplatform.example)
    ///   - environment: .development (sandbox) or .production
    ///   - debugMode: Enable verbose logging (default: false)
    public func configure(
        apiKey: String,
        apiBaseURL: String = "https://api.pushplatform.example",
        environment: Environment,
        debugMode: Bool = false
    ) {
        configuration.configure(
            apiKey: apiKey,
            apiBaseURL: apiBaseURL,
            environment: environment,
            debugMode: debugMode
        )

        Logger.info("SDK configured with environment: \(environment.rawValue), debug: \(debugMode)")
        Logger.debug("API key: \(Logger.apiKeyMasked(apiKey))")

        // Initialize installation ID
        do {
            let installationID = try installationManager.initialize()
            delegate?.didInitialize(installationID: installationID)
        } catch {
            Logger.error("Failed to initialize installation ID: \(error)")
            delegate?.didFailRegisterTokens(error: error as? SDKError ?? .keychainAccessDenied)
        }
    }

    // MARK: - Installation ID

    /// Get current installation ID (UUID)
    /// - Returns: Installation ID if SDK initialized, nil otherwise
    public func getInstallationID() -> UUID? {
        return installationManager.getInstallationID()
    }

    // MARK: - User Association

    /// Associate installation with external user ID
    /// - Parameters:
    ///   - userID: External user identifier from your system
    ///   - completion: Result callback
    public func login(
        userID: String,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard configuration.isConfigured else {
            Logger.error("SDK not configured")
            completion(.failure(.notConfigured))
            return
        }

        Logger.info("User login requested: userID=\(userID)")
        // TODO: Implement in TASK-006A-03 (API Client)
        completion(.failure(.notConfigured))
    }

    /// Dissociate user from installation (installation remains active)
    /// - Parameter completion: Result callback
    public func logout(
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard configuration.isConfigured else {
            Logger.error("SDK not configured")
            completion(.failure(.notConfigured))
            return
        }

        Logger.info("User logout requested")
        // TODO: Implement in TASK-006A-03 (API Client)
        completion(.failure(.notConfigured))
    }

    // MARK: - Token Registration

    /// Register APNs token (call from AppDelegate didRegisterForRemoteNotifications)
    /// - Parameter token: Device token data
    public func didRegisterAPNsToken(_ token: Data) {
        guard configuration.isConfigured else {
            Logger.error("SDK not configured, cannot register APNs token")
            return
        }

        Logger.info("APNs token received: \(Logger.tokenMasked(token))")
        apnsTokenManager?.didReceiveAPNsToken(token)
    }

    /// Handle APNs registration failure
    /// - Parameter error: Registration error
    public func didFailToRegisterAPNs(_ error: Error) {
        Logger.error("APNs registration failed: \(error.localizedDescription)")
        apnsTokenManager?.didFailToRegisterAPNs(error)
    }

    // MARK: - Delegate

    /// Set delegate for SDK callbacks
    public weak var delegate: PushPlatformDelegate?
}

// MARK: - APNsTokenManagerDelegate

extension PushPlatform: APNsTokenManagerDelegate {
    func didRegisterAPNsToken() {
        delegate?.didUpdateAPNsToken()
    }

    func didFailToRegisterAPNsToken(error: Error) {
        delegate?.didFailRegisterTokens(error: error as? SDKError ?? .networkError(underlying: error))
    }
}

// MARK: - PushKitManagerDelegate

extension PushPlatform: PushKitManagerDelegate {
    func didRegisterVoIPToken() {
        delegate?.didUpdateVoIPToken()
    }

    func didFailToRegisterVoIPToken(error: SDKError) {
        delegate?.didFailRegisterTokens(error: error)
    }

    func didReceiveVoIPPush(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        // TODO: Implement in TASK-006A-06 (CallKit Integration)
        Logger.debug("VoIP push received, deferring to CallKit handler")
        completion()
    }

    func didInvalidateVoIPToken() {
        Logger.warning("VoIP token invalidated")
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for SDK callbacks
public protocol PushPlatformDelegate: AnyObject {
    /// Called when SDK successfully initializes with installation ID
    /// - Parameter installationID: Generated or retrieved installation ID
    func didInitialize(installationID: UUID)

    /// Called when tokens are successfully registered
    func didRegisterTokens()

    /// Called when token registration fails
    /// - Parameter error: Registration error
    func didFailRegisterTokens(error: SDKError)

    /// Called when notification is received in foreground
    /// - Parameters:
    ///   - notification: Notification data
    ///   - context: Notification context (foreground/background)
    func didReceiveNotification(_ notification: Notification, context: NotificationContext)

    /// Called when user opens notification
    /// - Parameters:
    ///   - notification: Notification data
    ///   - action: Action identifier (nil for default tap)
    func didOpenNotification(_ notification: Notification, action: String?)

    /// Called when VoIP push is received
    /// - Parameters:
    ///   - callID: Unique call identifier
    ///   - callerName: Caller display name
    ///   - metadata: Additional call metadata
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any])

    /// Called when APNs token is updated
    func didUpdateAPNsToken()

    /// Called when VoIP token is updated
    func didUpdateVoIPToken()
}

// MARK: - Models

/// Push notification data
public struct Notification {
    public let title: String?
    public let body: String?
    public let badge: Int?
    public let sound: String?
    public let customData: [String: Any]
    public let eventID: String?
    public let callID: String?
    public let receivedAt: Date

    public init(
        title: String? = nil,
        body: String? = nil,
        badge: Int? = nil,
        sound: String? = nil,
        customData: [String: Any] = [:],
        eventID: String? = nil,
        callID: String? = nil,
        receivedAt: Date = Date()
    ) {
        self.title = title
        self.body = body
        self.badge = badge
        self.sound = sound
        self.customData = customData
        self.eventID = eventID
        self.callID = callID
        self.receivedAt = receivedAt
    }
}

/// Notification context
public struct NotificationContext {
    public let isForeground: Bool
    public let timestamp: Date

    public init(isForeground: Bool, timestamp: Date = Date()) {
        self.isForeground = isForeground
        self.timestamp = timestamp
    }
}
