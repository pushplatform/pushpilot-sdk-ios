import Foundation
import Security
import os

/// Keychain wrapper for secure storage
class SecureStorage: SecureStorageProtocol {
    private let service: String
    private let installationIDKey = "installation_id"
    private static let statusLog = OSLog(subsystem: "com.pushplatform.sdk", category: "keychain")

    init(service: String = "com.pushplatform.sdk") {
        self.service = service
    }

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
            kSecAttrAccount as String: key
        ]
        let addAttributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let copyStatus = SecItemCopyMatching(query as CFDictionary, nil)
        logStatus("SecItemCopyMatching", copyStatus)

        switch copyStatus {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
            logStatus("SecItemUpdate", updateStatus)
            return updateStatus == errSecSuccess

        case errSecItemNotFound:
            let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
            logStatus("SecItemAdd", addStatus)
            if addStatus == errSecDuplicateItem {
                let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
                logStatus("SecItemUpdate after duplicate", updateStatus)
                return updateStatus == errSecSuccess
            }
            return addStatus == errSecSuccess

        default:
            return false
        }
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
        logStatus("SecItemCopyMatching", status)

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
        logStatus("SecItemDelete", status)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func logStatus(_ operation: String, _ status: OSStatus) {
        Logger.debug("Keychain \(operation) status: \(status)")
        os_log("%{public}@ status: %{public}d", log: Self.statusLog, type: .debug, operation, status)
    }
}
