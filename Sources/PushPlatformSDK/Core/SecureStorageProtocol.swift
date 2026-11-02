import Foundation

/// Protocol for secure storage
protocol SecureStorageProtocol {
    func getInstallationID() -> UUID?
    func saveInstallationID(_ uuid: UUID) -> Bool
    func deleteInstallationID() -> Bool
    func getSubscriptionID() -> String?
    func saveSubscriptionID(_ id: String) -> Bool
}

/// In-memory storage for testing. A lock keeps concurrent reads and writes exclusive.
class InMemoryStorage: SecureStorageProtocol {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    func getInstallationID() -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = storage["installation_id"],
              let uuidString = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }

    func saveInstallationID(_ uuid: UUID) -> Bool {
        let data = uuid.uuidString.data(using: .utf8)!
        lock.lock()
        defer { lock.unlock() }
        storage["installation_id"] = data
        return true
    }

    func deleteInstallationID() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: "installation_id")
        return true
    }

    func getSubscriptionID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage["subscription_id"].flatMap { String(data: $0, encoding: .utf8) }
    }

    func saveSubscriptionID(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        storage["subscription_id"] = Data(id.utf8)
        return true
    }
}
