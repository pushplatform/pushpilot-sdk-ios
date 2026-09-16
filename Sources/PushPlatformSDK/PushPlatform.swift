import Foundation

/// Main SDK façade - singleton instance for push platform integration
public class PushPlatform {
    /// Shared singleton instance
    public static let shared = PushPlatform()

    private let configuration = Configuration.shared
    private let installationManager = InstallationManager.shared
    private let tokenRegistry = TokenRegistry()
    private let deduplicationCache = DeduplicationCache()
    private var apnsTokenManager: APNsTokenManager?
    private var pushKitManager: PushKitManager?
    private var userManager: UserManager?
    private var notificationDelegate: NotificationDelegate?

    private init() {
        // Initialize API client
        let apiClient = APIClient()

        // Initialize APNs token manager
        apnsTokenManager = APNsTokenManager(tokenRegistry: tokenRegistry)
        apnsTokenManager?.delegate = self

        // Initialize PushKit manager
        pushKitManager = PushKitManager(tokenRegistry: tokenRegistry)
        pushKitManager?.delegate = self

        // Initialize user manager
        userManager = UserManager(apiClient: apiClient)

        // Initialize notification delegate
        if #available(iOS 10.0, *) {
            notificationDelegate = NotificationDelegate(deduplicationCache: deduplicationCache)
            notificationDelegate?.appDelegate = nil  // Set via delegate property
        }
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
        userManager?.login(userID: userID, completion: completion)
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
        userManager?.logout(completion: completion)
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

    // MARK: - Notification Handling

    /// Handle foreground notification (call from willPresent)
    /// - Parameters:
    ///   - notification: UNNotification from system
    ///   - completionHandler: Presentation options callback
    @available(iOS 10.0, *)
    public func handleForegroundNotification(
        _ notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        notificationDelegate?.userNotificationCenter(
            UNUserNotificationCenter.current(),
            willPresent: notification,
            withCompletionHandler: completionHandler
        )
    }

    /// Handle notification response (call from didReceive)
    /// - Parameters:
    ///   - response: UNNotificationResponse from system
    ///   - completionHandler: Completion callback
    @available(iOS 10.0, *)
    public func handleNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        notificationDelegate?.userNotificationCenter(
            UNUserNotificationCenter.current(),
            didReceive: response,
            withCompletionHandler: completionHandler
        )
    }

    // MARK: - Delegate

    /// Set delegate for SDK callbacks
    public weak var delegate: PushPlatformDelegate? {
        didSet {
            if #available(iOS 10.0, *) {
                notificationDelegate?.appDelegate = delegate
            }
        }
    }
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

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        Logger.info("Incoming call: \(callerName), call_id: \(callID)")
        delegate?.didReceiveIncomingCall(callID: callID, callerName: callerName, metadata: metadata)
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
    ///   - context: Notification context
    func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext)

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

// MARK: - Models (Public Aliases)

/// Push notification data (public alias for ParsedNotification)
public typealias Notification = ParsedNotification
