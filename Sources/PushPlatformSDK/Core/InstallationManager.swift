import Foundation

/// Manages Installation ID lifecycle: generation, storage, retrieval
class InstallationManager {
    static let shared = InstallationManager()

    private let secureStorage = SecureStorage()
    private var cachedInstallationID: UUID?

    private init() {}

    /// Initialize installation ID (generate if not exists)
    /// - Returns: Installation ID (existing or newly generated)
    /// - Throws: SDKError.keychainAccessDenied if Keychain access fails
    func initialize() throws -> UUID {
        // Check cache first
        if let cached = cachedInstallationID {
            Logger.debug("Installation ID retrieved from cache: \(cached.uuidString)")
            return cached
        }

        // Check Keychain
        if let existing = secureStorage.getInstallationID() {
            cachedInstallationID = existing
            Logger.info("Installation ID retrieved from Keychain: \(existing.uuidString)")
            return existing
        }

        // Generate new UUID
        let newID = UUID()

        // Save to Keychain
        guard secureStorage.saveInstallationID(newID) else {
            Logger.error("Failed to save Installation ID to Keychain")
            throw SDKError.keychainAccessDenied
        }

        cachedInstallationID = newID
        Logger.info("New Installation ID generated and saved: \(newID.uuidString)")

        return newID
    }

    /// Get current Installation ID
    /// - Returns: Installation ID if initialized, nil otherwise
    func getInstallationID() -> UUID? {
        return cachedInstallationID ?? secureStorage.getInstallationID()
    }

    /// Reset Installation ID (for testing only)
    func resetInstallationID() -> Bool {
        cachedInstallationID = nil
        return secureStorage.deleteInstallationID()
    }
}
