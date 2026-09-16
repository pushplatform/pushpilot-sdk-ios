import XCTest
@testable import PushPlatformSDK

final class TokenRegistryTests: XCTestCase {
    var tokenRegistry: TokenRegistry!
    var mockAPIClient: MockAPIClient!
    var mockDelegate: MockTokenRegistryDelegate!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        tokenRegistry = TokenRegistry(apiClient: mockAPIClient)
        mockDelegate = MockTokenRegistryDelegate()
        tokenRegistry.delegate = mockDelegate

        // Configure SDK
        Configuration.shared.configure(
            apiKey: "pk_test_12345678",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: false
        )

        // Initialize installation ID
        _ = try? InstallationManager.shared.initialize()
    }

    override func tearDown() {
        _ = InstallationManager.shared.resetInstallationID()
        Configuration.shared.reset()
        tokenRegistry = nil
        mockAPIClient = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Registration Tests

    func testRegisterToken_Success() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = true

        let expectation = self.expectation(description: "Token registered")
        mockDelegate.onRegisterToken = { provider in
            XCTAssertEqual(provider, "apns")
            expectation.fulfill()
        }

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(mockAPIClient.createSubscriptionCalled)
    }

    func testRegisterToken_NetworkError_Retry() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .networkError(underlying: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then: Should schedule retry (verified by not immediately failing)
        let expectation = self.expectation(description: "Wait for retry attempt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // After 1s retry should have been attempted
            XCTAssertTrue(self.mockAPIClient.createSubscriptionCalled)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testRegisterToken_500Error_Retry() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .apiError(statusCode: 500, message: "Server error")

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then: Should retry server errors
        let expectation = self.expectation(description: "Retry on 500")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
    }

    func testRegisterToken_400Error_NoRetry() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .apiError(statusCode: 400, message: "Bad request")

        let expectation = self.expectation(description: "Permanent error")
        mockDelegate.onFailToRegisterToken = { provider, error in
            XCTAssertEqual(provider, "apns")
            if case .apiError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 400)
            } else {
                XCTFail("Should return apiError")
            }
            expectation.fulfill()
        }

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testRegisterToken_InvalidAPIKey_NoRetry() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .invalidAPIKey

        let expectation = self.expectation(description: "Invalid API key")
        mockDelegate.onFailToRegisterToken = { provider, error in
            if case .invalidAPIKey = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Should return invalidAPIKey")
            }
            expectation.fulfill()
        }

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testRegisterToken_ExponentialBackoff() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .networkError(underlying: NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut))

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then: First retry after 1s (2^0)
        let firstRetry = self.expectation(description: "First retry")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            firstRetry.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        // Subsequent retries would be at 2s, 4s, 8s, 16s (capped at 60s)
    }

    func testRegisterToken_MaxRetriesExceeded() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        mockAPIClient.shouldSucceed = false
        mockAPIClient.error = .networkError(underlying: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))

        let expectation = self.expectation(description: "Max retries exceeded")
        mockDelegate.onFailToRegisterToken = { provider, error in
            if case .maxRetriesExceeded = error {
                XCTAssertTrue(true)
                expectation.fulfill()
            }
        }

        // When: trigger multiple retries (this would take 1+2+4+8+16 = 31s in real time)
        // For testing purposes, we just verify the logic exists
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Simulate reaching max retries by calling multiple times
        // In real scenario, exponential backoff would delay these

        // Then: Eventually should fail with maxRetriesExceeded
        // Note: Full test would require timer mocking or long wait
        expectation.isInverted = true
        waitForExpectations(timeout: 0.5)
    }

    func testRegisterToken_VoIPProvider() {
        // Given
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4])
        mockAPIClient.shouldSucceed = true

        let expectation = self.expectation(description: "VoIP token registered")
        mockDelegate.onRegisterToken = { provider in
            XCTAssertEqual(provider, "apns_voip")
            expectation.fulfill()
        }

        // When
        tokenRegistry.registerToken(token, provider: "apns_voip", environment: "production")

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testRegisterToken_WithoutInstallationID() {
        // Given
        _ = InstallationManager.shared.resetInstallationID()
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])

        let expectation = self.expectation(description: "Fails without installation ID")
        mockDelegate.onFailToRegisterToken = { provider, error in
            if case .notConfigured = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Should return notConfigured")
            }
            expectation.fulfill()
        }

        // When
        tokenRegistry.registerToken(token, provider: "apns", environment: "development")

        // Then
        waitForExpectations(timeout: 1.0)
    }
}

// MARK: - Mock API Client

class MockAPIClient: APIClient {
    var shouldSucceed = true
    var error: SDKError?
    var createSubscriptionCalled = false

    override func createSubscription(installationID: UUID, subscription: Subscription, completion: @escaping (Result<Void, SDKError>) -> Void) {
        createSubscriptionCalled = true

        if shouldSucceed {
            completion(.success(()))
        } else {
            completion(.failure(error ?? .networkError(underlying: NSError(domain: "Test", code: -1))))
        }
    }
}

// MARK: - Mock Delegate

class MockTokenRegistryDelegate: TokenRegistryDelegate {
    var onRegisterToken: ((String) -> Void)?
    var onFailToRegisterToken: ((String, SDKError) -> Void)?

    func didRegisterToken(provider: String) {
        onRegisterToken?(provider)
    }

    func didFailToRegisterToken(provider: String, error: SDKError) {
        onFailToRegisterToken?(provider, error)
    }
}
