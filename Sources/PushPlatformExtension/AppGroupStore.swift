import Foundation

/// Shares the API address and subscription id with the notification service extension.
public enum AppGroupStore {
    public static func identifier(bundleID: String) -> String {
        "group.\(bundleID).pushplatform"
    }

    public static func save(serverURL: String, applicationID: UUID, subscriptionID: String?) {
        guard let defaults = defaults() else { return }
        defaults.set(serverURL, forKey: "server_url")
        defaults.set(applicationID.uuidString.lowercased(), forKey: "application_id")
        if let subscriptionID, !subscriptionID.isEmpty {
            defaults.set(subscriptionID, forKey: "subscription_id")
        }
    }

    public static func saveSubscriptionID(_ subscriptionID: String) {
        defaults()?.set(subscriptionID, forKey: "subscription_id")
    }

    public static func saveRevision(_ revision: Int) {
        defaults()?.set(revision, forKey: "badge_revision")
    }

    public static func revision() -> Int? {
        guard let defaults = defaults(), defaults.object(forKey: "badge_revision") != nil else { return nil }
        return defaults.integer(forKey: "badge_revision")
    }

    private static func defaults() -> UserDefaults? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let group = Bundle.main.object(forInfoDictionaryKey: "PushPlatformAppGroup") as? String ?? identifier(bundleID: bundleID)
        return UserDefaults(suiteName: group)
    }
}
