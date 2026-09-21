import Foundation

/// Manages user login/logout and external user ID association
class UserManager {
    private let apiClient: APIClient
    private let installationManager: InstallationManagerProtocol
    private var retryAttempt = 0
    private let maxRetries = 5

    init(apiClient: APIClient, installationManager: InstallationManagerProtocol = InstallationManager.shared) {
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
        performLogin(installationID: installationID, externalUserID: userID, completion: completion)
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
        performLogout(installationID: installationID, completion: completion)
    }

    // MARK: - Private

    private func performLogin(
        installationID: UUID,
        externalUserID: String,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        apiClient.loginUser(installationID: installationID, externalUserID: externalUserID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                Logger.info("Login successful: external_user_id=\(externalUserID)")
                self.retryAttempt = 0
                completion(.success(()))

            case .failure(let error):
                if self.shouldRetry(error) {
                    self.scheduleLoginRetry(installationID: installationID, externalUserID: externalUserID, completion: completion)
                } else {
                    Logger.error("Login failed permanently: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }

    private func performLogout(
        installationID: UUID,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        apiClient.logoutUser(installationID: installationID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                Logger.info("Logout successful")
                self.retryAttempt = 0
                completion(.success(()))

            case .failure(let error):
                if self.shouldRetry(error) {
                    self.scheduleLogoutRetry(installationID: installationID, completion: completion)
                } else {
                    Logger.error("Logout failed permanently: \(error)")
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

    private func scheduleLoginRetry(
        installationID: UUID,
        externalUserID: String,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard retryAttempt < maxRetries else {
            Logger.error("Login max retries exceeded")
            completion(.failure(.maxRetriesExceeded))
            return
        }

        let delay = min(pow(2.0, Double(retryAttempt)), 60.0)
        retryAttempt += 1

        Logger.debug("Retrying login in \(delay)s (attempt \(retryAttempt)/\(maxRetries))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.performLogin(installationID: installationID, externalUserID: externalUserID, completion: completion)
        }
    }

    private func scheduleLogoutRetry(
        installationID: UUID,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard retryAttempt < maxRetries else {
            Logger.error("Logout max retries exceeded")
            completion(.failure(.maxRetriesExceeded))
            return
        }

        let delay = min(pow(2.0, Double(retryAttempt)), 60.0)
        retryAttempt += 1

        Logger.debug("Retrying logout in \(delay)s (attempt \(retryAttempt)/\(maxRetries))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.performLogout(installationID: installationID, completion: completion)
        }
    }
}
