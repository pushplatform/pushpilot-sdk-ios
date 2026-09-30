import XCTest
@testable import PushPlatformSDK

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        lastRequest = request
        return MockURLSessionDataTask {
            completionHandler(self.mockData, self.mockResponse, self.mockError)
        }
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let closure: () -> Void

    init(closure: @escaping () -> Void) {
        self.closure = closure
    }

    override func resume() {
        closure()
    }
}

// MARK: - APIClient Tests

final class APIClientTests: XCTestCase {
    var apiClient: APIClient!
    var mockSession: MockURLSession!
    var configuration: Configuration!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        apiClient = APIClient(session: mockSession)
        configuration = Configuration.shared
        configuration.configure(
            apiKey: "pk_test_12345678",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: false
        )
    }

    override func tearDown() {
        configuration.reset()
        apiClient = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Installation Creation Tests

    func testCreateInstallation_Success() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data("{\"id\":\"11111111-1111-4111-8111-111111111111\"}".utf8)

        let expectation = self.expectation(description: "Installation created")

        // When
        apiClient.registerInstallation(installation) { result in
            // Then
            switch result {
            case .success(let id):
                XCTAssertEqual(id.uuidString.lowercased(), "11111111-1111-4111-8111-111111111111")
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify request
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.url?.path, "/v1/installations")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer pk_test_12345678")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testRegistrationContractAndMissingServerID() throws {
        let appID = UUID()
        let deviceID = UUID().uuidString
        let request = InstallationRegistration(applicationID: appID, deviceID: deviceID,
            environment: "development", osVersion: "26.1", appVersion: "1.0", deviceModel: "iPhone")
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 201, httpVersion: nil, headerFields: nil)
        mockSession.mockData = Data("{}".utf8)
        var rejected = false
        apiClient.registerInstallation(request) { result in
            if case .failure = result { rejected = true }
        }
        XCTAssertTrue(rejected, "A 201 without a server ID must not complete initialization")
        let body = try XCTUnwrap(mockSession.lastRequest?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["application_id"] as? String, appID.uuidString)
        XCTAssertEqual(json["device_id"] as? String, deviceID)
        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["environment"] as? String, "development")
        XCTAssertNil(json["installation_id"])
    }

    func testCreateInstallation_NotConfigured() {
        // Given
        configuration.reset()
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        let expectation = self.expectation(description: "Not configured error")

        // When
        apiClient.registerInstallation(installation) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Should return notConfigured error")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCreateInstallation_NetworkError() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        let expectation = self.expectation(description: "Network error")

        // When
        apiClient.registerInstallation(installation) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail on network error")
            case .failure(let error):
                if case .networkError = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Should return networkError")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCreateInstallation_400Error() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let errorJSON = "{\"message\":\"Invalid installation data\"}".data(using: .utf8)
        mockSession.mockData = errorJSON

        let expectation = self.expectation(description: "API error")

        // When
        apiClient.registerInstallation(installation) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail with 400")
            case .failure(let error):
                if case .apiError(let statusCode, let message) = error {
                    XCTAssertEqual(statusCode, 400)
                    XCTAssertEqual(message, "Invalid installation data")
                } else {
                    XCTFail("Should return apiError")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCreateInstallation_500Error() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let errorJSON = "{\"message\":\"Internal server error\"}".data(using: .utf8)
        mockSession.mockData = errorJSON

        let expectation = self.expectation(description: "Server error")

        // When
        apiClient.registerInstallation(installation) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail with 500")
            case .failure(let error):
                if case .apiError(let statusCode, let message) = error {
                    XCTAssertEqual(statusCode, 500)
                    XCTAssertEqual(message, "Internal server error")
                } else {
                    XCTFail("Should return apiError")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Installation Update Tests

    func testUpdateInstallation_Login() {
        // Given
        let installationID = UUID()

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations/\(installationID)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data()

        let expectation = self.expectation(description: "User login")

        // When
        apiClient.loginUser(installationID: installationID, externalUserID: "user_123") { result in
            // Then
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify request
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.url?.path, "/v1/installations/\(installationID.uuidString)/login")
    }

    func testUpdateInstallation_Logout() {
        // Given
        let installationID = UUID()

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations/\(installationID)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data()

        let expectation = self.expectation(description: "User logout")

        // When
        apiClient.logoutUser(installationID: installationID) { result in
            // Then
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Subscription Creation Tests

    func testCreateSubscription_APNs() {
        // Given
        let installationID = UUID()
        let subscription = Subscription(
            provider: "apns",
            environment: "development",
            token: "a1b2c3d4e5f6",
            bundleID: "com.example.app"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations/\(installationID)/tokens")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data()

        let expectation = self.expectation(description: "APNs subscription created")

        // When
        apiClient.createSubscription(installationID: installationID, subscription: subscription) { result in
            // Then
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify request
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(mockSession.lastRequest?.url?.path.contains("/tokens") ?? false)
    }

    func testCreateSubscription_VoIP() {
        // Given
        let installationID = UUID()
        let subscription = Subscription(
            provider: "apns_voip",
            environment: "development",
            token: "f6e5d4c3b2a1",
            bundleID: "com.example.app"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations/\(installationID)/tokens")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockData = Data()

        let expectation = self.expectation(description: "VoIP subscription created")

        // When
        apiClient.createSubscription(installationID: installationID, subscription: subscription) { result in
            // Then
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCreateSubscription_NotConfigured() {
        // Given
        configuration.reset()
        let installationID = UUID()
        let subscription = Subscription(
            provider: "apns",
            environment: "development",
            token: "a1b2c3d4",
            bundleID: "com.example.app"
        )

        let expectation = self.expectation(description: "Not configured")

        // When
        apiClient.createSubscription(installationID: installationID, subscription: subscription) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Should return notConfigured error")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Request Format Tests

    func testRequestTimeout() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )

        let expectation = self.expectation(description: "Request timeout")

        // When
        apiClient.registerInstallation(installation) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertEqual(mockSession.lastRequest?.timeoutInterval, 30.0)
    }

    func testAuthorizationHeader() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )

        let expectation = self.expectation(description: "Authorization header")

        // When
        apiClient.registerInstallation(installation) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Then
        let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer pk_test_12345678")
        XCTAssertTrue(authHeader?.hasPrefix("Bearer ") ?? false)
    }

    func testContentTypeHeader() {
        // Given
        let installation = InstallationRegistration(
            applicationID: UUID(),
            deviceID: UUID().uuidString,
            environment: "development",
            osVersion: "17.0",
            appVersion: "1.0.0",
            deviceModel: "iPhone"
        )

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.test.example/v1/installations")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )

        let expectation = self.expectation(description: "Content-Type header")

        // When
        apiClient.registerInstallation(installation) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - JSON Encoding Tests

    func testInstallationJSONEncoding() throws {
        // Given
        let installationID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let installation = Installation(
            installationID: installationID,
            osVersion: "17.0",
            appVersion: "1.0.0",
            sdkVersion: "1.0.0",
            locale: "en_US",
            timezone: "America/New_York"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(installation)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then
        XCTAssertEqual((json["installation_id"] as? String)?.lowercased(), "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["os_version"] as? String, "17.0")
        XCTAssertEqual(json["app_version"] as? String, "1.0.0")
        XCTAssertEqual(json["sdk_version"] as? String, "1.0.0")
        XCTAssertEqual(json["locale"] as? String, "en_US")
        XCTAssertEqual(json["timezone"] as? String, "America/New_York")
    }

    func testSubscriptionJSONEncoding() throws {
        // Given
        let subscription = Subscription(
            provider: "apns",
            environment: "production",
            token: "a1b2c3d4e5f6",
            bundleID: "com.example.app"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(subscription)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then
        XCTAssertEqual(json["provider"] as? String, "apns")
        XCTAssertEqual(json["environment"] as? String, "production")
        XCTAssertEqual(json["token"] as? String, "a1b2c3d4e5f6")
        XCTAssertEqual(json["bundle_id"] as? String, "com.example.app")
    }
}
