import XCTest
@testable import PushPlatformSDK

final class ForegroundBannerFallbackTests: XCTestCase {
    private func notification() -> ParsedNotification {
        ParsedNotification(title: "Hello", body: "Body", badge: nil, sound: nil, eventID: nil, callID: nil, customData: [:])
    }

    func testZeroDoesNotShowTheBanner() {
        let display = NotificationDisplayEvent(notification: notification())
        var calls = 0
        display.deferDecision()
        XCTAssertTrue(display.takeDeferred { _ in calls += 1 })
        display.scheduleFallback(after: 0)
        let unexpected = expectation(description: "fallback stays idle")
        unexpected.isInverted = true
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            if calls > 0 { unexpected.fulfill() }
        }
        wait(for: [unexpected], timeout: 0.15)
        XCTAssertEqual(calls, 0)
    }

    func testPositiveFallbackShowsTheBannerWhenFinishIsNotCalled() {
        let display = NotificationDisplayEvent(notification: notification())
        let shown = expectation(description: "system banner")
        display.deferDecision()
        XCTAssertTrue(display.takeDeferred { prevented in
            XCTAssertFalse(prevented)
            shown.fulfill()
        })
        display.scheduleFallback(after: 0.05)
        wait(for: [shown], timeout: 1)
    }

    func testPreventDefaultBeforeTheFallbackHidesTheBanner() {
        let display = NotificationDisplayEvent(notification: notification())
        let hidden = expectation(description: "banner hidden")
        display.deferDecision()
        display.preventDefault()
        XCTAssertTrue(display.takeDeferred { prevented in
            XCTAssertTrue(prevented)
            hidden.fulfill()
        })
        display.scheduleFallback(after: 0.05)
        wait(for: [hidden], timeout: 1)
    }

    func testFinishBeforeTheFallbackDecidesOnce() {
        let display = NotificationDisplayEvent(notification: notification())
        var calls = 0
        display.deferDecision()
        XCTAssertTrue(display.takeDeferred { prevented in
            XCTAssertFalse(prevented)
            calls += 1
        })
        display.finish()
        display.scheduleFallback(after: 0.05)
        let unexpected = expectation(description: "timer does not decide again")
        unexpected.isInverted = true
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.12) {
            if calls != 1 { unexpected.fulfill() }
        }
        wait(for: [unexpected], timeout: 0.25)
        XCTAssertEqual(calls, 1)
    }
}
