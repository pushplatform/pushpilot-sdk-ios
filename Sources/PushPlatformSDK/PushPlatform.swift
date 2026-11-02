import Foundation
import UIKit
import UserNotifications

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
    private var applicationID: UUID?
    private var activityObserver: NSObjectProtocol?

    private init() {
        activityObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            RemoteNotificationIntegration.install()
            self?.refreshMetadata()
        }
        DispatchQueue.main.async { RemoteNotificationIntegration.install() }
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

    public struct InitializeOptions {
        public var applicationId: String
        public var url: String?
        public var environment: Environment?
        public var debugMode: Bool

        public init(applicationId: String, url: String? = nil, environment: Environment? = nil, debugMode: Bool = false) {
            self.applicationId = applicationId
            self.url = url
            self.environment = environment
            self.debugMode = debugMode
        }
    }

    private var didStart = false
    private var deviceToken: String?

    /// Initialize with an application id. The server address is https://api.pushpilot.ru and the registration omits environment.
    public func initialize(_ applicationId: String, completion: ((Result<UUID, SDKError>) -> Void)? = nil) {
        initialize(InitializeOptions(applicationId: applicationId), completion: completion)
    }

    /// Initialize with an application id and an optional server URL and environment.
    /// A URL without an environment registers the installation as development.
    public func initialize(_ options: InitializeOptions, completion: ((Result<UUID, SDKError>) -> Void)? = nil) {
        DispatchQueue.main.async {
            if self.didStart {
                completion?(.success(self.installationManager.getInstallationID() ?? UUID(uuidString: options.applicationId) ?? UUID()))
                return
            }
            guard let appID = UUID(uuidString: options.applicationId) else {
                completion?(.failure(.apiError(statusCode: 400, message: "applicationId must be a UUID")))
                return
            }
            self.didStart = true
            let reportedEnvironment: String?
            if let environment = options.environment {
                reportedEnvironment = environment.rawValue
            } else if options.url != nil {
                reportedEnvironment = Environment.development.rawValue
            } else {
                reportedEnvironment = nil
            }
            self.configuration.apply(
                baseURL: options.url ?? Configuration.defaultAPIBaseURL,
                reportedEnvironment: reportedEnvironment,
                debugMode: options.debugMode
            )
            RemoteNotificationIntegration.install()
            self.begin(applicationID: appID, reportedEnvironment: reportedEnvironment ?? "", completion: completion)
        }
    }

    private func begin(
        applicationID: UUID,
        reportedEnvironment: String,
        completion: ((Result<UUID, SDKError>) -> Void)?
    ) {
            self.installationManager.beginRegistration()
            self.applicationID = applicationID
            do {
                // The persisted UUID identifies the device, not the backend row.
                let deviceID = try self.installationManager.initialize()
                let request = InstallationRegistration(
                    applicationID: applicationID, deviceID: deviceID.uuidString,
                    environment: reportedEnvironment,
                    osVersion: UIDevice.current.systemVersion,
                    appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                    deviceModel: DeviceMetadata.model
                )
                APIClient().registerInstallation(request) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let id):
                            self.installationManager.completeRegistration(id)
                            self.delegate?.didInitialize(installationID: id)
                        case .failure(let error):
                            self.delegate?.didFailRegisterTokens(error: error)
                        }
                        completion?(result)
                    }
                }
            } catch {
                let sdkError = error as? SDKError ?? .keychainAccessDenied
                self.delegate?.didFailRegisterTokens(error: sdkError)
                completion?(.failure(sdkError))
            }
    }

    /// Refresh actual OS/device/permission metadata without changing the installation.
    public func refreshMetadata() {
        DispatchQueue.main.async {
            guard self.configuration.isConfigured, let appID = self.applicationID,
                  self.installationManager.getInstallationID() != nil,
                  let deviceID = try? self.installationManager.initialize() else { return }
            let request = InstallationRegistration(applicationID: appID, deviceID: deviceID.uuidString,
                environment: self.configuration.reportedEnvironment ?? "", osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
                deviceModel: DeviceMetadata.model)
            APIClient().registerInstallation(request) { result in
                if case .success(let id) = result { self.installationManager.completeRegistration(id) }
            }
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
        deviceToken = token.map { String(format: "%02x", $0) }.joined()
        if let deviceToken {
            delegate?.didUpdateDeviceToken(deviceToken)
        }
        apnsTokenManager?.didReceiveAPNsToken(token)
    }

    /// Latest APNs device token, once the system has issued it.
    public func getDeviceToken() -> String? {
        deviceToken
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

    /// Foreground notification. Call preventDefault() to hide the system banner.
    func notificationWillDisplay(_ event: NotificationDisplayEvent)

    /// Called when the APNs device token is available.
    func didUpdateDeviceToken(_ token: String)

    /// Called when APNs token is updated
    func didUpdateAPNsToken()

    /// Called when VoIP token is updated
    func didUpdateVoIPToken()
}

public extension PushPlatformDelegate {
    func notificationWillDisplay(_ event: NotificationDisplayEvent) {}
    func didUpdateDeviceToken(_ token: String) {}
}

/// Foreground notification the application can display itself.
public final class NotificationDisplayEvent {
    public let notification: Notification
    private(set) var prevented = false
    init(notification: Notification) { self.notification = notification }
    public func preventDefault() { prevented = true }
    public var isPrevented: Bool { prevented }
}

// MARK: - Models (Public Aliases)

/// Push notification data (public alias for ParsedNotification)
public typealias Notification = ParsedNotification
