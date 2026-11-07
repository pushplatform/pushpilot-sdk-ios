import Foundation

/// Sends PUT /notifications/{id} when the user taps a notification. A tap that
/// arrives before initialize, or before the subscription id is known, waits here.
final class NotificationOpenReporter {
    enum Kind { case opened, received }
    private let kind: Kind
    private let apiClient: APIClient
    private let subscriptionID: () -> String?
    private let queue = DispatchQueue(label: "com.pushplatform.sdk.notification-opens")
    private let maxPending = 50
    private var pending: [String] = []
    private var applicationID: UUID?

    init(apiClient: APIClient = APIClient(), kind: Kind = .opened, subscriptionID: @escaping () -> String?) {
        self.kind = kind
        self.apiClient = apiClient
        self.subscriptionID = subscriptionID
    }

    func report(_ notificationID: String) {
        queue.async {
            self.enqueue(notificationID)
            self.send()
        }
    }

    func start(applicationID: UUID) {
        queue.async {
            self.applicationID = applicationID
            self.send()
        }
    }

    func flush() {
        queue.async { self.send() }
    }

    /// Notification ids not yet accepted by the server.
    var pendingIDs: [String] {
        queue.sync { pending }
    }

    private func enqueue(_ notificationID: String) {
        guard !notificationID.isEmpty, !pending.contains(notificationID) else { return }
        pending.append(notificationID)
        if pending.count > maxPending {
            pending.removeFirst(pending.count - maxPending)
        }
    }

    private func send() {
        guard !pending.isEmpty, let applicationID, Configuration.shared.isConfigured,
              let subscriptionID = subscriptionID() else { return }
        let ids = pending
        pending.removeAll()
        for id in ids {
            let finished: (Result<Void, SDKError>) -> Void = { [weak self] result in
                guard case .failure(let error) = result else { return }
                Logger.warning("Notification event was not recorded: \(error)")
                let retryable: Bool
                switch error {
                case .networkError: retryable = true
                case .apiError(let code, _): retryable = code == 429 || code >= 500
                default: retryable = false
                }
                if retryable { self?.queue.async { self?.enqueue(id) } }
            }
            switch kind {
            case .opened: apiClient.reportOpen(notificationID: id, applicationID: applicationID, subscriptionID: subscriptionID, completion: finished)
            case .received: apiClient.reportReceived(notificationID: id, applicationID: applicationID, subscriptionID: subscriptionID, completion: finished)
            }
        }
    }
}
