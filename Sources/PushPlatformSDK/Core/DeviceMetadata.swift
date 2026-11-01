import Foundation
import UIKit
import UserNotifications

internal enum DeviceMetadata {
    static var kind: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #elseif targetEnvironment(macCatalyst)
        return "unknown"
        #else
        if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac { return "unknown" }
        return "physical"
        #endif
    }

    static var model: String {
        var system = utsname()
        uname(&system)
        let machine = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        let known = ["iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max"]
        // Preserve the actual hardware identifier for newer devices instead of
        // guessing a marketing model from screen dimensions or OS version.
        return known[identifier] ?? identifier
    }

    static func permission(_ status: UNAuthorizationStatus) -> String {
        if #available(iOS 14.0, *), status == .ephemeral { return "ephemeral" }
        switch status {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "prompt"
        case .provisional: return "provisional"
        default: return "unknown"
        }
    }
}
