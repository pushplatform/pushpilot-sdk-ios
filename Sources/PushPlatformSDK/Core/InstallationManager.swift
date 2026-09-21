import Foundation

/// Protocol for Installation ID management
protocol InstallationManagerProtocol {
    func initialize() throws -> UUID
    func getInstallationID() -> UUID?
    func resetInstallationID() -> Bool
}

/// Manages Installation ID lifecycle: generation, storage, retrieval
class InstallationManager: InstallationManagerProtocol {
    static let shared = InstallationManager()

    private let lock = NSLock()
    private let secureStorage: SecureStorageProtocol
    private var cachedInstallationID: UUID?
    private var registeredInstallationID: UUID?
    private var registrationStarted = false

    private init(secureStorage: SecureStorageProtocol = SecureStorage()) {
        self.secureStorage = secureStorage
    }

    /// Create an InstallationManager with custom storage (for testing)
    static func makeForTesting(secureStorage: SecureStorageProtocol) -> InstallationManager {
        return InstallationManager(secureStorage: secureStorage)
    }

    /// Initialize installation ID (generate if not exists)
    /// - Returns: Installation ID (existing or newly generated)
    /// - Throws: SDKError.keychainAccessDenied if Keychain access fails
    func initialize() throws -> UUID {
        lock.lock()
        defer { lock.unlock() }
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
        lock.lock()
        defer { lock.unlock() }
        if registrationStarted { return registeredInstallationID }
        return cachedInstallationID ?? secureStorage.getInstallationID()
    }

    // Keep the legacy Keychain UUID stable as device_id across registration retries
    // and process restarts. The server ID is recovered by idempotent registration.
    func beginRegistration() {
        lock.lock()
        defer { lock.unlock() }
        registrationStarted = true
        registeredInstallationID = nil
    }

    func completeRegistration(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        registeredInstallationID = id
    }

    /// Reset Installation ID (for testing only)
    func resetInstallationID() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        cachedInstallationID = nil
        registeredInstallationID = nil
        registrationStarted = false
        return secureStorage.deleteInstallationID()
    }
}
