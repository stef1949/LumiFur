import Foundation

// MARK: - AccessoryCommandEncoder

/// Encodes UI actions into the BLE wire format expected by the accessory.
enum AccessoryCommandEncoder {
    static let requestHistoryCommand = Data([0x01])

    /// Encodes the config characteristic payload.
    static func accessorySettingsPayload(
        autoBrightness: Bool,
        accelerometerEnabled: Bool,
        sleepModeEnabled: Bool,
        auroraModeEnabled: Bool
    ) -> Data {
        Data([
            autoBrightness ? 1 : 0,
            accelerometerEnabled ? 1 : 0,
            sleepModeEnabled ? 1 : 0,
            auroraModeEnabled ? 1 : 0,
        ])
    }

    /// Encodes the config characteristic payload from a value-type configuration.
    static func accessorySettingsPayload(_ configuration: AccessoryConfiguration) -> Data {
        accessorySettingsPayload(
            autoBrightness: configuration.autoBrightness,
            accelerometerEnabled: configuration.accelerometerEnabled,
            sleepModeEnabled: configuration.sleepModeEnabled,
            auroraModeEnabled: configuration.auroraModeEnabled
        )
    }

    /// Encodes the currently selected face index.
    static func view(_ view: Int) -> Data {
        Data([UInt8(clamping: view)])
    }

    /// Encodes the scrolling text command.
    static func scrollText(_ text: String) -> Data {
        let payload = (text.data(using: .utf8) ?? Data()).prefix(63)
        var packet = Data([0x01])
        packet.append(payload)
        return packet
    }

    /// Encodes the scrolling speed command.
    static func scrollSpeed(_ speed: UInt8) -> Data {
        let clamped = UInt8(max(1, min(100, Int(speed))))
        return Data([0x02, clamped])
    }

    /// Encodes the OTA start packet.
    static func otaStart(size: Int) -> Data {
        var payload = Data([0x01])
        var littleEndianSize = UInt32(size).littleEndian
        payload.append(Data(bytes: &littleEndianSize, count: MemoryLayout<UInt32>.size))
        return payload
    }

    /// Encodes an OTA data chunk.
    static func otaChunk(_ chunk: Data) -> Data {
        var payload = Data([0x02])
        payload.append(chunk)
        return payload
    }

    /// Encodes an OTA data chunk directly from a firmware buffer range to avoid an intermediate `subdata` copy.
    static func otaChunk(from firmwareData: Data, range: Range<Int>) -> Data {
        var payload = Data()
        payload.reserveCapacity(range.count + 1)
        payload.append(0x02)

        firmwareData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            payload.append(
                baseAddress.advanced(by: range.lowerBound).assumingMemoryBound(to: UInt8.self),
                count: range.count
            )
        }

        return payload
    }

    /// Encodes the OTA completion packet.
    static func otaFinish() -> Data {
        Data([0x03])
    }

    /// Encodes the OTA abort packet.
    static func otaAbort() -> Data {
        Data([0x04])
    }
}
