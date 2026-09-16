import XCTest
@testable import PushPlatformSDK

final class APNsTokenManagerTests: XCTestCase {
    var tokenManager: APNsTokenManager!
    var mockTokenRegistry: MockTokenRegistry!
    var mockDelegate: MockAPNsTokenManagerDelegate!
    var mockInstallationManager: MockInstallationManager!

    override func setUp() {
        super.setUp()
        mockInstallationManager = MockInstallationManager()
        mockInstallationManager.installationID = UUID()
        mockTokenRegistry = MockTokenRegistry(installationManager: mockInstallationManager)
        tokenManager = APNsTokenManager(tokenRegistry: mockTokenRegistry)
        mockDelegate = MockAPNsTokenManagerDelegate()
        tokenManager.delegate = mockDelegate

        // Configure SDK
        Configuration.shared.configure(
            apiKey: "pk_test_12345678",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: false
        )
    }

    override func tearDown() {
        Configuration.shared.reset()
        tokenManager = nil
        mockTokenRegistry = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Token Reception Tests

    func testDidReceiveAPNsToken_FirstTime() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x01, 0x02])

        // When
        tokenManager.didReceiveAPNsToken(token)

        // Then
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled)
        XCTAssertEqual(mockTokenRegistry.lastToken, token)
        XCTAssertEqual(mockTokenRegistry.lastProvider, "apns")
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "development")
    }

    func testDidReceiveAPNsToken_SameTokenTwice_SkipsRegistration() {
        // Given
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])
        tokenManager.didReceiveAPNsToken(token)
        mockTokenRegistry.registerTokenCalled = false

        // When
        tokenManager.didReceiveAPNsToken(token)

        // Then
        XCTAssertFalse(mockTokenRegistry.registerTokenCalled, "Should skip re-registration for same token")
    }

    func testDidReceiveAPNsToken_DifferentToken_Registers() {
        // Given
        let firstToken = Data([0xa1, 0xb2, 0xc3, 0xd4])
        let secondToken = Data([0xe5, 0xf6, 0x07, 0x08])

        tokenManager.didReceiveAPNsToken(firstToken)
        mockTokenRegistry.registerTokenCalled = false

        // When
        tokenManager.didReceiveAPNsToken(secondToken)

        // Then
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled, "Should register new token")
        XCTAssertEqual(mockTokenRegistry.lastToken, secondToken)
    }

    func testDidReceiveAPNsToken_ProductionEnvironment() {
        // Given
        Configuration.shared.configure(
            apiKey: "pk_live_12345678",
            apiBaseURL: "https://api.example.com",
            environment: .production,
            debugMode: false
        )
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])

        // When
        tokenManager.didReceiveAPNsToken(token)

        // Then
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "production")
    }

    func testDidReceiveAPNsToken_DevelopmentEnvironment() {
        // Given
        Configuration.shared.configure(
            apiKey: "pk_test_12345678",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: false
        )
        let token = Data([0xa1, 0xb2, 0xc3, 0xd4])

        // When
        tokenManager.didReceiveAPNsToken(token)

        // Then
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "development")
    }

    // MARK: - Registration Failure Tests

    func testDidFailToRegisterAPNs() {
        // Given
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        let expectation = self.expectation(description: "Registration failed")
        mockDelegate.onFailToRegisterAPNsToken = { receivedError in
            XCTAssertNotNil(receivedError)
            expectation.fulfill()
        }

        // When
        tokenManager.didFailToRegisterAPNs(error)

        // Then
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Delegate Callback Tests

    func testTokenRegistryDelegate_DidRegisterToken() {
        // Given
        let expectation = self.expectation(description: "Delegate called")
        mockDelegate.onRegisterAPNsToken = {
            XCTAssertTrue(true)
            expectation.fulfill()
        }

        // When
        mockTokenRegistry.delegate?.didRegisterToken(provider: "apns")

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testTokenRegistryDelegate_DidFailToRegisterToken() {
        // Given
        let expectation = self.expectation(description: "Delegate called on failure")
        mockDelegate.onFailToRegisterAPNsToken = { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        // When
        let sdkError = SDKError.networkError(underlying: NSError(domain: "Test", code: -1))
        mockTokenRegistry.delegate?.didFailToRegisterToken(provider: "apns", error: sdkError)

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testTokenRegistryDelegate_IgnoresVoIPProvider() {
        // Given
        mockDelegate.onRegisterAPNsToken = {
            XCTFail("Should not call delegate for VoIP provider")
        }

        // When
        mockTokenRegistry.delegate?.didRegisterToken(provider: "apns_voip")

        // Then: Should not trigger delegate callback
        let expectation = self.expectation(description: "Wait")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)
    }

    // MARK: - Token Change Detection Tests

    func testTokenChangeDetection_MultipleTokens() {
        // Given
        let tokens = [
            Data([0xa1, 0xb2, 0xc3, 0xd4]),
            Data([0xe5, 0xf6, 0x07, 0x08]),
            Data([0x11, 0x22, 0x33, 0x44])
        ]

        // When
        for token in tokens {
            tokenManager.didReceiveAPNsToken(token)
        }

        // Then: Each new token should trigger registration
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled)
        XCTAssertEqual(mockTokenRegistry.lastToken, tokens.last)
    }
}

// MARK: - Mock Token Registry

class MockTokenRegistry: TokenRegistry {
    var registerTokenCalled = false
    var lastToken: Data?
    var lastProvider: String?
    var lastEnvironment: String?

    override init(apiClient: APIClient = APIClient(), installationManager: InstallationManagerProtocol) {
        super.init(apiClient: apiClient, installationManager: installationManager)
    }

    override func registerToken(_ token: Data, provider: String, environment: String) {
        registerTokenCalled = true
        lastToken = token
        lastProvider = provider
        lastEnvironment = environment
    }
}

// MARK: - Mock Delegate

class MockAPNsTokenManagerDelegate: APNsTokenManagerDelegate {
    var onRegisterAPNsToken: (() -> Void)?
    var onFailToRegisterAPNsToken: ((Error) -> Void)?

    func didRegisterAPNsToken() {
        onRegisterAPNsToken?()
    }

    func didFailToRegisterAPNsToken(error: Error) {
        onFailToRegisterAPNsToken?(error)
    }
}
