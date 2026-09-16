import Foundation
import Security

/// Keychain wrapper for secure storage
class SecureStorage {
    private let service = "com.pushplatform.sdk"
    private let installationIDKey = "installation_id"

    // MARK: - Installation ID

    /// Retrieve Installation ID from Keychain
    /// - Returns: UUID if found, nil otherwise
    func getInstallationID() -> UUID? {
        guard let data = read(key: installationIDKey),
              let uuidString = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }

    /// Save Installation ID to Keychain
    /// - Parameter uuid: Installation ID to save
    /// - Returns: true if successful, false otherwise
    func saveInstallationID(_ uuid: UUID) -> Bool {
        let data = uuid.uuidString.data(using: .utf8)!
        return save(key: installationIDKey, data: data)
    }

    /// Delete Installation ID from Keychain
    /// - Returns: true if successful or not found, false on error
    func deleteInstallationID() -> Bool {
        return delete(key: installationIDKey)
    }

    // MARK: - Keychain Wrapper

    /// Save data to Keychain
    /// - Parameters:
    ///   - key: Account key
    ///   - data: Data to save
    /// - Returns: true if successful, false otherwise
    private func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Read data from Keychain
    /// - Parameter key: Account key
    /// - Returns: Data if found, nil otherwise
    private func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return data
    }

    /// Delete data from Keychain
    /// - Parameter key: Account key
    /// - Returns: true if successful or not found, false on error
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
