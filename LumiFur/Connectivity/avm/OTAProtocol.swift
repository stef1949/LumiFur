import Foundation

/// The firmware acknowledgement is separate from CoreBluetooth's ATT write response.
struct OTAWriteAcknowledgement {
    let command: UInt8
    let requiresFirmwareResponse: Bool
    private(set) var transportAcknowledged = false
    private(set) var response: AccessoryOTAResponse?

    var isComplete: Bool {
        transportAcknowledged && (!requiresFirmwareResponse || response != nil)
    }

    mutating func acknowledgeTransport() {
        transportAcknowledged = true
    }

    mutating func receive(_ response: AccessoryOTAResponse) {
        if response.code == command && response.isAcknowledgement {
            self.response = response
        }
    }
}

enum OTAProtocol {
    // The controller's worker accepts 512 bytes, including the command byte.
    static func chunkPayloadSize(maximumWriteLength: Int) -> Int {
        max(0, min(maximumWriteLength, 512) - 1)
    }
}

/// Cancellation can arrive before the request reaches the BLE serial queue.
final class OTAWriteCancellation: @unchecked Sendable {
    let id = UUID()
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}
