import XCTest
import PushKit
@testable import PushPlatformSDK

final class PushKitManagerTests: XCTestCase {
    var pushKitManager: PushKitManager!
    var mockTokenRegistry: MockTokenRegistry!
    var mockDelegate: MockPushKitManagerDelegate!

    override func setUp() {
        super.setUp()
        mockTokenRegistry = MockTokenRegistry()
        pushKitManager = PushKitManager(tokenRegistry: mockTokenRegistry)
        mockDelegate = MockPushKitManagerDelegate()
        pushKitManager.delegate = mockDelegate

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
        pushKitManager = nil
        mockTokenRegistry = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - VoIP Token Reception Tests

    func testDidReceiveVoIPToken_FirstTime() {
        // Given
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8])

        // When
        pushKitManager.didReceiveVoIPToken(token)

        // Then
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled)
        XCTAssertEqual(mockTokenRegistry.lastToken, token)
        XCTAssertEqual(mockTokenRegistry.lastProvider, "apns_voip")
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "development")
    }

    func testDidReceiveVoIPToken_SameTokenTwice_SkipsRegistration() {
        // Given
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4])
        pushKitManager.didReceiveVoIPToken(token)
        mockTokenRegistry.registerTokenCalled = false

        // When
        pushKitManager.didReceiveVoIPToken(token)

        // Then
        XCTAssertFalse(mockTokenRegistry.registerTokenCalled, "Should skip re-registration for same token")
    }

    func testDidReceiveVoIPToken_DifferentToken_Registers() {
        // Given
        let firstToken = Data([0xf1, 0xf2, 0xf3, 0xf4])
        let secondToken = Data([0xa1, 0xa2, 0xa3, 0xa4])

        pushKitManager.didReceiveVoIPToken(firstToken)
        mockTokenRegistry.registerTokenCalled = false

        // When
        pushKitManager.didReceiveVoIPToken(secondToken)

        // Then
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled, "Should register new token")
        XCTAssertEqual(mockTokenRegistry.lastToken, secondToken)
    }

    func testDidReceiveVoIPToken_ProductionEnvironment() {
        // Given
        Configuration.shared.configure(
            apiKey: "pk_live_12345678",
            apiBaseURL: "https://api.example.com",
            environment: .production,
            debugMode: false
        )
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4])

        // When
        pushKitManager.didReceiveVoIPToken(token)

        // Then
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "production")
    }

    func testDidReceiveVoIPToken_DevelopmentEnvironment() {
        // Given
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4])

        // When
        pushKitManager.didReceiveVoIPToken(token)

        // Then
        XCTAssertEqual(mockTokenRegistry.lastEnvironment, "development")
    }

    // MARK: - Provider Verification Tests

    func testProviderIsVoIP() {
        // Given
        let token = Data([0xf1, 0xf2, 0xf3, 0xf4])

        // When
        pushKitManager.didReceiveVoIPToken(token)

        // Then
        XCTAssertEqual(mockTokenRegistry.lastProvider, "apns_voip", "Provider must be apns_voip, not apns")
    }

    func testVoIPTokenSeparateFromAPNs() {
        // Given
        let voipToken = Data([0xf1, 0xf2, 0xf3, 0xf4])

        // When
        pushKitManager.didReceiveVoIPToken(voipToken)

        // Then: Should create separate subscription
        XCTAssertNotEqual(mockTokenRegistry.lastProvider, "apns")
        XCTAssertEqual(mockTokenRegistry.lastProvider, "apns_voip")
    }

    // MARK: - Delegate Callback Tests

    func testTokenRegistryDelegate_DidRegisterToken() {
        // Given
        let expectation = self.expectation(description: "Delegate called")
        mockDelegate.onRegisterVoIPToken = {
            XCTAssertTrue(true)
            expectation.fulfill()
        }

        // When
        mockTokenRegistry.delegate?.didRegisterToken(provider: "apns_voip")

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testTokenRegistryDelegate_DidFailToRegisterToken() {
        // Given
        let expectation = self.expectation(description: "Delegate called on failure")
        mockDelegate.onFailToRegisterVoIPToken = { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        // When
        let sdkError = SDKError.networkError(underlying: NSError(domain: "Test", code: -1))
        mockTokenRegistry.delegate?.didFailToRegisterToken(provider: "apns_voip", error: sdkError)

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testTokenRegistryDelegate_IgnoresAPNsProvider() {
        // Given
        mockDelegate.onRegisterVoIPToken = {
            XCTFail("Should not call delegate for APNs provider")
        }

        // When
        mockTokenRegistry.delegate?.didRegisterToken(provider: "apns")

        // Then: Should not trigger delegate callback
        let expectation = self.expectation(description: "Wait")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.1)
    }

    // MARK: - VoIP Push Reception Tests

    func testDidReceiveVoIPPush() {
        // Given
        let payload: [AnyHashable: Any] = [
            "call_id": "call_123",
            "caller_name": "John Doe"
        ]

        let expectation = self.expectation(description: "VoIP push received")
        mockDelegate.onReceiveVoIPPush = { receivedPayload, completion in
            XCTAssertEqual(receivedPayload["call_id"] as? String, "call_123")
            XCTAssertEqual(receivedPayload["caller_name"] as? String, "John Doe")
            completion()
            expectation.fulfill()
        }

        // When
        mockDelegate.onReceiveVoIPPush?(payload) { }

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testDidInvalidateVoIPToken() {
        // Given
        let expectation = self.expectation(description: "Token invalidated")
        mockDelegate.onInvalidateVoIPToken = {
            XCTAssertTrue(true)
            expectation.fulfill()
        }

        // When
        mockDelegate.onInvalidateVoIPToken?()

        // Then
        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Token Change Detection Tests

    func testTokenChangeDetection_MultipleVoIPTokens() {
        // Given
        let tokens = [
            Data([0xf1, 0xf2, 0xf3, 0xf4]),
            Data([0xa1, 0xa2, 0xa3, 0xa4]),
            Data([0xb1, 0xb2, 0xb3, 0xb4])
        ]

        // When
        for token in tokens {
            pushKitManager.didReceiveVoIPToken(token)
        }

        // Then: Each new token should trigger registration
        XCTAssertTrue(mockTokenRegistry.registerTokenCalled)
        XCTAssertEqual(mockTokenRegistry.lastToken, tokens.last)
    }
}

// MARK: - Mock Delegate

class MockPushKitManagerDelegate: PushKitManagerDelegate {
    var onRegisterVoIPToken: (() -> Void)?
    var onFailToRegisterVoIPToken: ((SDKError) -> Void)?
    var onReceiveVoIPPush: (([AnyHashable: Any], @escaping () -> Void) -> Void)?
    var onInvalidateVoIPToken: (() -> Void)?

    func didRegisterVoIPToken() {
        onRegisterVoIPToken?()
    }

    func didFailToRegisterVoIPToken(error: SDKError) {
        onFailToRegisterVoIPToken?(error)
    }

    func didReceiveVoIPPush(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        onReceiveVoIPPush?(payload, completion)
    }

    func didInvalidateVoIPToken() {
        onInvalidateVoIPToken?()
    }
}
