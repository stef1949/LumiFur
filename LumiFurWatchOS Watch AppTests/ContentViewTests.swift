//
//  ContentViewTests.swift
//  LumiFurWatchOS Watch AppTests
//
//  Created by Stephan Ritchie on 7/3/25.
//

import Testing
import XCTest
@testable import LumiFurWatchOS_Watch_App

final class ContentViewTests: XCTestCase {
    // MARK: - String.spaced Extension
    func testSpacedSplitsCamelCase() {
        let original = "helloWorldTest"
        let spaced = original.spaced
        XCTAssertEqual(spaced, "Hello World Test")
    }

    func testSpacedKeepsSingleWord() {
        let original = "Device"
        let spaced = original.spaced
        XCTAssertEqual(spaced, "Device")
    }

    // MARK: - Item.displayName
    func testItemDisplayNameCases() {
        let expected = ["Device", "Faces", "Settings"]
        let actual = Item.allCases.map { $0.displayName }
        XCTAssertEqual(actual, expected)
    }

    // MARK: - SharedOptions.ProtoAction Helpers
    func testProtoActionRawValueEmoji() {
        let emoji = SharedOptions.ProtoAction.emoji("🙂")
        XCTAssertEqual(emoji.rawValue, "🙂")
        XCTAssertTrue(emoji.isEmoji)
    }

    func testProtoActionRawValueSymbol() {
        let symbol = SharedOptions.ProtoAction.symbol("star.fill")
        XCTAssertEqual(symbol.rawValue, "star.fill")
        XCTAssertFalse(symbol.isEmoji)
    }

    // MARK: - ConnectivityManager Default State
    @MainActor func testInitialConnectivityState() {
        let manager = WatchConnectivityManager.shared
        // Assuming default on init
        XCTAssertEqual(manager.connectionStatus, "Not Connected")
        XCTAssertFalse(manager.isReachable)
    }
}
