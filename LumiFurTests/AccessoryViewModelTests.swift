import Testing
@testable import LumiFur
import Foundation

@Suite("AccessoryViewModel - Logic Tests")
struct AccessoryViewModelLogicTests {
    @Test("Accessory settings encoding produces correct payload")
    func testEncodedAccessorySettingsPayload() async throws {
        let vm = await AccessoryViewModel.shared
        let data = await vm.encodedAccessorySettingsPayload(
            autoBrightness: true,
            accelerometerEnabled: false,
            sleepModeEnabled: true,
            auroraModeEnabled: false
        )
        #expect(data == Data([1, 0, 1, 0]), "Payload should match expected encoding")
    }
    
    @Test("Saving and loading StoredPeripheral roundtrips")
    func testStoredPeripheralPersistence() async throws {
        let vm = await AccessoryViewModel.shared
        let testDevices = [StoredPeripheral(id: "UUID-1234", name: "TestDevice")]
        await vm.saveStoredPeripherals(testDevices)
        let loaded = await vm.loadStoredPeripherals()
        #expect(loaded == testDevices, "Loaded devices should match saved devices.")
    }

    @Test("setView ignores invalid values and does not update selectedView")
    func testSetViewValidation() async throws {
        let vm = await AccessoryViewModel.shared
        let original = await vm.selectedView
        await vm.setView(0) // Below valid range
        #expect(vm.selectedView == original)
        await vm.setView(51) // Above valid range
        #expect(vm.selectedView == original)
        await vm.setView(original) // Same as current
        #expect(vm.selectedView == original)
    }
}
