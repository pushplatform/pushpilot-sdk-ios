import XCTest
@testable import PushPlatformSDK

final class LoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Logger.debugMode = false
    }

    override func tearDown() {
        Logger.debugMode = false
        super.tearDown()
    }

    // MARK: - Token Masking Tests

    func testTokenMasked_StandardToken() {
        // Given: 32-byte token (64 hex characters)
        let tokenData = Data([
            0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6, 0x01, 0x02,
            0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a,
            0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12,
            0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a
        ])

        // When
        let masked = Logger.tokenMasked(tokenData)

        // Then
        XCTAssertEqual(masked, "a1b2c3d4...", "Should show first 8 hex chars")
        XCTAssertFalse(masked.contains("e5f6"), "Should not contain full token")
    }

    func testTokenMasked_ShortToken() {
        // Given: short token (less than 4 bytes)
        let tokenData = Data([0xa1, 0xb2])

        // When
        let masked = Logger.tokenMasked(tokenData)

        // Then
        XCTAssertEqual(masked, "***", "Should mask short tokens completely")
    }

    func testTokenMasked_EmptyToken() {
        // Given
        let tokenData = Data()

        // When
        let masked = Logger.tokenMasked(tokenData)

        // Then
        XCTAssertEqual(masked, "***", "Should mask empty tokens")
    }

    func testTokenMasked_ExactlyFourBytes() {
        // Given: exactly 4 bytes (8 hex chars)
        let tokenData = Data([0xa1, 0xb2, 0xc3, 0xd4])

        // When
        let masked = Logger.tokenMasked(tokenData)

        // Then
        XCTAssertEqual(masked, "a1b2c3d4...", "Should show all chars for 4-byte token")
    }

    // MARK: - API Key Masking Tests

    func testAPIKeyMasked_StandardKey() {
        // Given
        let apiKey = "pk_test_1234567890abcdef"

        // When
        let masked = Logger.apiKeyMasked(apiKey)

        // Then
        XCTAssertEqual(masked, "pk_test_...", "Should show first 8 characters")
        XCTAssertFalse(masked.contains("1234567890"), "Should not contain full key")
    }

    func testAPIKeyMasked_ShortKey() {
        // Given
        let apiKey = "pk_123"

        // When
        let masked = Logger.apiKeyMasked(apiKey)

        // Then
        XCTAssertEqual(masked, "***", "Should mask short keys completely")
    }

    func testAPIKeyMasked_EmptyKey() {
        // Given
        let apiKey = ""

        // When
        let masked = Logger.apiKeyMasked(apiKey)

        // Then
        XCTAssertEqual(masked, "***", "Should mask empty keys")
    }

    func testAPIKeyMasked_ExactlyEightChars() {
        // Given
        let apiKey = "12345678"

        // When
        let masked = Logger.apiKeyMasked(apiKey)

        // Then
        XCTAssertEqual(masked, "***", "Should mask 8-char keys (boundary case)")
    }

    func testAPIKeyMasked_NineChars() {
        // Given
        let apiKey = "123456789"

        // When
        let masked = Logger.apiKeyMasked(apiKey)

        // Then
        XCTAssertEqual(masked, "12345678...", "Should show first 8 chars for 9+ char keys")
    }

    // MARK: - Debug Mode Tests

    func testDebugMode_DefaultIsFalse() {
        // Given: default state

        // Then
        XCTAssertFalse(Logger.debugMode, "Debug mode should be false by default")
    }

    func testDebugMode_CanBeEnabled() {
        // When
        Logger.debugMode = true

        // Then
        XCTAssertTrue(Logger.debugMode, "Should enable debug mode")
    }

    // MARK: - Integration Tests

    func testTokenMasking_PreventsSensitiveDataLeak() {
        // Given: realistic APNs token (32 bytes)
        let sensitiveToken = Data([
            0xde, 0xad, 0xbe, 0xef, 0xca, 0xfe, 0xba, 0xbe,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
            0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
        ])

        // When
        let masked = Logger.tokenMasked(sensitiveToken)

        // Then: should only show first 8 hex chars
        XCTAssertEqual(masked.count, 11, "Masked string should be 11 chars (8 + '...')")
        XCTAssertTrue(masked.hasPrefix("deadbeef"), "Should start with first 4 bytes")
        XCTAssertTrue(masked.hasSuffix("..."), "Should end with ellipsis")

        // Verify sensitive parts are NOT present
        XCTAssertFalse(masked.contains("cafebabe"))
        XCTAssertFalse(masked.contains("01234567"))
    }

    func testAPIKeyMasking_PreventsSensitiveDataLeak() {
        // Given
        let sensitiveKey = "pk_live_secret_1234567890abcdef"

        // When
        let masked = Logger.apiKeyMasked(sensitiveKey)

        // Then
        XCTAssertEqual(masked, "pk_live_...", "Should only show first 8 characters")
        XCTAssertFalse(masked.contains("secret"), "Should not leak secret part")
        XCTAssertFalse(masked.contains("1234567890"), "Should not leak numeric part")
    }
}
