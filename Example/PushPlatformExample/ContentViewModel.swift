import Foundation
import Combine
import PushPlatformSDK

class ContentViewModel: ObservableObject {
    @Published var installationID: UUID?
    @Published var apnsTokenStatus: TokenStatus = .pending
    @Published var voipTokenStatus: TokenStatus = .pending
    @Published var isLoggedIn: Bool = false
    @Published var userID: String?
    @Published var userIDInput: String = ""
    @Published var isLoading: Bool = false
    @Published var notifications: [NotificationItem] = []
    @Published var calls: [CallItem] = []
    @Published var showCopiedAlert: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()

        // Get initial installation ID
        if let id = PushPlatform.shared.getInstallationID() {
            installationID = id
        }
    }

    private func setupObservers() {
        // SDK initialization
        NotificationCenter.default.publisher(for: .sdkDidInitialize)
            .sink { [weak self] notification in
                if let id = notification.object as? UUID {
                    self?.installationID = id
                }
            }
            .store(in: &cancellables)

        // Token registration success
        NotificationCenter.default.publisher(for: .tokensDidRegister)
            .sink { [weak self] _ in
                self?.apnsTokenStatus = .registered
            }
            .store(in: &cancellables)

        // Token registration failure
        NotificationCenter.default.publisher(for: .tokensDidFail)
            .sink { [weak self] _ in
                self?.apnsTokenStatus = .failed
            }
            .store(in: &cancellables)

        // APNs token update
        NotificationCenter.default.publisher(for: .didUpdateAPNsToken)
            .sink { [weak self] _ in
                self?.apnsTokenStatus = .registered
            }
            .store(in: &cancellables)

        // VoIP token update
        NotificationCenter.default.publisher(for: .didUpdateVoIPToken)
            .sink { [weak self] _ in
                self?.voipTokenStatus = .registered
            }
            .store(in: &cancellables)

        // Notification received
        NotificationCenter.default.publisher(for: .didReceiveNotification)
            .sink { [weak self] notification in
                if let pushNotification = notification.object as? PushPlatformSDK.Notification {
                    self?.addNotification(pushNotification)
                }
            }
            .store(in: &cancellables)

        // Notification opened
        NotificationCenter.default.publisher(for: .didOpenNotification)
            .sink { [weak self] notification in
                if let dict = notification.object as? [String: Any],
                   let pushNotification = dict["notification"] as? PushPlatformSDK.Notification {
                    self?.addNotification(pushNotification)
                }
            }
            .store(in: &cancellables)

        // Incoming call
        NotificationCenter.default.publisher(for: .didReceiveIncomingCall)
            .sink { [weak self] notification in
                if let dict = notification.object as? [String: Any],
                   let callID = dict["callID"] as? String,
                   let callerName = dict["callerName"] as? String {
                    self?.addCall(callID: callID, callerName: callerName)
                }
            }
            .store(in: &cancellables)
    }

    func login() {
        guard !userIDInput.isEmpty else { return }

        isLoading = true
        PushPlatform.shared.login(userID: userIDInput) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.isLoggedIn = true
                    self?.userID = self?.userIDInput
                    self?.userIDInput = ""
                case .failure(let error):
                    self?.showError(message: "Login failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func logout() {
        isLoading = true
        PushPlatform.shared.logout { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.isLoggedIn = false
                    self?.userID = nil
                case .failure(let error):
                    self?.showError(message: "Logout failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func addNotification(_ notification: PushPlatformSDK.Notification) {
        let item = NotificationItem(
            title: notification.title ?? "Notification",
            body: notification.body,
            eventID: notification.eventID,
            timestamp: Date()
        )
        notifications.insert(item, at: 0)

        // Keep only last 10 notifications
        if notifications.count > 10 {
            notifications = Array(notifications.prefix(10))
        }
    }

    private func addCall(callID: String, callerName: String) {
        let item = CallItem(
            callID: callID,
            callerName: callerName,
            timestamp: Date()
        )
        calls.insert(item, at: 0)

        // Keep only last 5 calls
        if calls.count > 5 {
            calls = Array(calls.prefix(5))
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Models

struct NotificationItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String?
    let eventID: String?
    let timestamp: Date
}

struct CallItem: Identifiable {
    let id = UUID()
    let callID: String
    let callerName: String
    let timestamp: Date
}
