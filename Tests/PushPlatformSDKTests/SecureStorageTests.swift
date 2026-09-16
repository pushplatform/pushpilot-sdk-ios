import XCTest
@testable import PushPlatformSDK

final class SecureStorageTests: XCTestCase {
    var secureStorage: SecureStorageProtocol!

    override func setUp() {
        super.setUp()
        secureStorage = InMemoryStorage()
        // Clean up any existing test data
        _ = secureStorage.deleteInstallationID()
    }

    override func tearDown() {
        // Clean up after tests
        _ = secureStorage.deleteInstallationID()
        secureStorage = nil
        super.tearDown()
    }

    // MARK: - Installation ID Tests

    func testSaveAndRetrieveInstallationID() {
        // Given
        let testUUID = UUID()

        // When
        let saveResult = secureStorage.saveInstallationID(testUUID)
        let retrievedUUID = secureStorage.getInstallationID()

        // Then
        XCTAssertTrue(saveResult, "Should successfully save Installation ID")
        XCTAssertEqual(retrievedUUID, testUUID, "Retrieved UUID should match saved UUID")
    }

    func testGetInstallationID_WhenNotExists_ReturnsNil() {
        // Given: no installation ID saved

        // When
        let retrievedUUID = secureStorage.getInstallationID()

        // Then
        XCTAssertNil(retrievedUUID, "Should return nil when Installation ID not found")
    }

    func testDeleteInstallationID() {
        // Given
        let testUUID = UUID()
        _ = secureStorage.saveInstallationID(testUUID)

        // When
        let deleteResult = secureStorage.deleteInstallationID()
        let retrievedUUID = secureStorage.getInstallationID()

        // Then
        XCTAssertTrue(deleteResult, "Should successfully delete Installation ID")
        XCTAssertNil(retrievedUUID, "Should return nil after deletion")
    }

    func testDeleteInstallationID_WhenNotExists_ReturnsTrue() {
        // Given: no installation ID saved

        // When
        let deleteResult = secureStorage.deleteInstallationID()

        // Then
        XCTAssertTrue(deleteResult, "Should return true even when item not found")
    }

    func testOverwriteInstallationID() {
        // Given
        let firstUUID = UUID()
        let secondUUID = UUID()
        _ = secureStorage.saveInstallationID(firstUUID)

        // When
        let saveResult = secureStorage.saveInstallationID(secondUUID)
        let retrievedUUID = secureStorage.getInstallationID()

        // Then
        XCTAssertTrue(saveResult, "Should successfully overwrite Installation ID")
        XCTAssertEqual(retrievedUUID, secondUUID, "Should retrieve second UUID")
        XCTAssertNotEqual(retrievedUUID, firstUUID, "Should not retrieve first UUID")
    }

    func testInstallationIDPersistence() {
        // Given
        let testUUID = UUID()
        _ = secureStorage.saveInstallationID(testUUID)

        // When: create new storage instance
        let newSecureStorage = InMemoryStorage()
        let retrievedUUID = newSecureStorage.getInstallationID()

        // Then: InMemoryStorage doesn't persist across instances (expected behavior for test storage)
        XCTAssertNil(retrievedUUID, "InMemoryStorage should not persist across instances")

        // Verify original instance still has it
        XCTAssertEqual(secureStorage.getInstallationID(), testUUID)
    }

    func testMultipleSaveOperations() {
        // Given
        let uuids = [UUID(), UUID(), UUID()]

        // When
        for uuid in uuids {
            let saveResult = secureStorage.saveInstallationID(uuid)
            XCTAssertTrue(saveResult, "Should save UUID: \(uuid)")
        }

        // Then: last saved should be retrieved
        let retrievedUUID = secureStorage.getInstallationID()
        XCTAssertEqual(retrievedUUID, uuids.last, "Should retrieve last saved UUID")
    }

    func testConcurrentAccess() {
        // Given
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        let testUUID = UUID()

        // When: multiple threads accessing Keychain
        for _ in 0..<10 {
            DispatchQueue.global().async {
                _ = self.secureStorage.saveInstallationID(testUUID)
                let retrieved = self.secureStorage.getInstallationID()
                XCTAssertNotNil(retrieved, "Should retrieve UUID from any thread")
                expectation.fulfill()
            }
        }

        // Then
        waitForExpectations(timeout: 5.0)
    }

    func testUUIDStringFormat() {
        // Given
        let testUUID = UUID()
        _ = secureStorage.saveInstallationID(testUUID)

        // When
        let retrievedUUID = secureStorage.getInstallationID()

        // Then
        XCTAssertNotNil(retrievedUUID)
        XCTAssertEqual(retrievedUUID?.uuidString.count, 36, "UUID string should be 36 characters")
        XCTAssertTrue(retrievedUUID!.uuidString.contains("-"), "UUID string should contain hyphens")
    }
}
