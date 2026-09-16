import Foundation

/// Protocol for secure storage
protocol SecureStorageProtocol {
    func getInstallationID() -> UUID?
    func saveInstallationID(_ uuid: UUID) -> Bool
    func deleteInstallationID() -> Bool
}

/// In-memory storage for testing
class InMemoryStorage: SecureStorageProtocol {
    private var storage: [String: Data] = [:]

    func getInstallationID() -> UUID? {
        guard let data = storage["installation_id"],
              let uuidString = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }

    func saveInstallationID(_ uuid: UUID) -> Bool {
        let data = uuid.uuidString.data(using: .utf8)!
        storage["installation_id"] = data
        return true
    }

    func deleteInstallationID() -> Bool {
        storage.removeValue(forKey: "installation_id")
        return true
    }
}
