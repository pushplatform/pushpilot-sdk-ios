import Foundation
import XCTest
@testable import PushPlatformSDK

// MARK: - Mock PushPlatformDelegate

class MockPushPlatformDelegate: PushPlatformDelegate {
    var receivedNotifications: [(notification: ParsedNotification, context: NotificationContext)] = []
    var openedNotifications: [(notification: ParsedNotification, action: String?, context: NotificationContext)] = []
    var onDidInitialize: ((UUID) -> Void)?

    func didInitialize(installationID: UUID) {
        onDidInitialize?(installationID)
    }

    func didRegisterTokens() {}
    func didFailRegisterTokens(error: SDKError) {}

    func didReceiveNotification(_ notification: ParsedNotification, context: NotificationContext) {
        receivedNotifications.append((notification, context))
    }

    func didOpenNotification(_ notification: ParsedNotification, action: String?, context: NotificationContext) {
        openedNotifications.append((notification, action, context))
    }

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {}
    func didUpdateAPNsToken() {}
    func didUpdateVoIPToken() {}
}
