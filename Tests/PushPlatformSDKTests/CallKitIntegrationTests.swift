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

    // MARK: - Payload Validation Tests (These work in unit test - early returns)

    func testHandleIncomingVoIPPush_MissingCallID() {
        // Given
        let payload: [AnyHashable: Any] = [
            "caller_name": "John Doe"
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Should complete quickly (early return before CallKit)
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_MissingCallerName() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Should complete quickly (early return before CallKit)
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_InvalidCallIDFormat() {
        // Given
        let payload: [AnyHashable: Any] = [
            "call_id": "invalid-uuid-format",
            "caller_name": "John Doe"
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Should complete quickly (early return before CallKit)
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_EmptyPayload() {
        // Given
        let payload: [AnyHashable: Any] = [:]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Should complete quickly (early return before CallKit)
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_EmptyCallID() {
        // Given
        let payload: [AnyHashable: Any] = [
            "call_id": "",
            "caller_name": "Test"
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Empty string is invalid UUID, should reject quickly
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_WrongTypeCallID() {
        // Given: call_id is not a string
        let payload: [AnyHashable: Any] = [
            "call_id": 12345,  // Integer instead of string
            "caller_name": "Test"
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Type mismatch should cause early return
        waitForExpectations(timeout: 0.5)
    }

    func testHandleIncomingVoIPPush_WrongTypeCallerName() {
        // Given: caller_name is not a string
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID,
            "caller_name": 12345  // Integer instead of string
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: Type mismatch should cause early return
        waitForExpectations(timeout: 0.5)
    }

    // MARK: - Integration Tests (Note: Limited in simulator without CallKit entitlements)

    func testCallKitIntegration_HasDelegate() {
        // Verify that delegate can be set
        XCTAssertNotNil(callKitIntegration.delegate)
        XCTAssertTrue(callKitIntegration.delegate is MockCallKitIntegrationDelegate)
    }
}

// MARK: - Mock Delegate

class MockCallKitIntegrationDelegate: CallKitIntegrationDelegate {
    var onReceiveIncomingCall: ((String, String, [String: Any]) -> Void)?
    var callCount = 0
    var receivedCalls: [(callID: String, callerName: String, metadata: [String: Any])] = []

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        callCount += 1
        receivedCalls.append((callID, callerName, metadata))
        onReceiveIncomingCall?(callID, callerName, metadata)
    }
}
