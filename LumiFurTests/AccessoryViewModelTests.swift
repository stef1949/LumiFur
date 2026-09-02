import Testing
@testable import LumiFur
import CoreBluetooth
import Foundation

@Suite("AccessoryViewModel - Logic Tests")
struct AccessoryViewModelLogicTests {
    @MainActor
    private func makeViewModel(testName: String = #function) -> AccessoryViewModel {
        let suiteName = "com.richies3d.LumiFur.tests.\(testName)"
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
            staticColorEnabled: false,
            mouthBrightnessOverrideEnabled: false,
            accelerometerEnabled: false,
            sleepModeEnabled: true,
            auroraModeEnabled: false
        )
        #expect(data == Data([1, 0, 1, 0, 0]), "Payload should include the disabled maw brightness override flag")
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

    @Test("Deleting StoredPeripheral updates persisted devices")
    @MainActor
    func testDeleteStoredPeripheralPersistence() throws {
        let vm = makeViewModel()
        let firstDevice = StoredPeripheral(id: "UUID-1234", name: "TestDevice")
        let secondDevice = StoredPeripheral(id: "UUID-5678", name: "OtherDevice")

        vm.saveStoredPeripherals([firstDevice, secondDevice])
        vm.deleteStoredPeripheral(firstDevice)

        #expect(vm.previouslyConnectedDevices == [secondDevice])
        #expect(vm.loadStoredPeripherals() == [secondDevice])
    }

    @Test("Deleting last connected StoredPeripheral clears remote reconnect target")
    @MainActor
    func testDeleteStoredPeripheralClearsLastConnectedPeripheral() throws {
        let suiteName = "com.richies3d.LumiFur.tests.\(#function)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StoredPeripheralStore(defaults: defaults)
        let device = StoredPeripheral(id: "39F13A98-47D1-46B7-9F2D-8699A03C577C", name: "TestDevice")

        store.save([device])
        store.setLastConnectedPeripheralUUID(device.id)

        let vm = AccessoryViewModel(client: BLEClient(), store: store, defaults: defaults)
        vm.deleteStoredPeripheral(device)

        let reloadedVM = AccessoryViewModel(client: BLEClient(), store: store, defaults: defaults)
        #expect(reloadedVM.attemptRemoteConnect() == "Scanning for LumiFur controllers.")
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

    @Test("Dashboard state distinguishes recovery and connected states")
    func testDashboardStateMapping() {
        #expect(
            DashboardState(
                connectionState: .disconnected,
                bluetoothState: .poweredOn
            ) == .disconnected
        )
        #expect(
            DashboardState(
                connectionState: .connected,
                bluetoothState: .poweredOn
            ) == .connected
        )
        #expect(
            DashboardState(
                connectionState: .disconnected,
                bluetoothState: .unauthorized
            ) == .permissionDenied
        )
        #expect(
            DashboardState(
                connectionState: .disconnected,
                bluetoothState: .poweredOff
            ) == .bluetoothOff
        )
        #expect(
            DashboardState(
                connectionState: .failed,
                bluetoothState: .poweredOn,
                errorMessage: "Controller is out of range."
            ) == .failed(message: "Controller is out of range.")
        )
    }

    @Test("Only a connected dashboard allows controller actions")
    func testDashboardActionAvailability() {
        #expect(DashboardState.connected.allowsControllerActions)
        #expect(!DashboardState.disconnected.allowsControllerActions)
        #expect(!DashboardState.scanning.allowsControllerActions)
        #expect(!DashboardState.permissionDenied.allowsControllerActions)
        #expect(!DashboardState.failed(message: "No controller").allowsControllerActions)
    }

    @Test("Inline connection feedback can be dismissed")
    @MainActor
    func testClearFeedback() {
        let vm = makeViewModel()
        vm.errorMessage = "Controller is unavailable."
        vm.showError = true

        #expect(vm.hasInlineFeedback)

        vm.clearFeedback()

        #expect(!vm.hasInlineFeedback)
        #expect(vm.errorMessage.isEmpty)
        #expect(!vm.showError)
    }
}
