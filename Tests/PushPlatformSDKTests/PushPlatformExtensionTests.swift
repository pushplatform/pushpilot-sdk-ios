import XCTest
@testable import PushPlatformExtension

final class PushPlatformExtensionTests: XCTestCase {
    func testMainBundleIDStripsTheExtensionSuffix() {
        XCTAssertEqual(
            PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.app.PushPlatformNotificationService"),
            "com.example.app"
        )
        XCTAssertEqual(PushPlatformExtension.mainBundleID(extensionBundleID: "com.example.app"), "com.example.app")
    }

    func testReceiptRequestIsMissingWithoutAppGroupConfig() {
        let request = PushPlatformExtension.receiptRequest(
            userInfo: ["notification_id": "11111111-1111-1111-1111-111111111111"],
            extensionBundleID: "com.example.app.PushPlatformNotificationService"
        )
        XCTAssertNil(request)
    }
}
