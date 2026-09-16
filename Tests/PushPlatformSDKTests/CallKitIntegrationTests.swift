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

    // MARK: - Payload Parsing Tests

    func testHandleIncomingVoIPPush_ValidPayload() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID,
            "caller_name": "John Doe"
        ]

        let expectation = self.expectation(description: "Call registered")
        mockDelegate.onReceiveIncomingCall = { receivedCallID, callerName, metadata in
            XCTAssertEqual(receivedCallID, callID)
            XCTAssertEqual(callerName, "John Doe")
            expectation.fulfill()
        }

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) { }

        // Then
        waitForExpectations(timeout: 2.0)
    }

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

    func testHandleIncomingVoIPPush_WithMetadata() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID,
            "caller_name": "Jane Smith",
            "caller_avatar": "https://example.com/avatar.jpg",
            "call_type": "video"
        ]

        let expectation = self.expectation(description: "Call with metadata")
        mockDelegate.onReceiveIncomingCall = { _, _, metadata in
            XCTAssertEqual(metadata["caller_avatar"] as? String, "https://example.com/avatar.jpg")
            XCTAssertEqual(metadata["call_type"] as? String, "video")
            expectation.fulfill()
        }

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) { }

        // Then
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Deduplication Tests

    func testHandleIncomingVoIPPush_Duplicate_Ignored() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID,
            "caller_name": "John Doe"
        ]

        var callCount = 0
        mockDelegate.onReceiveIncomingCall = { _, _, _ in
            callCount += 1
        }

        let firstExpectation = self.expectation(description: "First call")
        let secondExpectation = self.expectation(description: "Second call ignored")

        // When: first call
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            firstExpectation.fulfill()
        }

        wait(for: [firstExpectation], timeout: 2.0)

        // When: duplicate call
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            secondExpectation.fulfill()
        }

        wait(for: [secondExpectation], timeout: 1.0)

        // Then: only first call should be registered
        XCTAssertEqual(callCount, 1, "Duplicate call should be ignored")
    }

    func testHandleIncomingVoIPPush_DifferentCallIDs() {
        // Given
        let callID1 = UUID().uuidString
        let callID2 = UUID().uuidString

        let payload1: [AnyHashable: Any] = [
            "call_id": callID1,
            "caller_name": "John Doe"
        ]

        let payload2: [AnyHashable: Any] = [
            "call_id": callID2,
            "caller_name": "Jane Smith"
        ]

        var callCount = 0
        mockDelegate.onReceiveIncomingCall = { _, _, _ in
            callCount += 1
        }

        let firstExpectation = self.expectation(description: "First call")
        let secondExpectation = self.expectation(description: "Second call")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload1) {
            firstExpectation.fulfill()
        }

        wait(for: [firstExpectation], timeout: 2.0)

        callKitIntegration.handleIncomingVoIPPush(payload: payload2) {
            secondExpectation.fulfill()
        }

        wait(for: [secondExpectation], timeout: 2.0)

        // Then: both calls should be registered
        XCTAssertEqual(callCount, 2, "Different call IDs should both register")
    }

    // MARK: - Completion Handler Tests

    func testHandleIncomingVoIPPush_CompletionCalledImmediately() {
        // Given
        let callID = UUID().uuidString
        let payload: [AnyHashable: Any] = [
            "call_id": callID,
            "caller_name": "John Doe"
        ]

        let expectation = self.expectation(description: "Completion called")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then: must complete within Apple's required timeframe
        waitForExpectations(timeout: 2.0)
    }

    func testHandleIncomingVoIPPush_CompletionCalledOnError() {
        // Given: invalid payload
        let payload: [AnyHashable: Any] = [:]

        let expectation = self.expectation(description: "Completion called on error")

        // When
        callKitIntegration.handleIncomingVoIPPush(payload: payload) {
            expectation.fulfill()
        }

        // Then
        waitForExpectations(timeout: 1.0)
    }
}

// MARK: - Deduplication Cache Tests

final class DeduplicationCacheTests: XCTestCase {
    var cache: DeduplicationCache!

    override func setUp() {
        super.setUp()
        cache = DeduplicationCache()
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    func testContains_NewEvent_ReturnsFalse() {
        // Given
        let eventID = "event_123"

        // When
        let contains = cache.contains(eventID)

        // Then
        XCTAssertFalse(contains)
    }

    func testAdd_ThenContains_ReturnsTrue() {
        // Given
        let eventID = "event_123"
        cache.add(eventID)

        // When
        let contains = cache.contains(eventID)

        // Then
        XCTAssertTrue(contains)
    }

    func testRemove_AfterAdd() {
        // Given
        let eventID = "event_123"
        cache.add(eventID)

        // When
        cache.remove(eventID)
        let contains = cache.contains(eventID)

        // Then
        XCTAssertFalse(contains)
    }

    func testConcurrentAccess() {
        // Given
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10

        // When: multiple threads accessing cache
        for i in 0..<10 {
            DispatchQueue.global().async {
                let eventID = "event_\(i)"
                self.cache.add(eventID)
                _ = self.cache.contains(eventID)
                expectation.fulfill()
            }
        }

        // Then
        waitForExpectations(timeout: 2.0)
    }
}

// MARK: - Mock Delegate

class MockCallKitIntegrationDelegate: CallKitIntegrationDelegate {
    var onReceiveIncomingCall: ((String, String, [String: Any]) -> Void)?

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        onReceiveIncomingCall?(callID, callerName, metadata)
    }
}
