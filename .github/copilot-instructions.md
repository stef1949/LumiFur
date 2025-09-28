# LumiFur - GitHub Copilot Instructions

## Project Overview

LumiFur is an innovative iOS app designed to control LED and light systems for fursuits. It provides an intuitive SwiftUI-based interface for managing various lighting effects and patterns, enhancing the visual appeal of fursuit costumes through Bluetooth and Wi-Fi connectivity.

## Project Architecture

### Technology Stack
- **Platform**: iOS (14.0+), watchOS
- **Language**: Swift 5.0+
- **UI Framework**: SwiftUI
- **Development Tool**: Xcode 12.0+
- **Connectivity**: Core Bluetooth, Wi-Fi
- **Additional Frameworks**: 
  - CoreHaptics (haptic feedback)
  - Charts (data visualization)
  - MarkdownUI (documentation rendering)
  - WidgetKit (home screen widgets)
  - ActivityKit (Live Activities)
  - AccessorySetupKit (iOS 18.0 features)

### Project Structure
```
LumiFur/
├── LumiFur/                    # Main iOS app
│   ├── LumiFurApp.swift       # App entry point
│   ├── ContentView.swift      # Main app interface
│   ├── Connectivity/          # Bluetooth/networking components
│   │   ├── AccessoryViewModel.swift  # BLE device management
│   │   ├── DeviceInfoView.swift     # Device information display
│   │   └── WatchOSConnectivity.swift # Watch connectivity
│   ├── SettingsPage/          # App configuration screens
│   ├── SharedViews/           # Reusable UI components
│   └── Assets/                # Images, colors, etc.
├── LumiFur Widget/            # Home screen widget
├── LumiFurWatchOS Watch App/  # Apple Watch companion
├── docs/                      # Documentation
└── README.md
```

## Core Features & Components

### 1. LED Matrix Control
- **Purpose**: Visualize and control LED patterns with 64x32 or 8x8 dot matrix interfaces
- **Implementation**: Custom SwiftUI views with interactive touch controls
- **Key Files**: `CustomLedView.swift`, `MatrixStylePicker.swift`

### 2. Bluetooth Connectivity
- **Purpose**: Connect to fursuit LED controllers via Bluetooth Low Energy (BLE)
- **Implementation**: `AccessoryViewModel` manages device discovery, connection, and data transmission
- **Key Features**: Auto-reconnect, RSSI monitoring, device persistence
- **Related Files**: `AccessoryViewModel.swift`, `DeviceInfoView.swift`

### 3. Lighting Patterns & Effects
- **Purpose**: Create, save, and apply custom lighting sequences
- **Implementation**: Real-time pattern preview with customizable effects
- **Features**: Color ramping, breathing effects, plasma animations, temperature-responsive patterns

### 4. Multi-Platform Support
- **iOS App**: Main interface with full feature set
- **watchOS App**: Companion app with essential controls
- **Widgets**: Home screen widgets for quick access
- **Live Activities**: Real-time status updates

## Coding Conventions & Best Practices

### Swift Style Guidelines
- Use SwiftUI declarative syntax
- Follow Swift naming conventions (camelCase for properties/methods, PascalCase for types)
- Implement proper error handling with Result types and throw statements
- Use `@MainActor` for UI-related classes
- Leverage Combine framework for reactive programming patterns

### Architecture Patterns
- **MVVM**: Model-View-ViewModel architecture with ObservableObject
- **Dependency Injection**: Services injected through environment or init parameters
- **Single Responsibility**: Each view/model focuses on specific functionality
- **State Management**: Use `@State`, `@StateObject`, `@ObservedObject`, and `@AppStorage` appropriately

### Code Organization
- Group related functionality in dedicated folders
- Use file extensions to separate concerns (e.g., `+Extensions.swift`)
- Keep view files focused and extract complex logic into view models
- Use protocol-oriented programming where appropriate

## Key Development Areas

### Bluetooth/Networking
- Implement proper BLE peripheral management
- Handle connection state changes gracefully
- Implement retry mechanisms for failed connections
- Use proper queue management for data transmission

### UI/UX Implementation
- Follow iOS Human Interface Guidelines
- Implement proper accessibility features
- Use consistent color schemes and typography
- Ensure responsive design for different screen sizes

### Performance Optimization
- Use efficient data structures for LED matrix operations
- Implement proper memory management for BLE operations
- Optimize animation performance for smooth visual effects
- Use background queues for intensive operations

## Repository Relationships

### Companion Repository
- **LumiFur_Controller**: Hardware controller firmware and protocols
- **Integration**: This app communicates with devices running LumiFur_Controller firmware
- **Data Exchange**: JSON-based command/response protocols over BLE

## Development Workflows

### Testing
- Unit tests in `LumiFurTests/` using Swift Testing framework
- UI tests in `LumiFurUITests/`
- Use `@Suite` and `@Test` annotations for organizing test cases
- Test BLE connectivity with mock peripherals when possible
- Test UI responsiveness across different device sizes
- Follow async/await patterns in test methods when testing async components

### Build Configuration
- Support multiple schemes (Debug, Release)
- Use proper code signing for device testing
- Configure proper entitlements for BLE usage
- Support both simulator and device builds

### Version Management
- Follow semantic versioning (SemVer)
- Update version numbers in Info.plist files
- Maintain changelog for releases
- Tag releases appropriately

## Documentation Standards

- Use comprehensive documentation comments for public APIs
- Include code examples for complex implementations
- Document BLE protocol specifications
- Maintain user-facing documentation in `/docs` folder

## Common Patterns & Examples

### BLE Device Management
```swift
@MainActor
class AccessoryViewModel: ObservableObject {
    @Published var discoveredDevices: [PeripheralDevice] = []
    @Published var isConnected = false
    
    func connectToDevice(_ device: PeripheralDevice) {
        // Implementation
    }
}
```

### SwiftUI View Structure
```swift
struct SettingsView: View {
    @ObservedObject var bleModel: AccessoryViewModel
    @State private var showAdvanced = false
    
    var body: some View {
        NavigationStack {
            List {
                // Settings sections
            }
        }
    }
}
```

### Shared Data Structures
The app uses shared data structures for cross-platform compatibility:
```swift
struct FaceItem: Identifiable, Equatable {
    let id = UUID()
    let content: SharedOptions.ProtoAction
}
```

### Testing Patterns
```swift
@Suite("AccessoryViewModel - Logic Tests")
struct AccessoryViewModelLogicTests {
    @Test("Test description")
    func testFunction() async throws {
        // Test implementation with Swift Testing framework
        #expect(condition, "Error message")
    }
}
```

## Error Handling
- Use proper Swift error handling with do-catch blocks
- Implement user-friendly error messages
- Log errors appropriately for debugging
- Provide graceful degradation when features are unavailable

## Security Considerations
- Handle BLE pairing securely
- Validate incoming data from BLE devices
- Protect user preferences and device configurations
- Use proper keychain storage for sensitive data when needed

## Contributing Guidelines
- Follow the existing code style and patterns
- Add appropriate tests for new features
- Update documentation when adding new functionality
- Ensure compatibility with minimum iOS version (14.0+)
- Test on both simulator and physical devices
- Consider accessibility implications for new UI elements

---

When working with this codebase, prioritize code clarity, proper error handling, and maintaining the established architectural patterns. The app's primary purpose is to provide a seamless and intuitive interface for controlling LED systems in fursuits, so user experience and reliability are paramount.