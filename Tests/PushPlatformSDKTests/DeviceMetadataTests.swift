import XCTest
import UserNotifications
@testable import PushPlatformSDK

final class DeviceMetadataTests: XCTestCase {
    func testSimulatorKindAndWireMetadataAreExplicit() throws {
        #if targetEnvironment(simulator)
        XCTAssertEqual(DeviceMetadata.kind, "simulator")
        XCTAssertEqual(Environment.automatic, .development)
        #endif
        var request = InstallationRegistration(applicationID: UUID(), deviceID: UUID().uuidString,
            environment: "production", osVersion: "26.1", appVersion: "2.0", deviceModel: "iPhone 11")
        request.notificationPermission = "granted"
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(body["device_kind"] as? String, DeviceMetadata.kind)
        XCTAssertEqual(body["locale"] as? String, Locale.current.identifier)
        XCTAssertEqual(body["timezone"] as? String, TimeZone.current.identifier)
        XCTAssertEqual(body["notification_permission"] as? String, "granted")
        XCTAssertEqual(body["device_model"] as? String, "iPhone 11")
        XCTAssertEqual(body["sdk_version"] as? String, "2.0.3")
    }

    func testPermissionStatesDoNotInventAuthorization() {
        XCTAssertEqual(DeviceMetadata.permission(.notDetermined), "prompt")
        XCTAssertEqual(DeviceMetadata.permission(.denied), "denied")
        XCTAssertEqual(DeviceMetadata.permission(.authorized), "granted")
        XCTAssertEqual(DeviceMetadata.permission(.provisional), "provisional")
        if #available(iOS 14.0, *) { XCTAssertEqual(DeviceMetadata.permission(.ephemeral), "ephemeral") }
    }

    func testAPNsSandboxIsTransportMetadataInsteadOfAnotherApp() throws {
        let sandbox = Subscription(provider: "apns", environment: "development", token: "controlled", bundleID: "com.pushpilot.controlled")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sandbox)) as? [String: Any])
        XCTAssertEqual(body["apns_sandbox"] as? Bool, true)
        let production = Subscription(provider: "apns", environment: "production", token: "controlled", bundleID: "com.pushpilot.controlled")
        XCTAssertFalse(production.apnsSandbox)
    }
}
