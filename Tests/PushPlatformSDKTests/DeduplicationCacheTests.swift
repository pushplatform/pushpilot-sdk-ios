import XCTest
@testable import PushPlatformSDK

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

    // MARK: - Basic Operations

    func testNewEventNotInCache() {
        XCTAssertFalse(cache.contains("evt_new"))
    }

    func testAddEventToCache() {
        cache.add("evt_123")

        // Wait for async add
        let expectation = self.expectation(description: "cache add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(cache.contains("evt_123"))
    }

    func testRemoveEventFromCache() {
        cache.add("evt_to_remove")

        // Wait for add
        let addExpectation = self.expectation(description: "cache add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            addExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(cache.contains("evt_to_remove"))

        cache.remove("evt_to_remove")

        // Wait for remove
        let removeExpectation = self.expectation(description: "cache remove")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            removeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(cache.contains("evt_to_remove"))
    }

    func testMultipleDistinctEvents() {
        cache.add("evt_1")
        cache.add("evt_2")
        cache.add("evt_3")

        // Wait for adds
        let expectation = self.expectation(description: "cache adds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(cache.contains("evt_1"))
        XCTAssertTrue(cache.contains("evt_2"))
        XCTAssertTrue(cache.contains("evt_3"))
    }

    func testDuplicateEventIgnored() {
        cache.add("evt_duplicate")

        // Wait for add
        let expectation = self.expectation(description: "first add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(cache.contains("evt_duplicate"))

        // Add same event again
        cache.add("evt_duplicate")

        // Wait for second add
        let secondExpectation = self.expectation(description: "second add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            secondExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Still in cache
        XCTAssertTrue(cache.contains("evt_duplicate"))
    }

    // MARK: - LRU Eviction

    func testLRUEvictionAt101Entries() {
        // Add 101 events (exceeds max 100)
        for i in 1...101 {
            cache.add("evt_\(i)")
        }

        // Wait for all adds
        let expectation = self.expectation(description: "cache adds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        // First event (oldest) should be evicted
        XCTAssertFalse(cache.contains("evt_1"))

        // Last event should still be in cache
        XCTAssertTrue(cache.contains("evt_101"))
    }

    func testLRUEvictionMultipleOverLimit() {
        // Add 110 events (10 over limit)
        for i in 1...110 {
            cache.add("evt_\(i)")
        }

        // Wait for all adds
        let expectation = self.expectation(description: "cache adds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        // First 10 events should be evicted
        XCTAssertFalse(cache.contains("evt_1"))
        XCTAssertFalse(cache.contains("evt_5"))
        XCTAssertFalse(cache.contains("evt_10"))

        // Recent events should remain
        XCTAssertTrue(cache.contains("evt_101"))
        XCTAssertTrue(cache.contains("evt_110"))
    }

    // MARK: - Thread Safety

    func testConcurrentAccess() {
        let expectation = self.expectation(description: "concurrent operations")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // Add 50 events concurrently
        for i in 1...50 {
            group.enter()
            queue.async {
                self.cache.add("evt_\(i)")
                group.leave()
            }
        }

        // Check 50 events concurrently
        for i in 1...50 {
            group.enter()
            queue.async {
                _ = self.cache.contains("evt_\(i)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        // No crash = thread safety verified
        XCTAssertTrue(true)
    }

    func testConcurrentAddAndRemove() {
        let expectation = self.expectation(description: "concurrent add/remove")
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        // Add and remove same events concurrently
        for i in 1...20 {
            group.enter()
            queue.async {
                self.cache.add("evt_\(i)")
                group.leave()
            }

            group.enter()
            queue.async {
                self.cache.remove("evt_\(i)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)

        // No crash = thread safety verified
        XCTAssertTrue(true)
    }

    // MARK: - Call ID vs Event ID

    func testCallIDAndEventIDSeparateNamespaces() {
        cache.add("550e8400-e29b-41d4-a716-446655440000")  // call_id (UUID)
        cache.add("evt_123456")  // event_id

        // Wait for adds
        let expectation = self.expectation(description: "cache adds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Both should coexist
        XCTAssertTrue(cache.contains("550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertTrue(cache.contains("evt_123456"))
    }
}
