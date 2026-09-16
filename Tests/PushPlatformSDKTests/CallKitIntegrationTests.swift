import XCTest
import CallKit
@testable import PushPlatformSDK

final class CallKitIntegrationTests: XCTestCase {
    var callKitIntegration: CallKitIntegration!
    var mockDelegate: MockCallKitIntegrationDelegate!

    override func setUp() {
        super.setUp()
        callKitIntegration = CallKitIntegration()
        mockDelegate = MockCallKitIntegrationDelegate()
        callKitIntegration.delegate = mockDelegate
    }

    override func tearDown() {
        callKitIntegration = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Payload Validation Tests (Unit Tests - No CallKit API calls)

    func testHandleIncomingVoIPPush_MissingCallID() {
        // Given
        let payload: [AnyHashable: Any] = [
            "caller_name": "John Doe"
        ]

        mockDelegate.onReceiveIncomingCall = { _, _, _ in
            XCTFail("Should not register call without call_id")
        }

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testHandleIncomingVoIPPush_MissingCallerName() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID
        ]

        mockDelegate.onReceiveIncomingCall = { _, _, _ in
            XCTFail("Should not register call without caller_name")
        }

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testHandleIncomingVoIPPush_InvalidCallIDFormat() {
        // Given
        let payload: [AnyHashable: Any] = [
            "call_id": "invalid-uuid-format",
            "caller_name": "John Doe"
        ]

        mockDelegate.onReceiveIncomingCall = { _, _, _ in
            XCTFail("Should not register call with invalid UUID")
        }

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
    }

    func testHandleIncomingVoIPPush_CompletionCalledOnError() {
        // Given: invalid payload
        let payload: [AnyHashable: Any] = [:]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
    }

    // NOTE: Tests that call actual CallKit APIs (reportNewIncomingCall) require:
    // - Device with CallKit entitlements
    // - Cannot run in unit test environment
    // - Should be moved to UI/integration tests
    //
    // Skipped tests:
    // - testHandleIncomingVoIPPush_ValidPayload (requires CallKit)
    // - testHandleIncomingVoIPPush_WithMetadata (requires CallKit)
    // - testHandleIncomingVoIPPush_Duplicate_Ignored (requires CallKit)
    // - testHandleIncomingVoIPPush_DifferentCallIDs (requires CallKit)
    // - testHandleIncomingVoIPPush_CompletionCalledImmediately (requires CallKit)
}

// MARK: - Mock Delegate

class MockCallKitIntegrationDelegate: CallKitIntegrationDelegate {
    var onReceiveIncomingCall: ((String, String, [String: Any]) -> Void)?

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        onReceiveIncomingCall?(callID, callerName, metadata)
    }
}
