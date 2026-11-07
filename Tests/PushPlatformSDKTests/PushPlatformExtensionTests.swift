import XCTest
import UserNotifications
@testable import PushPlatformExtension

final class PushPlatformExtensionTests: XCTestCase {
    func testMainBundleIDStripsTheExtensionSuffix() {
        XCTAssertEqual(
            PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.app.PushPlatformNotificationService"),
            "com.example.app"
        )
        XCTAssertEqual(PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.app"), "com.example.app")
    }

    func testExtensionTargetAndCustomContainingApplicationNamesAreSupported() {
        XCTAssertEqual(PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.app.PushPlatformNotificationServiceExtension"), "com.example.app")
        XCTAssertEqual(PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.custom", applicationBundleID: "com.customer.app"), "com.customer.app")
    }

    func testConcurrentNotificationsCompleteIndependentlyAndOutOfOrder() {
        let group = AppGroupStore.identifier(bundleID: Bundle.main.bundleIdentifier!)
        let defaults = UserDefaults(suiteName: group)!
        defaults.set("https://extension.test", forKey: "server_url")
        defaults.set(UUID().uuidString, forKey: "application_id")
        defaults.set(UUID().uuidString, forKey: "subscription_id")
        defer { defaults.removePersistentDomain(forName: group) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredReceiptProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let started = expectation(description: "both receipt requests started")
        started.expectedFulfillmentCount = 2
        DeferredReceiptProtocol.prepare { started.fulfill() }
        defer { DeferredReceiptProtocol.reset() }
        let first = UNMutableNotificationContent(), second = UNMutableNotificationContent()
        first.title = "first"; first.userInfo = ["notification_id": "first"]
        second.title = "second"; second.userInfo = ["notification_id": "second"]
        let firstDone = expectation(description: "first delivered once"), secondDone = expectation(description: "second delivered once")
        let firstRequest = UNNotificationRequest(identifier: "first", content: first, trigger: nil)
        let secondRequest = UNNotificationRequest(identifier: "second", content: second, trigger: nil)
        PushPlatformExtension.didReceive(firstRequest, with: first, withContentHandler: { XCTAssertEqual($0.title, "first"); firstDone.fulfill() }, using: session)
        PushPlatformExtension.didReceive(secondRequest, with: second, withContentHandler: { XCTAssertEqual($0.title, "second"); secondDone.fulfill() }, using: session)
        wait(for: [started], timeout: 3)
        DeferredReceiptProtocol.complete("second")
        DeferredReceiptProtocol.complete("first")
        wait(for: [firstDone, secondDone], timeout: 3)
    }

    func testReceiptRequestIsMissingWithoutAppGroupConfig() {
        let request = PushPlatformExtension.receiptRequest(
            userInfo: ["notification_id": "11111111-1111-1111-1111-111111111111"],
            extensionBundleID: "com.example.app.PushPlatformNotificationService"
        )
        XCTAssertNil(request)
    }
}

private final class DeferredReceiptProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var pending: [String: DeferredReceiptProtocol] = [:]
    private static var started: (() -> Void)?
    static func prepare(_ started: @escaping () -> Void) { lock.lock(); pending = [:]; self.started = started; lock.unlock() }
    static func reset() { lock.lock(); pending = [:]; started = nil; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "extension.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        Self.pending[request.url!.lastPathComponent] = self
        let notify = Self.started
        Self.lock.unlock()
        notify?()
    }
    override func stopLoading() {}
    static func complete(_ id: String) {
        lock.lock(); let item = pending.removeValue(forKey: id); lock.unlock()
        guard let item else { return }
        item.client?.urlProtocol(item, didReceive: HTTPURLResponse(url: item.request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        item.client?.urlProtocol(item, didLoad: Data("{}".utf8))
        item.client?.urlProtocolDidFinishLoading(item)
    }
}
