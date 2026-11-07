import Foundation

/// Serializes account changes so a late login/retry can never overwrite a newer logout.
class UserManager {
    private let apiClient: APIClient
    private let installationManager: InstallationManagerProtocol
    private struct Operation {
        let id = UUID()
        let userID: String?
        let metadata: [String: Any]?
        var completion: ((Result<Void, SDKError>) -> Void)?
        var attempt = 0
    }
    private var desired: Operation?
    private var inFlight = false
    private var inFlightID: UUID?
    private var retry: DispatchWorkItem?

    init(apiClient: APIClient, installationManager: InstallationManagerProtocol = InstallationManager.shared) {
        self.apiClient = apiClient
        self.installationManager = installationManager
    }

    func login(userID: String, metadata: [String: Any]? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        enqueue(userID: userID, metadata: metadata, completion: completion)
    }

    func logout(completion: @escaping (Result<Void, SDKError>) -> Void) {
        enqueue(userID: nil, metadata: nil, completion: completion)
    }

    private func enqueue(userID: String?, metadata: [String: Any]?, completion: @escaping (Result<Void, SDKError>) -> Void) {
        onMain { [self] in
            guard installationManager.getInstallationID() != nil else { completion(.failure(.notConfigured)); return }
            let previous = desired
            retry?.cancel()
            retry = nil
            desired = Operation(userID: userID, metadata: metadata, completion: completion)
            if previous?.id != inFlightID { previous?.completion?(.failure(.apiError(statusCode: 409, message: "Account operation superseded"))) }
            send()
        }
    }

    func retryPending() {
        onMain { [self] in
            guard !inFlight, var operation = desired else { return }
            retry?.cancel()
            operation.attempt = 0
            desired = operation
            send()
        }
    }

    private func send() {
        guard !inFlight, let operation = desired, let installationID = installationManager.getInstallationID() else { return }
        inFlight = true
        inFlightID = operation.id
        let finished: (Result<Void, SDKError>) -> Void = { [weak self] result in
            self?.onMain {
                guard let self else { return }
                self.inFlight = false
                self.inFlightID = nil
                guard var latest = self.desired, latest.id == operation.id else {
                    operation.completion?(.failure(.apiError(statusCode: 409, message: "Account operation superseded")))
                    self.send()
                    return
                }
                switch result {
                case .success:
                    self.desired = nil
                    latest.completion?(.success(()))
                case .failure(let error):
                    if self.isRetryable(error), latest.attempt < 5 {
                        let delay = pow(2.0, Double(latest.attempt))
                        latest.attempt += 1
                        self.desired = latest
                        let item = DispatchWorkItem { [weak self] in
                            guard self?.desired?.id == operation.id else { return }
                            self?.send()
                        }
                        self.retry = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
                    } else {
                        let callback = latest.completion
                        latest.completion = nil
                        self.desired = self.isRetryable(error) ? latest : nil
                        callback?(.failure(error))
                    }
                }
            }
        }
        if let userID = operation.userID {
            apiClient.loginUser(installationID: installationID, externalUserID: userID, metadata: operation.metadata, completion: finished)
        } else { apiClient.logoutUser(installationID: installationID, completion: finished) }
    }

    private func isRetryable(_ error: SDKError) -> Bool {
        switch error {
        case .networkError: return true
        case .apiError(let status, _): return status >= 500 || status == 429
        default: return false
        }
    }
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
