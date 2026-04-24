//
//  RRGGBBHelper.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 02/03/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RGB8: Equatable, Sendable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

extension RGB8 {
    /// Returns "RRGGBB" (no leading #)
    var hexString: String {
        String(format: "%02X%02X%02X", r, g, b)
    }

    /// Returns bytes [r,g,b]
    var bytes: [UInt8] { [r, g, b] }
}

struct StrobeSettingsPayload: Equatable, Sendable {
    let enabled: Bool
    let rgb: RGB8
    let cycleMs: UInt16

    /// Firmware protocol:
    /// - 0x01 + color payload
    /// - 0x02 + speed payload (UInt16 little-endian)
    enum Opcode {
        static let color: UInt8 = 0x01
        static let speed: UInt8 = 0x02
    }

    /// Packet: [0x01][R][G][B]
    func encodeColorPacketRGB() -> Data {
        var out = Data()
        out.reserveCapacity(4)
        out.append(Opcode.color)
        out.append(contentsOf: rgb.bytes)
        return out
    }

    /// Packet: [0x02][cycleLo][cycleHi] (little-endian)
    /// If `enabled == false`, this sends speed=0 to represent "off".
    func encodeSpeedPacket() -> Data {
        var out = Data()
        out.reserveCapacity(3)
        out.append(Opcode.speed)

        let speedToSend: UInt16 = enabled ? cycleMs : 0
        let le = speedToSend.littleEndian
        out.append(UInt8(truncatingIfNeeded: le & 0x00FF))
        out.append(UInt8(truncatingIfNeeded: (le & 0xFF00) >> 8))
        return out
    }

    // MARK: - Legacy
    /// Legacy 6-byte encoding used by older firmware builds.
    /// Prefer `encodeColorPacketRGB()` + `encodeSpeedPacket()`.
    func encodeBinary6Legacy() -> Data {
        var out = Data()
        out.reserveCapacity(6)

        out.append(enabled ? 1 : 0)
        out.append(rgb.r)
        out.append(rgb.g)
        out.append(rgb.b)

        let le = cycleMs.littleEndian
        out.append(UInt8(truncatingIfNeeded: le & 0x00FF))
        out.append(UInt8(truncatingIfNeeded: (le & 0xFF00) >> 8))
        return out
    }
}

extension RGB8 {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.r = UInt8((v >> 16) & 0xFF)
        self.g = UInt8((v >> 8) & 0xFF)
        self.b = UInt8(v & 0xFF)
    }
}

extension Color {
    init(_ rgb: RGB8) {
        self.init(red: Double(rgb.r) / 255.0,
                  green: Double(rgb.g) / 255.0,
                  blue: Double(rgb.b) / 255.0)
    }

    /// Best-effort conversion of a SwiftUI `Color` to 8-bit RGB.
    /// On iOS/tvOS/watchOS this uses UIKit.
    func toRGB8() -> RGB8? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGB8(
            r: UInt8((r * 255).rounded()),
            g: UInt8((g * 255).rounded()),
            b: UInt8((b * 255).rounded())
        )
        #else
        // Non-UIKit targets: callers should supply RGB directly.
        return nil
        #endif
    }
}

/// Firmware notify/read payload:
/// {"color":"RRGGBB","speedMs":123}
struct FWStrobeSettings: Decodable, Equatable, Sendable {
    let color: String
    let speedMs: UInt16

    var rgb: RGB8? { RGB8(hex: color) }

    /// Treat speed==0 as disabled (firmware has no explicit enabled flag).
    var enabled: Bool { speedMs != 0 }

    static func decode(from data: Data) -> FWStrobeSettings? {
        guard let s = String(data: data, encoding: .utf8), !s.isEmpty,
              let json = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FWStrobeSettings.self, from: json)
    }
}
