import Testing
@testable import LumiFur
import Foundation

@Suite("AccessoryViewModel - Logic Tests")
struct AccessoryViewModelLogicTests {
    @MainActor
    private func makeViewModel(testName: String = #function) -> AccessoryViewModel {
        let suiteName = "com.richies3d.LumiFur.xcodeproj-tests.\(testName)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StoredPeripheralStore(defaults: defaults)
        return AccessoryViewModel(client: BLEClient(), store: store, defaults: defaults)
    }

    @Test("Accessory settings encoding produces correct payload")
    @MainActor
    func testEncodedAccessorySettingsPayload() throws {
        let vm = makeViewModel()
        let data = vm.encodedAccessorySettingsPayload(
            autoBrightness: true,
            accelerometerEnabled: false,
            sleepModeEnabled: true,
            auroraModeEnabled: false
        )
        #expect(data == Data([1, 0, 1, 0]), "Payload should match expected encoding")
    }
    
    @Test("Saving and loading StoredPeripheral roundtrips")
    @MainActor
    func testStoredPeripheralPersistence() throws {
        let vm = makeViewModel()
        let testDevices = [StoredPeripheral(id: "UUID-1234", name: "TestDevice")]
        vm.saveStoredPeripherals(testDevices)
        let loaded = vm.loadStoredPeripherals()
        #expect(loaded == testDevices, "Loaded devices should match saved devices.")
    }

    @Test("setView ignores invalid values and does not update selectedView")
    @MainActor
    func testSetViewValidation() throws {
        let vm = makeViewModel()
        let original = vm.selectedView
        _ = vm.setView(0) // Below valid range
        #expect(vm.selectedView == original)
        _ = vm.setView(51) // Above valid range
        #expect(vm.selectedView == original)
        _ = vm.setView(original) // Same as current
        #expect(vm.selectedView == original)
    }
}
