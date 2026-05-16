import Foundation

// MARK: - OTA Response

/// A parsed OTA status payload emitted by the firmware.
struct AccessoryOTAResponse: Equatable, Sendable {
    let statusMessage: String
    let resetsProgress: Bool
}

// MARK: - AccessoryNotificationParser

/// Decodes BLE characteristic payloads into value-type domain models.
enum AccessoryNotificationParser {
    static func deviceInfo(from data: Data) -> DeviceInfo? {
        if let info = try? JSONDecoder().decode(DeviceInfo.self, from: data) {
            return info
        }

        guard
            let jsonString = String(data: data, encoding: .utf8),
            let jsonData = jsonString.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(DeviceInfo.self, from: jsonData)
    }

    static func selectedView(from data: Data) -> Int? {
        data.first.map(Int.init)
    }

    static func configuration(from data: Data) -> AccessoryConfiguration? {
        guard data.count >= 4 else { return nil }

        return AccessoryConfiguration(
            autoBrightness: data[0] == 1,
            accelerometerEnabled: data[1] == 1,
            sleepModeEnabled: data[2] == 1,
            auroraModeEnabled: data[3] == 1
        )
    }

    static func liveTemperatureCelsius(from data: Data) -> Double? {
        guard data.count >= MemoryLayout<Int16>.size else { return nil }

        let raw: Int16 = data.withUnsafeBytes { buffer in
            buffer.load(as: Int16.self)
        }

        return Double(Int16(littleEndian: raw)) / 10.0
    }

    static func brightness(from data: Data) -> UInt8? {
        data.first
    }

    static func lux(from data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        return UInt16(data[0]) | (UInt16(data[1]) << 8)
    }

    static func scrollText(from data: Data) -> String {
        let bytes = data.prefix { $0 != 0 }
        return String(bytes: bytes, encoding: .utf8)
            ?? String(bytes: bytes, encoding: .ascii)
            ?? ""
    }

    static func strobeState(from data: Data) -> StrobeState? {
        guard let settings = FWStrobeSettings.decode(from: data), let rgb = settings.rgb else {
            return nil
        }

        return StrobeState(enabled: settings.enabled, rgb: rgb, cycleMs: settings.speedMs)
    }

    static func otaResponse(from data: Data) -> AccessoryOTAResponse? {
        guard data.count == 2 else { return nil }

        let code = data[0]
        let detail = data[1]

        switch (code, detail) {
        case (0x01, 0x00):
            return AccessoryOTAResponse(statusMessage: "OTA Started", resetsProgress: false)
        case (0x03, 0x00):
            return AccessoryOTAResponse(statusMessage: "OTA Complete - Rebooting...", resetsProgress: false)
        case (0x04, 0x00):
            return AccessoryOTAResponse(statusMessage: "OTA Aborted", resetsProgress: true)
        case (0xFF, _):
            return AccessoryOTAResponse(statusMessage: "OTA Error \(detail)", resetsProgress: true)
        default:
            return AccessoryOTAResponse(statusMessage: "OTA Unknown Response", resetsProgress: false)
        }
    }
}

// MARK: - TemperatureHistoryAssembler

/// Reassembles streamed history packets on the BLE queue before crossing to the main actor.
struct TemperatureHistoryAssembler {
    enum Result: Sendable {
        case finished([TemperatureData])
        case failed(String)
    }

    private struct State {
        var totalChunks: Int = 0
        var receivedChunks: Int = 0
        var totalPoints: Int = 0
        var processedPoints: Int = 0
        var interval: TimeInterval = 60
        var oldestTimestamp: Date = .distantPast
        var points: [TemperatureData] = []
    }

    private let maxPoints: Int
    private var state: State?

    init(maxPoints: Int = 600) {
        self.maxPoints = maxPoints
    }

    var isDownloading: Bool {
        state != nil
    }

    mutating func reset() {
        state = nil
    }

    mutating func process(_ data: Data, now: Date = Date()) -> Result? {
        guard let type = data.first else { return nil }

        switch type {
        case 0xA0:
            guard data.count >= 8 else {
                state = nil
                return .failed("History start packet was truncated.")
            }

            let intervalSeconds = Int(data[2])
            let totalPoints: UInt16 = data.withUnsafeBytes { raw in
                raw.load(fromByteOffset: 4, as: UInt16.self)
            }
            let startAgeMinutes: UInt16 = data.withUnsafeBytes { raw in
                raw.load(fromByteOffset: 6, as: UInt16.self)
            }

            let oldest = now.addingTimeInterval(-TimeInterval(UInt16(littleEndian: startAgeMinutes)) * 60)

            let advertisedTotalPoints = Int(UInt16(littleEndian: totalPoints))

            var newState = State(
                totalChunks: 0,
                receivedChunks: 0,
                totalPoints: advertisedTotalPoints,
                processedPoints: 0,
                interval: TimeInterval(intervalSeconds),
                oldestTimestamp: oldest,
                points: []
            )
            newState.points.reserveCapacity(min(advertisedTotalPoints, maxPoints))
            state = newState
            return nil

        case 0xA1:
            guard data.count >= 4 else {
                state = nil
                return .failed("History data packet was truncated.")
            }
            guard var currentState = state else {
                return .failed("History data arrived before history start.")
            }

            let totalChunks = Int(data[2])
            let pointsInChunk = Int(data[3])

            if currentState.totalChunks == 0 {
                currentState.totalChunks = totalChunks
            } else if currentState.totalChunks != totalChunks {
                state = nil
                return .failed("History packet count changed mid-transfer.")
            }

            let requiredBytes = 4 + (pointsInChunk * MemoryLayout<Int16>.size)
            guard data.count >= requiredBytes else {
                state = nil
                return .failed("History packet length did not match the advertised point count.")
            }

            let baseIndex = currentState.processedPoints
            let firstRetainedIndex = max(0, currentState.totalPoints - maxPoints)

            data.withUnsafeBytes { raw in
                for index in 0..<pointsInChunk {
                    let absoluteIndex = baseIndex + index
                    let offset = 4 + (index * MemoryLayout<Int16>.size)
                    let rawValue = raw.load(fromByteOffset: offset, as: Int16.self)
                    let celsius = Double(Int16(littleEndian: rawValue)) / 10.0
                    let timestamp = currentState.oldestTimestamp.addingTimeInterval(
                        Double(absoluteIndex) * currentState.interval
                    )

                    if absoluteIndex >= firstRetainedIndex {
                        currentState.points.append(TemperatureData(timestamp: timestamp, temperature: celsius))
                    }
                }
            }

            currentState.receivedChunks += 1
            currentState.processedPoints += pointsInChunk

            if currentState.points.count > maxPoints {
                currentState.points.removeFirst(currentState.points.count - maxPoints)
            }

            if currentState.receivedChunks == currentState.totalChunks {
                state = nil
                return .finished(currentState.points)
            }

            state = currentState
            return nil

        default:
            return nil
        }
    }
}
