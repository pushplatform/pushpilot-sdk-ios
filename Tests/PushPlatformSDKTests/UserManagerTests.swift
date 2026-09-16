import XCTest
@testable import PushPlatformSDK

final class UserManagerTests: XCTestCase {

    var userManager: UserManager!
    var mockAPIClient: MockAPIClient!
    var mockInstallationManager: MockInstallationManager!

    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockInstallationManager = MockInstallationManager()
        userManager = UserManager(apiClient: mockAPIClient, installationManager: mockInstallationManager)
    }

    override func tearDown() {
        userManager = nil
        mockAPIClient = nil
        mockInstallationManager = nil
        super.tearDown()
    }

    // MARK: - Login Tests

    func testLoginSuccess() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .success(())

        let expectation = self.expectation(description: "login success")

        userManager.login(userID: "user_42") { result in
            switch result {
            case .success:
                XCTAssertTrue(true, "Login should succeed")
            case .failure(let error):
                XCTFail("Login should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify API client was called with correct parameters
        XCTAssertEqual(mockAPIClient.updateCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateInstallationID, installationID)
        XCTAssertEqual(mockAPIClient.lastUpdateExternalUserID, "user_42")
    }

    func testLoginNotConfigured() {
        // Installation ID not set
        mockInstallationManager.installationID = nil

        let expectation = self.expectation(description: "login not configured")

        userManager.login(userID: "user_42") { result in
            switch result {
            case .success:
                XCTFail("Login should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Expected notConfigured error, got \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // API client should not be called
        XCTAssertEqual(mockAPIClient.updateCallCount, 0)
    }

    func testLoginNetworkError() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .failure(.networkError(underlying: NSError(domain: "test", code: -1)))

        let expectation = self.expectation(description: "login network error")

        userManager.login(userID: "user_42") { result in
            switch result {
            case .success:
                XCTFail("Login should fail on network error")
            case .failure(let error):
                if case .networkError = error {
                    XCTAssertTrue(true)
                } else if case .maxRetriesExceeded = error {
                    XCTAssertTrue(true, "Max retries exceeded after network errors")
                } else {
                    XCTFail("Expected network error, got \(error)")
                }
            }
            expectation.fulfill()
        }

        // Wait longer for retries
        waitForExpectations(timeout: 35.0)

        // Should retry multiple times (5 retries + 1 initial = 6 total)
        XCTAssertGreaterThan(mockAPIClient.updateCallCount, 1, "Should retry on network error")
    }

    func testLoginClientError400NoRetry() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .failure(.apiError(statusCode: 400, message: "Bad request"))

        let expectation = self.expectation(description: "login 400 error")

        userManager.login(userID: "user_42") { result in
            switch result {
            case .success:
                XCTFail("Login should fail on 400 error")
            case .failure(let error):
                if case .apiError(let statusCode, _) = error {
                    XCTAssertEqual(statusCode, 400)
                } else {
                    XCTFail("Expected API error, got \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Should NOT retry on 400 error
        XCTAssertEqual(mockAPIClient.updateCallCount, 1, "Should not retry on 400 error")
    }

    func testLoginServerError500Retry() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .failure(.apiError(statusCode: 500, message: "Server error"))

        let expectation = self.expectation(description: "login 500 error")

        userManager.login(userID: "user_42") { result in
            switch result {
            case .success:
                XCTFail("Login should fail on 500 error")
            case .failure(let error):
                if case .maxRetriesExceeded = error {
                    XCTAssertTrue(true, "Max retries exceeded after 500 errors")
                } else if case .apiError(let statusCode, _) = error {
                    XCTAssertEqual(statusCode, 500)
                } else {
                    XCTFail("Expected API error or max retries, got \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 35.0)

        // Should retry on 500 error
        XCTAssertGreaterThan(mockAPIClient.updateCallCount, 1, "Should retry on 500 error")
    }

    // MARK: - Logout Tests

    func testLogoutSuccess() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .success(())

        let expectation = self.expectation(description: "logout success")

        userManager.logout { result in
            switch result {
            case .success:
                XCTAssertTrue(true, "Logout should succeed")
            case .failure(let error):
                XCTFail("Logout should not fail: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify API client was called with nil external_user_id
        XCTAssertEqual(mockAPIClient.updateCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateInstallationID, installationID)
        XCTAssertNil(mockAPIClient.lastUpdateExternalUserID, "Logout should set external_user_id to nil")
    }

    func testLogoutNotConfigured() {
        mockInstallationManager.installationID = nil

        let expectation = self.expectation(description: "logout not configured")

        userManager.logout { result in
            switch result {
            case .success:
                XCTFail("Logout should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Expected notConfigured error, got \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mockAPIClient.updateCallCount, 0)
    }

    func testLogoutNetworkErrorRetry() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .failure(.networkError(underlying: NSError(domain: "test", code: -1)))

        let expectation = self.expectation(description: "logout network error")

        userManager.logout { result in
            switch result {
            case .success:
                XCTFail("Logout should fail on network error")
            case .failure:
                XCTAssertTrue(true)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 35.0)

        // Should retry
        XCTAssertGreaterThan(mockAPIClient.updateCallCount, 1, "Should retry logout on network error")
    }

    // MARK: - Exponential Backoff Test

    func testExponentialBackoff() {
        let installationID = UUID()
        mockInstallationManager.installationID = installationID
        mockAPIClient.updateResult = .failure(.networkError(underlying: NSError(domain: "test", code: -1)))

        let expectation = self.expectation(description: "backoff timing")
        var timestamps: [Date] = []

        // Track when each attempt happens
        mockAPIClient.onUpdateCall = {
            timestamps.append(Date())
        }

        userManager.login(userID: "user_42") { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 35.0)

        // Verify exponential backoff (1s, 2s, 4s, 8s, 16s)
        // Allow some tolerance for execution time
        guard timestamps.count >= 3 else {
            XCTFail("Not enough retry attempts recorded")
            return
        }

        // Check that delays increase
        for i in 1..<min(timestamps.count, 4) {
            let delay = timestamps[i].timeIntervalSince(timestamps[i-1])
            let expectedDelay = pow(2.0, Double(i-1))

            // Allow 0.5s tolerance for execution overhead
            XCTAssertGreaterThan(delay, expectedDelay - 0.5, "Delay \(i) should be at least \(expectedDelay)s")
            XCTAssertLessThan(delay, expectedDelay + 2.0, "Delay \(i) should not exceed \(expectedDelay + 2)s")
        }
    }
}

// MARK: - Mock Classes

class MockInstallationManager: InstallationManager {
    var installationID: UUID?

    override func getInstallationID() -> UUID? {
        return installationID
    }
}
