import Foundation

/// Sends PUT /notifications/{id} when the user taps a notification. A tap that
/// arrives before initialize, or before the subscription id is known, waits here.
final class NotificationOpenReporter {
    private let apiClient: APIClient
    private let subscriptionID: () -> String?
    private let queue = DispatchQueue(label: "com.pushplatform.sdk.notification-opens")
    private let maxPending = 50
    private var pending: [String] = []
    private var applicationID: UUID?

    init(apiClient: APIClient = APIClient(), subscriptionID: @escaping () -> String?) {
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
            apiClient.reportOpen(notificationID: id, applicationID: applicationID, subscriptionID: subscriptionID) { [weak self] result in
                guard case .failure(let error) = result else { return }
                Logger.warning("Notification open was not recorded: \(error)")
                // Repeated opens are not counted twice, so a network failure is retried.
                if case .networkError = error {
                    self?.queue.async { self?.enqueue(id) }
                }
            }
        }
    }
}
