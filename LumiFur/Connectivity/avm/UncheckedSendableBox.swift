import Foundation

/// Use only to move Obj-C / CoreBluetooth references into @Sendable closures.
/// Safe here because we *only* touch these values on the BLE queue that owns them.
final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
