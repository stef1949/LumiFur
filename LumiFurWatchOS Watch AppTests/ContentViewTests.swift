import XCTest
@testable import LumiFurWatchOS_Watch_App

final class WatchAppLogicTests: XCTestCase {
    private struct StubConnectivityError: LocalizedError, Sendable {
        var errorDescription: String? { "Counterpart unavailable" }
    }

    func testDestinationsStayShallowAndFocused() {
        XCTAssertEqual(WatchDestination.allCases, [.faces, .status, .settings])
        XCTAssertEqual(WatchDestination.faces.systemImage, "theatermasks.fill")
        XCTAssertEqual(WatchDestination.status.title, "Status")
    }

    func testFaceSelectionClampsToAvailableRange() {
        XCTAssertEqual(FaceSelection.clamped(-2, count: 10), 1)
        XCTAssertEqual(FaceSelection.clamped(4, count: 10), 4)
        XCTAssertEqual(FaceSelection.clamped(14, count: 10), 10)
        XCTAssertEqual(FaceSelection.clamped(1, count: 0), 0)
    }

    func testAdjacentFaceStopsAtBoundaries() {
        XCTAssertEqual(FaceSelection.adjacent(to: 2, offset: 1, count: 4), 3)
        XCTAssertEqual(FaceSelection.adjacent(to: 3, offset: -1, count: 4), 2)
        XCTAssertNil(FaceSelection.adjacent(to: 1, offset: -1, count: 4))
        XCTAssertNil(FaceSelection.adjacent(to: 4, offset: 1, count: 4))
    }

    func testWristFlickClassifierUsesDirectionThresholdAndCooldown() {
        var classifier = WristFlickClassifier(accelerationThreshold: 1.2, cooldown: 0.6)

        XCTAssertNil(classifier.classify(accelerationX: 1.19, at: 1.0))
        XCTAssertEqual(classifier.classify(accelerationX: -1.3, at: 1.0), .left)
        XCTAssertNil(classifier.classify(accelerationX: 1.4, at: 1.2))
        XCTAssertEqual(classifier.classify(accelerationX: 1.4, at: 1.7), .right)
    }

    func testControllerConnectionStateCapabilities() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
        XCTAssertFalse(ConnectionState.connected.isInProgress)
        XCTAssertTrue(ConnectionState.connecting.isInProgress)
        XCTAssertTrue(ConnectionState.reconnecting.isInProgress)
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
    }

    func testSharedFaceActionsExposeStableValues() {
        let emoji = SharedOptions.ProtoAction.emoji("🙂")
        let symbol = SharedOptions.ProtoAction.symbol("star.fill")

        XCTAssertEqual(emoji.rawValue, "🙂")
        XCTAssertTrue(emoji.isEmoji)
        XCTAssertEqual(symbol.rawValue, "star.fill")
        XCTAssertFalse(symbol.isEmoji)
    }

    func testConnectivityReplyCallbackCanArriveOffMainActor() async {
        let receivedStatus = await withCheckedContinuation { continuation in
            let handler = WatchConnectivityCallbackBridge.makeReplyHandler { reply in
                MainActor.assertIsolated()
                continuation.resume(returning: reply["status"] as? String)
            }

            Task.detached {
                handler(["status": "Snapshot received."])
            }
        }

        XCTAssertEqual(receivedStatus, "Snapshot received.")
    }

    func testConnectivityErrorCallbackCanArriveOffMainActor() async {
        let receivedDescription = await withCheckedContinuation { continuation in
            let handler = WatchConnectivityCallbackBridge.makeErrorHandler { description in
                MainActor.assertIsolated()
                continuation.resume(returning: description)
            }

            Task.detached {
                handler(StubConnectivityError())
            }
        }

        XCTAssertEqual(receivedDescription, "Counterpart unavailable")
    }
}
