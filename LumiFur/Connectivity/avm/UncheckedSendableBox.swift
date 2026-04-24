import Foundation

/// Use only to move actor-confined Obj-C / CoreBluetooth references into `@Sendable` closures.
/// Safe here because callers must still respect the owning actor or queue boundary.
final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// Weak variant for capturing actor-confined reference types in `@Sendable` closures without retain cycles.
final class WeakUncheckedSendableBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?

    init(_ value: T?) {
        self.value = value
    }
}
