import Foundation

/// HTTP API Client for REST API v1
class APIClient {
    private let configuration = Configuration.shared
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Installation API

    /// Create or update installation
    /// - Parameters:
    ///   - installation: Installation data
    ///   - completion: Result callback
    func createInstallation(
        _ installation: Installation,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let apiKey = configuration.apiKey else {
            completion(.failure(.notConfigured))
            return
        }

        let url = URL(string: "\(configuration.apiBaseURL)/v1/installations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        do {
            request.httpBody = try JSONEncoder().encode(installation)
        } catch {
            completion(.failure(.networkError(underlying: error)))
            return
        }

        Logger.debug("POST /v1/installations: \(installation.installationID)")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.error("Installation creation failed: \(error.localizedDescription)")
                completion(.failure(.networkError(underlying: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(underlying: NSError(domain: "APIClient", code: -1))))
                return
            }

            Logger.debug("Installation response: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200, 201:
                completion(.success(()))
            case 400...499:
                let message = self.parseErrorMessage(from: data) ?? "Client error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            case 500...599:
                let message = self.parseErrorMessage(from: data) ?? "Server error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            default:
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: "Unknown error")))
            }
        }.resume()
    }

    /// Update installation with external user ID
    /// - Parameters:
    ///   - installationID: Installation UUID
    ///   - externalUserID: External user ID (nil to dissociate)
    ///   - completion: Result callback
    func updateInstallation(
        installationID: UUID,
        externalUserID: String?,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let apiKey = configuration.apiKey else {
            completion(.failure(.notConfigured))
            return
        }

        let url = URL(string: "\(configuration.apiBaseURL)/v1/installations/\(installationID.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let update = UserUpdate(externalUserID: externalUserID)

        do {
            request.httpBody = try JSONEncoder().encode(update)
        } catch {
            completion(.failure(.networkError(underlying: error)))
            return
        }

        Logger.debug("PATCH /v1/installations/\(installationID): external_user_id=\(externalUserID ?? "nil")")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.error("Installation update failed: \(error.localizedDescription)")
                completion(.failure(.networkError(underlying: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(underlying: NSError(domain: "APIClient", code: -1))))
                return
            }

            Logger.debug("Installation update response: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                completion(.success(()))
            case 400...499:
                let message = self.parseErrorMessage(from: data) ?? "Client error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            case 500...599:
                let message = self.parseErrorMessage(from: data) ?? "Server error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            default:
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: "Unknown error")))
            }
        }.resume()
    }

    // MARK: - Subscription API

    /// Create or update subscription
    /// - Parameters:
    ///   - installationID: Installation UUID
    ///   - subscription: Subscription data
    ///   - completion: Result callback
    func createSubscription(
        installationID: UUID,
        subscription: Subscription,
        completion: @escaping (Result<Void, SDKError>) -> Void
    ) {
        guard let apiKey = configuration.apiKey else {
            completion(.failure(.notConfigured))
            return
        }

        let url = URL(string: "\(configuration.apiBaseURL)/v1/installations/\(installationID.uuidString)/subscriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        do {
            request.httpBody = try JSONEncoder().encode(subscription)
        } catch {
            completion(.failure(.networkError(underlying: error)))
            return
        }

        Logger.debug("POST /v1/installations/\(installationID)/subscriptions: provider=\(subscription.provider)")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.error("Subscription creation failed: \(error.localizedDescription)")
                completion(.failure(.networkError(underlying: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(underlying: NSError(domain: "APIClient", code: -1))))
                return
            }

            Logger.debug("Subscription response: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200, 201:
                completion(.success(()))
            case 400...499:
                let message = self.parseErrorMessage(from: data) ?? "Client error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            case 500...599:
                let message = self.parseErrorMessage(from: data) ?? "Server error"
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: message)))
            default:
                completion(.failure(.apiError(statusCode: httpResponse.statusCode, message: "Unknown error")))
            }
        }.resume()
    }

    // MARK: - Error Parsing

    private func parseErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return nil
        }
        return message
    }
}
