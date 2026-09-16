import XCTest
@testable import PushPlatformSDK

final class InstallationManagerTests: XCTestCase {
    var installationManager: InstallationManager!
    var secureStorage: SecureStorage!

    override func setUp() {
        super.setUp()
        installationManager = InstallationManager.shared
        secureStorage = SecureStorage()
        // Clean up before each test
        _ = installationManager.resetInstallationID()
    }

    override func tearDown() {
        // Clean up after tests
        _ = installationManager.resetInstallationID()
        installationManager = nil
        secureStorage = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialize_GeneratesNewUUID_WhenNotExists() throws {
        // Given: no existing installation ID

        // When
        let installationID = try installationManager.initialize()

        // Then
        XCTAssertNotNil(installationID, "Should generate new Installation ID")

        // Verify it's saved to Keychain
        let retrievedFromKeychain = secureStorage.getInstallationID()
        XCTAssertEqual(retrievedFromKeychain, installationID, "Should save to Keychain")
    }

    func testInitialize_ReusesExistingUUID_WhenExists() throws {
        // Given: existing installation ID
        let existingUUID = UUID()
        _ = secureStorage.saveInstallationID(existingUUID)

        // When
        let installationID = try installationManager.initialize()

        // Then
        XCTAssertEqual(installationID, existingUUID, "Should reuse existing Installation ID")
    }

    func testInitialize_UsesCache_OnSecondCall() throws {
        // Given
        let firstID = try installationManager.initialize()

        // When: call initialize again
        let secondID = try installationManager.initialize()

        // Then
        XCTAssertEqual(firstID, secondID, "Should return same ID from cache")
    }

    func testGetInstallationID_ReturnsNil_BeforeInitialize() {
        // Given: not initialized

        // When
        let installationID = installationManager.getInstallationID()

        // Then
        XCTAssertNil(installationID, "Should return nil before initialization")
    }

    func testGetInstallationID_ReturnsID_AfterInitialize() throws {
        // Given
        let expectedID = try installationManager.initialize()

        // When
        let retrievedID = installationManager.getInstallationID()

        // Then
        XCTAssertEqual(retrievedID, expectedID, "Should return initialized ID")
    }

    func testResetInstallationID_ClearsCache() throws {
        // Given
        _ = try installationManager.initialize()

        // When
        let resetResult = installationManager.resetInstallationID()
        let retrievedID = installationManager.getInstallationID()

        // Then
        XCTAssertTrue(resetResult, "Reset should succeed")
        XCTAssertNil(retrievedID, "Should return nil after reset")
    }

    func testResetInstallationID_DeletesFromKeychain() throws {
        // Given
        _ = try installationManager.initialize()

        // When
        _ = installationManager.resetInstallationID()

        // Then
        let keychainValue = secureStorage.getInstallationID()
        XCTAssertNil(keychainValue, "Should delete from Keychain")
    }

    func testMultipleInitialize_ReturnsSameID() throws {
        // Given
        let firstID = try installationManager.initialize()

        // When: initialize multiple times
        let secondID = try installationManager.initialize()
        let thirdID = try installationManager.initialize()

        // Then
        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(secondID, thirdID)
    }

    func testInitialize_AfterReset_GeneratesNewID() throws {
        // Given
        let firstID = try installationManager.initialize()
        _ = installationManager.resetInstallationID()

        // When
        let secondID = try installationManager.initialize()

        // Then
        XCTAssertNotEqual(firstID, secondID, "Should generate new ID after reset")
    }

    func testConcurrentInitialize() throws {
        // Given
        let expectation = self.expectation(description: "Concurrent initialize")
        expectation.expectedFulfillmentCount = 10
        var ids: [UUID] = []
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let syncQueue = DispatchQueue(label: "test.sync")

        // When: multiple threads calling initialize
        for _ in 0..<10 {
            queue.async {
                do {
                    let id = try self.installationManager.initialize()
                    syncQueue.async {
                        ids.append(id)
                    }
                } catch {
                    XCTFail("Initialize should not throw: \(error)")
                }
                expectation.fulfill()
            }
        }

        // Then
        waitForExpectations(timeout: 5.0)

        // All IDs should be the same (from cache or Keychain)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(uniqueIDs.count, 1, "All concurrent calls should return same ID")
    }

    func testUUIDFormat() throws {
        // Given
        let installationID = try installationManager.initialize()

        // When
        let uuidString = installationID.uuidString

        // Then
        XCTAssertEqual(uuidString.count, 36, "UUID string should be 36 characters")
        XCTAssertTrue(uuidString.contains("-"), "UUID should contain hyphens")

        // Verify format: 8-4-4-4-12
        let components = uuidString.split(separator: "-")
        XCTAssertEqual(components.count, 5, "UUID should have 5 components")
        XCTAssertEqual(components[0].count, 8)
        XCTAssertEqual(components[1].count, 4)
        XCTAssertEqual(components[2].count, 4)
        XCTAssertEqual(components[3].count, 4)
        XCTAssertEqual(components[4].count, 12)
    }

    func testPersistenceAcrossInstances() throws {
        // Given
        let firstID = try installationManager.initialize()

        // When: simulate app restart by getting ID directly from Keychain
        let persistedID = secureStorage.getInstallationID()

        // Then
        XCTAssertEqual(persistedID, firstID, "Installation ID should persist")
    }
}
