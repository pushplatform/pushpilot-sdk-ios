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
    private let openReporter = NotificationOpenReporter(subscriptionID: { SecureStorage().getSubscriptionID() })
    private let receivedReporter = NotificationOpenReporter(kind: .received, subscriptionID: { SecureStorage().getSubscriptionID() })
    private lazy var voipReceivedReporter = NotificationOpenReporter(kind: .received, subscriptionID: { [weak self] in self?.tokenRegistry.subscriptionID(for: "apns_voip") })
    private var apnsTokenManager: APNsTokenManager?
    private var pushKitManager: PushKitManager?
    private var userManager: UserManager?
    private var notificationDelegate: NotificationDelegate?
    private var applicationID: UUID?
    private var activityObserver: NSObjectProtocol?
    private var initializationInProgress = false
    private var initializationCallbacks: [((Result<UUID, SDKError>) -> Void)] = []
    private var pendingAPNsToken: Data?
    private var externalVoIPToken: Data?
    private var lastOptions: InitializeOptions?
    private let registrationReachability = Reachability()

    private init() {
        activityObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            RemoteNotificationIntegration.install()
            self?.refreshMetadata()
            self?.openReporter.flush()
            self?.receivedReporter.flush()
            self?.voipReceivedReporter.flush()
            self?.clearBadgeAndReportSession()
            self?.retryInitialization()
            self?.tokenRegistry.flushPendingRegistrations()
            self?.userManager?.retryPending()
        }
        // A tap that launched the app is delivered only to a delegate set during launch.
        if Thread.isMainThread {
            RemoteNotificationIntegration.install()
        } else {
            DispatchQueue.main.async { RemoteNotificationIntegration.install() }
        }
        // Initialize API client
        let apiClient = APIClient()
        tokenRegistry.onSubscriptionID = { [openReporter] id in
            AppGroupStore.saveSubscriptionID(id)
            openReporter.flush()
        }

        tokenRegistry.onProviderRegistered = { [weak self] _ in
            self?.receivedReporter.flush()
            self?.voipReceivedReporter.flush()
        }

        // Initialize APNs token manager
        apnsTokenManager = APNsTokenManager(tokenRegistry: tokenRegistry)
        apnsTokenManager?.delegate = self

        // PushKit is opt-in. Applications with CallKit/CallKeep keep their own registry.
        registrationReachability.startMonitoring { [weak self] in self?.retryInitialization(); self?.userManager?.retryPending() }

        tokenRegistry.setDelegate(self, for: "apns_voip")

        // Initialize user manager
        userManager = UserManager(apiClient: apiClient)

        // Initialize notification delegate
        if #available(iOS 10.0, *) {
            notificationDelegate = NotificationDelegate(deduplicationCache: deduplicationCache)
            notificationDelegate?.appDelegate = nil  // Set via delegate property
            notificationDelegate?.onOpen = { [openReporter] id in openReporter.report(id) }
            notificationDelegate?.onReceive = { [weak self] parsed in
                if let id = parsed.notificationID { self?.receivedReporter.report(id) }
                if let revision = parsed.badgeRevision { AppGroupStore.saveRevision(revision) }
            }
        }
    }

    public var serverURL: String { configuration.serverURL }
    public var isVoIPConfigured: Bool { pushKitManager != nil || externalVoIPToken != nil }

    // MARK: - Configuration

    public struct InitializeOptions {
        public var applicationId: String
        public var url: String?
        public var environment: Environment?
        public var debugMode: Bool
        /// Seconds before a deferred foreground banner is shown. Zero or less waits for finish() only.
        public var foregroundBannerFallback: TimeInterval

        public init(applicationId: String, url: String? = nil, environment: Environment? = nil, debugMode: Bool = false, foregroundBannerFallback: TimeInterval = 0) {
            self.applicationId = applicationId
            self.url = url
            self.environment = environment
            self.debugMode = debugMode
            self.foregroundBannerFallback = foregroundBannerFallback
        }
    }

    private var didStart = false
    private var deviceToken: String?

    /// Initialize with an application id. The server address is https://api.pushpilot.ru and the registration omits environment.
    public func initialize(_ applicationId: String, completion: ((Result<UUID, SDKError>) -> Void)? = nil) {
        initialize(InitializeOptions(applicationId: applicationId), completion: completion)
    }

    /// Initialize with an application UUID and options such as debugMode.
    /// Storage is always production unless an explicit legacy `environment` is passed.
    /// APNs/VoIP sandbox comes from the provisioning profile (`Environment.automatic`), not from `url`.
    public func initialize(_ options: InitializeOptions, completion: ((Result<UUID, SDKError>) -> Void)? = nil) {
        DispatchQueue.main.async {
            if let previous = self.lastOptions,
               previous.applicationId != options.applicationId || (previous.url ?? Configuration.defaultAPIBaseURL) != (options.url ?? Configuration.defaultAPIBaseURL) || previous.environment != options.environment {
                completion?(.failure(.apiError(statusCode: 409, message: "SDK is already configured for a different application or server")))
                return
            }
            if self.didStart, let id = self.installationManager.getInstallationID() {
                completion?(.success(id))
                return
            }
            guard let appID = UUID(uuidString: options.applicationId) else {
                completion?(.failure(.apiError(statusCode: 400, message: "applicationId must be a UUID")))
                return
            }
            guard options.foregroundBannerFallback.isFinite, options.foregroundBannerFallback >= 0 else {
                completion?(.failure(.apiError(statusCode: 400, message: "foregroundBannerFallback must be a non-negative number of seconds")))
                return
            }
            if let completion { self.initializationCallbacks.append(completion) }
            guard !self.initializationInProgress else { return }
            self.initializationInProgress = true
            self.lastOptions = options
            let reportedEnvironment = options.environment?.rawValue
            self.configuration.apply(
                baseURL: options.url ?? Configuration.defaultAPIBaseURL,
                reportedEnvironment: reportedEnvironment,
                debugMode: options.debugMode,
                foregroundBannerFallback: options.foregroundBannerFallback
            )
            RemoteNotificationIntegration.install()
            self.begin(applicationID: appID, reportedEnvironment: reportedEnvironment ?? "", completion: nil)
        }
    }

    private func begin(
        applicationID: UUID,
        reportedEnvironment: String,
        completion: ((Result<UUID, SDKError>) -> Void)?
    ) {
            self.installationManager.beginRegistration()
            self.applicationID = applicationID
            self.openReporter.start(applicationID: applicationID)
            self.receivedReporter.start(applicationID: applicationID)
            self.voipReceivedReporter.start(applicationID: applicationID)
            AppGroupStore.save(serverURL: self.configuration.serverURL, applicationID: applicationID, subscriptionID: SecureStorage().getSubscriptionID())
            self.clearBadgeAndReportSession()
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
                            self.didStart = true
                            if let token = self.pendingAPNsToken { self.apnsTokenManager?.didReceiveAPNsToken(token) }
                            if let token = self.externalVoIPToken { self.registerExternalVoIPToken(token) }
                            self.tokenRegistry.flushPendingRegistrations()
                            self.delegate?.didInitialize(installationID: id)
                        case .failure(let error):
                            self.delegate?.didFailRegisterTokens(error: error)
                        }
                        self.finishInitialization(result)
                    }
                }
            } catch {
                let sdkError = error as? SDKError ?? .keychainAccessDenied
                self.delegate?.didFailRegisterTokens(error: sdkError)
                self.finishInitialization(.failure(sdkError))
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

    private func finishInitialization(_ result: Result<UUID, SDKError>) {
        initializationInProgress = false
        let callbacks = initializationCallbacks
        initializationCallbacks.removeAll()
        callbacks.forEach { $0(result) }
    }

    private func retryInitialization() {
        guard !didStart, !initializationInProgress, let options = lastOptions else { return }
        initialize(options)
    }

    /// Register the token from the application's existing PKPushRegistry.
    /// This does not create a registry or a CallKit provider.
    public func registerVoIPToken(_ token: Data) {
        DispatchQueue.main.async {
            self.externalVoIPToken = token
            self.registerExternalVoIPToken(token)
        }
    }

    private func registerExternalVoIPToken(_ token: Data) {
        tokenRegistry.registerToken(token, provider: "apns_voip", environment: configuration.reportedEnvironment ?? "")
    }

    /// Opt-in PushKit transport. Install during native application launch.
    /// The handler must report to the application's CallKit provider immediately,
    /// then invoke completion; it must never wait for JavaScript or Dart.
    public func startVoIPNotifications(handler: @escaping ([AnyHashable: Any], @escaping () -> Void) -> Void) {
        precondition(Thread.isMainThread, "Start PushKit on the main thread during application launch")
        guard pushKitManager == nil else { return }
        pushKitManager = PushKitManager(tokenRegistry: tokenRegistry) { [weak self] payload, completion in
            self?.handleVoIPNotification(payload)
            handler(payload) {
                if let id = payload["call_id"] as? String, let name = payload["caller_name"] as? String {
                    self?.delegate?.didReceiveIncomingCall(callID: id, callerName: name, metadata: payload as? [String: Any] ?? [:])
                }
                completion()
            }
        }
        pushKitManager?.delegate = self
    }

    // MARK: - Installation ID

    /// Get current installation ID (UUID)
    /// - Returns: Installation ID if SDK initialized, nil otherwise
    public func getInstallationID() -> UUID? {
        return installationManager.getInstallationID()
    }

    /// Alert subscription id issued by the server for this device's APNs token.
    /// Notification opens are reported with it.
    public func getSubscriptionID() -> String? {
        return tokenRegistry.subscriptionID
    }

    // MARK: - User Association

    /// Associate installation with external user ID
    /// - Parameters:
    ///   - userID: External user identifier from your system
    ///   - completion: Result callback
    public func login(
        userID: String,
        metadata: [String: Any]? = nil,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard configuration.isConfigured else {
            Logger.error("SDK not configured")
            completion(.failure(.notConfigured))
            return
        }

        Logger.info("User login requested: userID=\(userID)")
        userManager?.login(userID: userID, metadata: metadata, completion: completion)
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
        pendingAPNsToken = token
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

    /// A host-owned PushKit registry forwards its payload here for a device receipt.
    /// CallKit reporting and PushKit completion remain the native application's responsibility.
    @discardableResult
    public func handleVoIPNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let id = userInfo[NotificationParser.notificationIDKey] as? String else { return false }
        if Thread.isMainThread { voipReceivedReporter.report(id) }
        else { DispatchQueue.main.async { self.voipReceivedReporter.report(id) } }
        return true
    }

    /// Forward a delivered APNs payload from the application's background fetch callback.
    /// Returns false for notifications belonging to another provider. This does not start
    /// a JavaScript/Dart background runtime or replace the application's fetch completion.
    @discardableResult
    public func handleBackgroundNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard userInfo[NotificationParser.notificationIDKey] is String else { return false }
        if Thread.isMainThread { notificationDelegate?.handleBackground(userInfo) }
        else { DispatchQueue.main.async { self.notificationDelegate?.handleBackground(userInfo) } }
        return true
    }

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

    private func clearBadgeAndReportSession() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        guard let applicationID, let subscriptionID = SecureStorage().getSubscriptionID() else { return }
        let revision = AppGroupStore.revision()
        APIClient().resetBadge(applicationID: applicationID, subscriptionID: subscriptionID, revision: revision) { result in
            if case .failure(let error) = result { Logger.warning("Badge reset was not recorded: \(error)") }
        }
        APIClient().reportSession(applicationID: applicationID, subscriptionID: subscriptionID) { result in
            if case .failure(let error) = result { Logger.warning("Session was not recorded: \(error)") }
        }
    }

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
        delegate?.didRegisterTokens()
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
    private let lock = NSLock()
    private var prevented = false
    private var deferred = false
    private var finished = false
    private var decision: ((Bool) -> Void)?
    private var fallback: DispatchWorkItem?

    init(notification: Notification) { self.notification = notification }

    public func preventDefault() {
        lock.lock()
        prevented = true
        lock.unlock()
    }

    public var isPrevented: Bool {
        lock.lock()
        defer { lock.unlock() }
        return prevented
    }

    /// Hold the system banner until finish(). Sync delegates that never call this
    /// still decide the banner when notificationWillDisplay returns.
    public func deferDecision() {
        lock.lock()
        deferred = true
        lock.unlock()
    }

    public func finish() {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        let callback = decision
        let preventedNow = prevented
        let pending = fallback
        decision = nil
        fallback = nil
        lock.unlock()
        pending?.cancel()
        callback?(preventedNow)
    }

    /// Show the system banner if finish() has not run when the interval elapses. Zero does not schedule a fallback.
    func scheduleFallback(after seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.finish()
        }
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        fallback = work
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func takeDeferred(_ callback: @escaping (Bool) -> Void) -> Bool {
        lock.lock()
        guard deferred else {
            lock.unlock()
            return false
        }
        if finished {
            let preventedNow = prevented
            lock.unlock()
            callback(preventedNow)
            return true
        }
        decision = callback
        lock.unlock()
        return true
    }
}

// MARK: - Models (Public Aliases)

/// Push notification data (public alias for ParsedNotification)
public typealias Notification = ParsedNotification

// External PushKit registries still receive independent registration results.
extension PushPlatform: TokenRegistryDelegate {
    func didRegisterToken(provider: String) {
        if provider == "apns_voip" { delegate?.didUpdateVoIPToken() }
    }
    func didFailToRegisterToken(provider: String, error: SDKError) {
        delegate?.didFailRegisterTokens(error: error)
    }
}
