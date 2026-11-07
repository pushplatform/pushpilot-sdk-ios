import Foundation

/// Serializes registration per transport and retains tokens until an installation exists.
class TokenRegistry {
    private let apiClient: APIClient
    private let installationManager: InstallationManagerProtocol
    private let storage: SecureStorageProtocol
    private let reachability = Reachability()
    private struct Pending {
        let token: Data
        let environment: String
        let generation: UUID
        var attempt = 0
        var inFlight = false
    }
    private final class WeakDelegate {
        weak var value: TokenRegistryDelegate?
        init(_ value: TokenRegistryDelegate) { self.value = value }
    }
    private var pending: [String: Pending] = [:]
    private let subscriptionLock = NSLock()
    private var providerSubscriptionIDs: [String: String] = [:]
    var onProviderRegistered: ((String) -> Void)?
    private var registered: [String: String] = [:]
    private var inFlightProviders = Set<String>()
    private var delegates: [String: WeakDelegate] = [:]
    private var retries: [String: DispatchWorkItem] = [:]
    weak var delegate: TokenRegistryDelegate?
    var onSubscriptionID: ((String) -> Void)?

    init(apiClient: APIClient = APIClient(), installationManager: InstallationManagerProtocol = InstallationManager.shared, storage: SecureStorageProtocol = SecureStorage()) {
        self.apiClient = apiClient
        self.installationManager = installationManager
        self.storage = storage
        reachability.startMonitoring { [weak self] in self?.flushPendingRegistrations() }
    }

    deinit {
        reachability.stopMonitoring()
        retries.values.forEach { $0.cancel() }
    }

    func setDelegate(_ value: TokenRegistryDelegate, for provider: String) {
        delegates[provider] = WeakDelegate(value)
    }

    func delegate(for provider: String) -> TokenRegistryDelegate? {
        delegates[provider]?.value ?? delegate
    }

    func registerToken(_ token: Data, provider: String, environment: String) {
        onMain { [self] in
            if let previous = pending[provider], previous.token == token, previous.environment == environment {
                if !previous.inFlight { send(provider) }
                return
            }
            retries.removeValue(forKey: provider)?.cancel()
            pending[provider] = Pending(token: token, environment: environment, generation: UUID())
            send(provider)
        }
    }

    /// Called after installation registration and whenever connectivity is restored.
    func flushPendingRegistrations() {
        onMain { [self] in
            for provider in Array(pending.keys) {
                retries.removeValue(forKey: provider)?.cancel()
                if var value = pending[provider], !value.inFlight {
                    value.attempt = 0
                    pending[provider] = value
                    send(provider)
                }
            }
        }
    }

    var subscriptionID: String? { storage.getSubscriptionID() }
    func subscriptionID(for provider: String) -> String? {
        if provider == "apns" { return storage.getSubscriptionID() }
        subscriptionLock.lock()
        defer { subscriptionLock.unlock() }
        return providerSubscriptionIDs[provider]
    }

    private func send(_ provider: String) {
        guard Configuration.shared.isConfigured, let installationID = installationManager.getInstallationID(),
              var value = pending[provider], !value.inFlight, !inFlightProviders.contains(provider) else { return }
        let environment = value.environment.isEmpty ? (Configuration.shared.reportedEnvironment ?? "production") : value.environment
        let hexToken = value.token.map { String(format: "%02x", $0) }.joined()
        let fingerprint = "\(installationID):\(Configuration.shared.serverURL):\(environment):\(Configuration.shared.environment.rawValue):\(hexToken)"
        if registered[provider] == fingerprint {
            pending.removeValue(forKey: provider)
            return
        }
        inFlightProviders.insert(provider)
        value.inFlight = true
        pending[provider] = value
        let generation = value.generation
        let subscription = Subscription(provider: provider, environment: environment, token: hexToken,
                                        bundleID: Bundle.main.bundleIdentifier ?? "unknown",
                                        apnsSandbox: Configuration.shared.environment == .development)
        apiClient.createSubscription(installationID: installationID, subscription: subscription) { [weak self] result in
            self?.onMain {
                guard let self = self else { return }
                self.inFlightProviders.remove(provider)
                guard var latest = self.pending[provider] else { return }
                guard latest.generation == generation else { self.send(provider); return }
                latest.inFlight = false
                self.pending[provider] = latest
                switch result {
                case .success(let subscriptionID):
                    self.registered[provider] = fingerprint
                    self.pending.removeValue(forKey: provider)
                    if let subscriptionID {
                        self.subscriptionLock.lock()
                        self.providerSubscriptionIDs[provider] = subscriptionID
                        self.subscriptionLock.unlock()
                    }
                    if provider == "apns", let subscriptionID, self.storage.saveSubscriptionID(subscriptionID) {
                        self.onSubscriptionID?(subscriptionID)
                    }
                    self.onProviderRegistered?(provider)
                    self.delegate(for: provider)?.didRegisterToken(provider: provider)
                case .failure(let error):
                    if self.isRetryable(error), latest.attempt < 5 {
                        let delay = min(pow(2.0, Double(latest.attempt)), 30)
                        latest.attempt += 1
                        self.pending[provider] = latest
                        let work = DispatchWorkItem { [weak self] in
                            guard self?.pending[provider]?.generation == generation else { return }
                            self?.send(provider)
                        }
                        self.retries[provider] = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
                    } else {
                        // Keep the latest token for an explicit retry or network recovery.
                        self.delegate(for: provider)?.didFailToRegisterToken(provider: provider, error: error)
                    }
                }
            }
        }
    }

    private func isRetryable(_ error: SDKError) -> Bool {
        switch error {
        case .networkError, .notConfigured: return true
        case .apiError(let code, _): return code >= 500 || code == 429
        default: return false
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

protocol TokenRegistryDelegate: AnyObject {
    func didRegisterToken(provider: String)
    func didFailToRegisterToken(provider: String, error: SDKError)
}
