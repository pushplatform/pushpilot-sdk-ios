import Foundation

/// Manages user login/logout and external user ID association
class UserManager {
    private let apiClient: APIClient
    private let installationManager: InstallationManager
    private var retryAttempt = 0
    private let maxRetries = 5

    init(apiClient: APIClient, installationManager: InstallationManager = .shared) {
        self.apiClient = apiClient
        self.installationManager = installationManager
    }

    // MARK: - Login

    /// Associate installation with external user ID
    /// - Parameters:
    ///   - userID: External user identifier
    ///   - completion: Result callback
    func login(userID: String, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let installationID = installationManager.getInstallationID() else {
            Logger.error("Cannot login: installation ID not initialized")
            completion(.failure(.notConfigured))
            return
        }

        Logger.info("User login: external_user_id=\(userID)")
        retryAttempt = 0
        updateUser(installationID: installationID, externalUserID: userID, completion: completion)
    }

    // MARK: - Logout

    /// Dissociate user from installation
    /// - Parameter completion: Result callback
    func logout(completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let installationID = installationManager.getInstallationID() else {
            Logger.error("Cannot logout: installation ID not initialized")
            completion(.failure(.notConfigured))
            return
        }

        Logger.info("User logout")
        retryAttempt = 0
        updateUser(installationID: installationID, externalUserID: nil, completion: completion)
    }

    // MARK: - Private

    private func updateUser(
        installationID: UUID,
        externalUserID: String?,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        apiClient.updateInstallation(installationID: installationID, externalUserID: externalUserID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                Logger.info("User update successful: external_user_id=\(externalUserID ?? "nil")")
                self.retryAttempt = 0
                completion(.success(()))

            case .failure(let error):
                if self.shouldRetry(error) {
                    self.scheduleRetry(installationID: installationID, externalUserID: externalUserID, completion: completion)
                } else {
                    Logger.error("User update failed permanently: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }

    private func shouldRetry(_ error: SDKError) -> Bool {
        switch error {
        case .networkError:
            return true
        case .apiError(let statusCode, _):
            // Retry on 5xx server errors and 429 rate limit
            return statusCode >= 500 || statusCode == 429
        default:
            return false
        }
    }

    private func scheduleRetry(
        installationID: UUID,
        externalUserID: String?,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard retryAttempt < maxRetries else {
            Logger.error("User update max retries exceeded")
            completion(.failure(.maxRetriesExceeded))
            return
        }

        let delay = min(pow(2.0, Double(retryAttempt)), 60.0)
        retryAttempt += 1

        Logger.debug("Retrying user update in \(delay)s (attempt \(retryAttempt)/\(maxRetries))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateUser(installationID: installationID, externalUserID: externalUserID, completion: completion)
        }
    }
}
