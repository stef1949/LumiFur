//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI
import CoreBluetooth
import AVKit
import CoreImage
import Charts
import UniformTypeIdentifiers
import os

// IOS 18.0 features
//import AccessorySetupKit


struct SplashView: View {
    @Environment(\.colorScheme) var colorScheme

    var overlayColor: Color {
        colorScheme == .dark ? .black : .gray
    }
    
    @State var isActive: Bool = false
    //Protogen hover effect
    @State private var yOffset: CGFloat = -10
    @State private var animationDirection: Bool = true // True for moving up, false for moving down
    let animationDuration: Double =  2.0 //Duratio for full hover effect
    
    var body: some View {
        ZStack {
            if self.isActive {
                ContentView()
            } else {
                NavigationStack {
                    ZStack {
                        VStack {
                            animatedProtogenImage(yOffset: $yOffset, animationDirection: true, animationDuration: animationDuration)
                            
                            ZStack {
                                
                                Image(systemName: "aqi.medium")
                                    .resizable()
                                    .scaledToFit()
                                    .font(.title)
                                    .symbolEffect(.variableColor.cumulative)
                                    .blur(radius: 10)
                                
                                Image(systemName: "aqi.medium")
                                    .resizable()
                                    .scaledToFit()
                                    .font(.title)
                                    .symbolEffect(.variableColor.cumulative)
                                    .blur(radius: 1)
                                    .opacity(0.5)
                                
                                Circle()
                                    .fill(RadialGradient(
                                        gradient: Gradient(colors: [Color.clear, overlayColor]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 150
                                    )
                                    )
                                    .scaleEffect(CGSize(width: 1.2, height: 1.2))
                                    .font(.title)
                                    .blur(radius: 3.0)
                                    .scaledToFit()
                                
                            }
                            .padding()
                            
                            Text("Welcome to LumiFur")
                                .font(.title)
                                .multilineTextAlignment(.trailing)
                                .fontDesign(.monospaced)
                            
                            Text("An app designed to control your fursuit LEDs & light systems")
                                .multilineTextAlignment(.center)
                                .padding([.leading, .bottom, .trailing])
                                .fontDesign(.monospaced)
                            
                            
                            Button(action: {
                                withAnimation {
                                    self.isActive = true
                                }
                            }) {
                                Text("Start")
                                    .font(.title2)
                                    .padding()
                                    .padding(.horizontal)
                                    .background(.ultraThinMaterial)
                                    .tint(.gray)
                                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
                            }
                            
                        }
                   }
                    .overlay(alignment: .bottomTrailing) {
                        NavigationLink(destination: InfoView()) {
                            Image(systemName: "info.square")
                                .imageScale(.large)
                                .symbolRenderingMode(.multicolor)
                                .tint(.gray)
                                .padding()
                                .offset(CGSize(width: -10.0, height: -5.0))
                            
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
struct BouncingButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    @State private var animate = false

    var body: some View {
        Button(action: {
            // Trigger the bounce animation on tap
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                animate = true
            }
            // Return to normal scale after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    animate = false
                }
            }
            // Perform the button action
            action()
        }) {
            label()
                .scaleEffect(animate ? 0.8 : 1.0)
        }
    }
}

// MARK: ContentView
struct ContentView: View {
    @StateObject var accessoryViewModel = AccessoryViewModel()
    //@EnvironmentObject var bluetoothManager: BluetoothManager
    //Environment Variables
        //@Environment(\.colorScheme) var colorScheme
    //@EnvironmentObject var sharedViewModel: SharedViewModel
    /*
    //Connectivity Variables
    @State private var connectionBluetooth: Bool = true
    @State private var connectionWIFI: Bool = false
    @State private var connectionMatter: Bool = false
    @State private var connectionZ_Wave: Bool = false
    @State private var signalStrength: Int = 0
    */
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter, z_wave
        var id: Self { self }
    }
    //@State private var selectedConnection: Connection = .bluetooth
    @State private var selectedMatrix: SettingsView.Matrixstyle = .array
    
    private let twoColumnGrid = [
        GridItem(.flexible(minimum: 100), spacing: 5),
        GridItem(.flexible(minimum: 100), spacing: 5)
        //GridItem(.flexible(minimum: 40))
    ]
    
    // Array of SF Symbol names
    private var protoActionOptions: [String] = ["", "🏳️‍⚧️", "🌈", "🙂", "😳", "😎", "☠️"]
   
    //dotMatrix variable
    @State private var dotMatrices: [[Bool]] = Array(repeating: Array(repeating: false, count: 64), count: 32)
    
    @State private var errorMessage: String? = nil
    
    //Protogen image variables
    @State private var yOffset: CGFloat = 0
    @State private var animationDuration: Double = 1.0
    /*
    private var signalLevel: Double {
            // Convert RSSI to 0-1 range
            let signalStrength = Double(bluetoothManager.signalStrength)
            let normalizedSignal = (signalStrength - (-100)) / ((-30) - (-100))
            return min(max(normalizedSignal, 0.0), 1.0)
        }
    */
    var body: some View {
        ZStack {
            Color.primary
                .opacity(0.3)
                .ignoresSafeArea()
            
            NavigationStack {
                VStack(spacing: 20) {
                    headerSection
                    statusSection
                    ledArraySection
                    gridSection
                    settingsAndChartsSection
                    /*
                    HStack {
                        // animated image
                        animatedProtogenImage(yOffset: $yOffset, animationDirection: true, animationDuration: animationDuration)
                        
                        //.border(Color.red)
                            .scaledToFill()
                            .frame(height: 100)
                            .offset(CGSize(width: 0.0, height: 20.0))
                        
                        Text("LumiFur")
                            .font(.title)
                            .multilineTextAlignment(.trailing)
                            .fontDesign(.monospaced)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                    }
                    
                    VStack {
                        // Status Indicators and Signal Strength
                        HStack {
                            Spacer()
                            HStack {
                                // Signal Strength Indicator
                               SignalStrengthView(rssi: bluetoothManager.signalStrength)
                                
                                // Connection Status
                                //Image(systemName: bluetoothManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                //.symbolRenderingMode(.multicolor)
                                //.symbolEffect(.variableColor)
                                    //.foregroundColor (bluetoothManager.isConnected ? .green : .gray)
                                
                                // Bluetooth Status
                                Image(systemName: "logo.bluetooth.capsule.portrait.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .symbolEffect(.variableColor)
                                    .opacity(bluetoothManager.isConnected ? 1 : 0.3)
                            }
                            .padding(.all, 10.0)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                            .border(Color.green)
                        }
                        //.border(Color.purple)
                        .offset(CGSize(width: -20.0, height: -40.0))
                    }
                    //LED ARRAY MAIN VIEW
                   VStack {
                        HStack {
                            Spacer()
                           //  MatrixTestView5()
                           // LEDMatrix()
                            LEDPreview()
                                .background(.ultraThinMaterial)
                            Spacer()
                            LEDPreview()
                                .background(.ultraThinMaterial)
                            Spacer()
                        }
                        .padding()
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                    .frame(width: .infinity, height: 100)
                    .offset(CGSize(width: 0, height: -40))
                    .padding()
                    .border(Color.purple)
                    //Spacer()
                    
                    // Grid of squares
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: twoColumnGrid, alignment: .center, spacing: 0) {
                            ForEach(protoActionOptions , id: \.self) { item in
                                //GeometryReader { gr in
                                    Button(action: {
                                        // Define the action for the button here
                                        print("\(item) button pressed")
                                    }) {
                                        Text(item)
                                            //.imageScale(.large)
                                            .font(.system(size: 120))
                                            //.resizable()
                                            //.frame(maxHeight: .infinity, maxWidth: .infinity) // Makes the image fill the available space
                                            .aspectRatio(1, contentMode: .fit)
                                            .border(Color.green)
                                            .symbolRenderingMode(.monochrome)
                                            .background(.clear)
                                    }
                                .aspectRatio(1, contentMode: .fit)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .padding()
                                .frame(width: 175, height:175)
                                .border(Color.red)
                            }
                        }
                        .border(Color.yellow)
                        //.aspectRatio(1, contentMode: .fit)
                        .frame(maxHeight: .infinity)
                        .padding()
                    }
                        
                        // Settings Button
                        HStack {
                            Spacer()
                            HStack {
                                VStack {
                                    Chart(bluetoothManager.cpuUsageData) {
                                        LineMark(
                                            x: .value("Time", $0.timestamp),
                                            y: .value("CPU Usage", $0.cpuUsage)
                                        )
                                        .foregroundStyle(Color.blue)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
                                        .symbol(Circle().strokeBorder(lineWidth: 2)) // Corrected symbol usage=
                                    }
                                    .chartYScale(domain: 0...100)
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: 1)) { value in
                                            
                                            
                                            AxisValueLabel {
                                                if let dateValue = value.as(Date.self) {
                                                    Text(dateValue, format: .dateTime.hour().minute().second())
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(values: .stride(by: 50)) { value in
                                            AxisValueLabel {
                                                if let intValue = value.as(Int.self) {
                                                    Text("\(intValue)%")
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                                    .frame(height: 50)
                                    
                                    Text("CPU")
                                        .fontDesign(.rounded)
                                        .bold()
                                }
                                //.frame(width: 30, height: 50)
                                VStack {
                                    Chart(bluetoothManager.cpuUsageData) {
                                        LineMark(
                                            x: .value("Time", $0.timestamp),
                                            y: .value("CPU Usage", $0.cpuUsage)
                                        )
                                        .foregroundStyle(Color.blue)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
                                        .symbol(Circle().strokeBorder(lineWidth: 2)) // Corrected symbol usage
                                    }
                                    .chartYScale(domain: 0...100)
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: 1)) { value in
                                            
                                            
                                            AxisValueLabel {
                                                if let dateValue = value.as(Date.self) {
                                                    Text(dateValue, format: .dateTime.hour().minute().second())
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(values: .stride(by: 50)) { value in
                                            AxisValueLabel {
                                                if let intValue = value.as(Int.self) {
                                                    Text("\(intValue)%")
                                                        .font(.caption2)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(10)
                                    .frame(height: 50)
                                    
                                    Text("Temperature")
                                        .fontDesign(.rounded)
                                        .bold()
                                    
                                }
                                //.frame(maxWidth: 30, maxHeight: 50)
                            }
                            .padding(.bottom,40)
                            
                            //NavigationLink(destination: ContentView3()) {Image(systemName: "info")}
                            NavigationLink(destination: SettingsView(selectedMatrix: $selectedMatrix)) {
                                Image(systemName: "gear")
                                    .imageScale(.large)
                                    .symbolRenderingMode(.multicolor)
                                NavigationLink(destination: BluetoothConnectionView())
                                {Image(systemName: "1.circle.fill")}
                            }
                            .padding()
                        }
                    */
                    }
                    .background(Color.clear)
                }
            .scrollContentBackground(.hidden)
            .navigationTitle("LumiFur")
        }
    }
    private var headerSection: some View {
            HStack {
                // Call the extension function on Color.clear (or any other placeholder view)
                Color.clear
                    .animatedProtogenImage(
                        yOffset: $yOffset,
                        animationDirection: true,
                        animationDuration: animationDuration
                    )
                    .scaledToFill()
                    .frame(height: 100)
                    .offset(y: 40)
                
                Text("LumiFur")
                    .font(.title)
                    .multilineTextAlignment(.trailing)
                    .fontDesign(.monospaced)
                    .padding(.horizontal)
                
                Spacer()
            }
        }
    private var statusSection: some View {
            HStack {
                Spacer()
                HStack {
                    SignalStrengthView(rssi: accessoryViewModel.signalStrength)
                    
                    Image(systemName: "logo.bluetooth.capsule.portrait.fill")
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.variableColor)
                        .opacity(accessoryViewModel.isConnected ? 1 : 0.3)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                //.border(Color.green)
            }
            .offset(x: -20, y: -40)
        }
    private var ledArraySection: some View {
                HStack {
                    Spacer()
                    LEDPreview()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    LEDPreview()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                //.border(Color.red)
                //.padding()
            
            //.background(.ultraThinMaterial)
            //.clipShape(RoundedRectangle(cornerRadius: 25))
            //.frame(maxWidth: .infinity, maxHeight: 100)
            //.offset(y: -40)
            //.padding()
            //.border(Color.purple)
        }
    static let gradientStart = Color(red: 0 / 255, green: 0 / 255, blue: 0 / 255)
    static let gradientEnd = Color(red: 239.0 / 255, green: 172.0 / 255, blue: 120.0 / 255)
    
    private var gridSection: some View {
        ZStack {
            
            ScrollView(.horizontal) {
                LazyHGrid(rows: twoColumnGrid, alignment: .center, spacing: 0) {
                    ForEach(protoActionOptions.indices, id: \.self) { index in
                        BouncingButton(action: {
                            print("\(protoActionOptions[index]) button pressed – setting view \(index + 1)")
                            accessoryViewModel.setView(index + 1)
                        }) {
                            Text(protoActionOptions[index])
                                .aspectRatio(1, contentMode: .fit)
                                .font(.system(size: 75))
                                .frame(width: 175, height: 175)
                            
                            //.border(Color.green)
                                .symbolRenderingMode(.monochrome)
                                .background(.clear)
                            
                            //.padding()
                        }
                        //.buttonStyle(BounceButtonStyle())
                        //.aspectRatio(1, contentMode: .fit)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        //.padding()
                        .frame(width: 150, height: 150)
                        //.border(Color.red)
                        .padding()
                    }
                }
                //.border(Color.yellow)
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
        .mask(LinearGradient(gradient: Gradient(colors: [.clear, .black, .black, .black, .black, .black, .black, .black, .black, .black, .black, .black, .clear]), startPoint: .leading, endPoint: .trailing))
        }
    private var settingsAndChartsSection: some View {
            HStack {
                Spacer()
                
                // CPU Usage Chart
                VStack {
                    Chart(accessoryViewModel.cpuUsageData) { element in
                        LineMark(
                            x: .value("Time", element.timestamp),
                            y: .value("CPU Usage", element.cpuUsage)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 2]))
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 1)) { value in
                            AxisValueLabel {
                                if let dateValue = value.as(Date.self) {
                                    Text(dateValue, format: .dateTime.hour().minute().second())
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 50)) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)%")
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .frame(height: 70)
                    
                    Text("CPU")
                        .fontDesign(.rounded)
                        .bold()
                }
                //.padding()
                // Temperature Chart
                VStack {
                    Chart {
                                    ForEach(accessoryViewModel.temperatureData) { element in
                                        LineMark(
                                            x: .value("Time", element.timestamp),
                                            y: .value("Temperature", element.temperature)
                                        )
                                        //.foregroundStyle(.red) // Change to blue if preferred.
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                     
                                    }
                                }
                                //.id(accessoryViewModel.temperatureData.count)
                                .animation(.easeInOut(duration: 0.5), value: accessoryViewModel.temperatureData.count)
                                .chartYScale(domain: 15...85) // Adjust the domain to your expected temperature range.
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { axisValue in
                                        AxisValueLabel() {
                                                        if let tempValue = axisValue.as(Double.self) {
                                                            Text(String(format: "%.1f°C", tempValue))
                                                                .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic) { axisValue in
                                        AxisValueLabel() {
                                            if let tempValue = axisValue.as(Double.self) {
                                                Text(String(tempValue))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .frame(height: 70)
                                
                                Text("Temperature (°C)")
                                    .fontDesign( .rounded)
                                    .bold()
                            }
                //.padding()
                //.border(Color.gray, width: 1)
                
                // Isolated NavigationLinks
                NavigationLink(destination: SettingsView(bleModel: accessoryViewModel, selectedMatrix: $selectedMatrix)) {
                    Image(systemName: "gear")
                        .imageScale(.large)
                        .symbolRenderingMode(.multicolor)
                }
                .padding()
                /*
                NavigationLink(destination: BluetoothConnectionView()) {
                    Image(systemName: "1.circle.fill")
                }
                 */
            }
        }
    }
    /*
    struct LedGridView: View {
        // Computed property to generate an array of random colors
            private var squares: [Color] {
                Array(repeating: Color.clear, count: 64).map { _ in randomColor() }
            }
        
        let spacing: CGFloat = 1 // Space between rows and columns
        
        // Define the number of columns in the grid
        let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 1), count: 8)
        
        var body: some View {
            
            LazyVGrid(columns: columns, spacing: 1) {  // Y Spacing
                ForEach(squares.indices, id: \.self) { index in
                    Rectangle()
                        .fill(squares[index])
                        .frame(width: 5, height: 5)
                        .cornerRadius(1)
                        //.blur(radius: 3.0) //Potential blur effect?
                }
            }
            .padding(10.0)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 5, height: 5)))
            .aspectRatio(0.5, contentMode: .fit)
        }
    }
    
    // Function to generate a random color (red, green, or blue)
    private func randomColor() -> Color {
        let colors: [Color] = [.red, .green, .blue, .white]
        return colors.randomElement() ?? .clear
    }
*/
// MARK: SettingsView

struct SettingsView: View {
    @State private var fontSize: CGFloat = 15
    @State private var showLineNumbers = false
    @State private var showPreview = true
    @ObservedObject var bleModel: AccessoryViewModel
    @State private var showAdvanced = false
    
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter
        var id: Self { self }
    }
    
    //Matrix Options
    enum Matrixstyle: String, CaseIterable, Identifiable {
        case array, dot, wled
        var id: Self { self }
    }
    
    @Binding var selectedMatrix: Matrixstyle
    
    var body: some View {
        NavigationStack {
            List {
                connectionSection
                matrixSection
                advancedSettings
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Connection Error",
                   isPresented: $bleModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(bleModel.errorMessage)
            }
        }
    }
// MARK: - Connection Section
    private var connectionSection: some View {
            Section {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Spacer()
                        Image("bluetooth.fill")
                            .font(.system(size: 75))
                            .opacity(0.2)
                        Spacer()
                    }
                    HStack {
                        SignalStrengthView(rssi: bleModel.signalStrength)
                        Spacer()
                        Text(bleModel.connectionStatus)
                            .foregroundColor(bleModel.isConnected ? .green : .red)
                            .animation(.easeInOut(duration: 0.3), value: bleModel.isConnected)
                    }
                    
                    if !bleModel.isConnected {
                        Button(action: bleModel.scanForDevices) {
                            Label("Scan for Devices", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!bleModel.isBluetoothReady)
                    }
                    
                    deviceList
                }
                .padding(.vertical, 8)
            } header: {
                Text("Device Connection")
            }
        }
    
    private var deviceList: some View {
            Group {
                if bleModel.isConnected, let device = bleModel.connectedDevice {
                                ConnectedDeviceView(peripheral: device)
                } else {
                    ForEach(bleModel.discoveredDevices) { device in
                                        Button(action: { bleModel.connect(to: device) }) {
                                            HStack {
                                                Text(device.name)
                                                Spacer()
                                                SignalStrengthView(rssi: bleModel.signalStrength)
                                                if bleModel.connectingPeripheral?.id == device.id {
                                                    ProgressView()
                                                }
                                            }
                                        }
                                        .disabled(bleModel.isConnecting)
                    }
                }
            }
        }
    
    private var matrixSection: some View {
            Section {
                HStack {
                    LEDPreview()
                    LEDPreview()
                }
                MatrixStylePicker(selectedMatrix: $selectedMatrix)
            } header: {
                Text("Matrix Configuration")
            }
        }
        
        private var advancedSettings: some View {
            Section {
                Toggle("Show Advanced Settings", isOn: $showAdvanced)
                
                if showAdvanced {
                    NavigationLink("Connection Parameters") {
                        AdvancedSettingsView(bleModel: bleModel) // AdvancedSettingsView is assumed to be defined elsewhere
                    }
                    Button("Reset to Defaults") {
                        // Handle reset logic here
                    }
                }
            }
        }
    }

    struct MatrixStylePicker: View {
        @Binding var selectedMatrix: SettingsView.Matrixstyle
        
        var body: some View {
            Picker("Visual Style", selection: $selectedMatrix) {
                ForEach(SettingsView.Matrixstyle.allCases) { style in
                    Text(style.rawValue.capitalized)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Current style: \(selectedMatrix.rawValue.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

struct ConnectedDeviceView: View {
    let peripheral: PeripheralDevice
    
    var body: some View {
            HStack {
                Image("LumiFur_Controller_AK")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                VStack(alignment: .leading) {
                    Text(peripheral.name)
                        .font(.headline)
                    Text(peripheral.id.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()
    }
}

struct SignalStrengthView: View {
    @AppStorage("rssiMonitoringEnabled") private var rssiMonitoringEnabled: Bool = false
    let rssi: Int
    
    private var signalLevel: Double {
        let normalized = Double(rssi + 100) / 70.0 // Normalize between -100dBm and -30dBm
        return min(max(normalized, 0.0), 1.0)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<4) { bar in
                RoundedRectangle(cornerRadius: 2)
                    .fill(bar < Int(signalLevel * 4) ? .blue : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(bar + 2) * 4)
            }
            if rssiMonitoringEnabled {
                Text("\(rssi)dBm")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: rssiMonitoringEnabled)
            }
        }
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var bleModel: AccessoryViewModel

    // Example advanced settings state variables.
   // @State private var autoReconnect: Bool = true
    @AppStorage("autoReconnect") private var autoReconnect: Bool = true
    @AppStorage("rssiMonitoringEnabled") private var rssiMonitoringEnabled: Bool = false
    @AppStorage("rssiUpdateInterval") private var rssiUpdateInterval: Double = 1.0

    var body: some View {
        Form {
            // Connection Options Section
            Section(header: Text("Connection Options")) {
                Toggle("Auto Reconnect", isOn: $autoReconnect)
                    .onChange(of: autoReconnect) { oldValue, newValue in
                        // Implement auto-reconnect logic here if desired.
                        // For example, you might store this setting in your model or user defaults.
                        print("Auto Reconnect changed from \(oldValue) to \(newValue)")
                    }
                
                Button("Disconnect Device") {
                    bleModel.disconnect()
                }
                
                Button("Reconnect Device") {
                    bleModel.scanForDevices()
                }
            }
            
            // RSSI Monitoring Section
            Section(header: Text("RSSI Monitoring")) {
                Toggle("Enable RSSI Monitoring", isOn: $rssiMonitoringEnabled)
                    .onChange(of: rssiMonitoringEnabled) { oldValue, newValue in
                        if newValue {
                            bleModel.startRSSIMonitoring()
                        } else {
                            // If you have a method to stop monitoring, you can call it here.
                            print("RSSI monitoring disabled")
                        }
                    }
                
                if rssiMonitoringEnabled {
                    Stepper("Update Interval: \(rssiUpdateInterval, specifier: "%.1f") sec", value: $rssiUpdateInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: rssiUpdateInterval) { oldValue, newValue in
                            // If your model supports adjustable intervals for reading RSSI, update it here.
                            print("RSSI update interval changed from \(oldValue) to \(newValue)")
                        }
                }
            }
            
            // Debug / Status Information Section
            Section(header: Text("Debug Info")) {
                Text("Connection Status: \(bleModel.connectionStatus)")
                Text("Selected View: \(bleModel.selectedView)")
                Text("Temperature: \(bleModel.temperature)")
                Text("Signal Strength: \(bleModel.signalStrength)dBm")
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/*
struct SignalStrengthView: View {
    let rssi: Int
    
    // Convert RSSI to signal strength value (0.0 to 1.0)
    private var signalLevel: Double {
        // RSSI typically ranges from -30 (strong) to -100 (weak)
        let maxRSSI: Double = -30
        let minRSSI: Double = -100
        
        let signalStrength = Double(rssi)
        let normalizedSignal = (signalStrength - minRSSI) / (maxRSSI - minRSSI)
        return min(max(normalizedSignal, 0.0), 1.0) // Clamp between 0 and 1
    }
    
    // Check if there's an active connection
    private var isConnected: Bool {
        return rssi > -100
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Image(systemName: "cellularbars", variableValue: signalLevel)
                .symbolRenderingMode(.multicolor)
                .imageScale(.medium)
                .symbolEffect(.variableColor)
                .opacity(isConnected ? 1 : 0.3)
                .animation(.smooth, value: isConnected)
            
            if isConnected {
                Text("\(rssi) dBm")
                    .font(.system(size: 8))
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
    }
}
 */
/*
struct DotMatrixView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var overlayColor: Color {
            colorScheme == .dark ? .gray : .black
        }
    
    var invertoverlayColor: Color {
        colorScheme == .light ? .black : .gray
    }
    
    let matrix: [[Bool]]
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                .foregroundStyle(.ultraThinMaterial)
                .aspectRatio(contentMode: .fit)
                .frame(width: 70)
                
            
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { y in
                    HStack(spacing: 0.5) {
                        ForEach(0..<8, id: \.self) { x in
                            Rectangle()
                                .fill(self.matrix[y][x] ? overlayColor : invertoverlayColor)
                                .frame(width: 5, height: 5)
                                .clipShape(RoundedRectangle(cornerRadius: CGFloat(1)))
                        }
                    }
                }
            }
            //.border(Color.green)
            .padding(.horizontal)
            
        }
        //.border(Color.purple)
        .aspectRatio(1, contentMode: .fit)
        }
}

struct CircleMatrixView: View {
    @Environment(\.colorScheme) var colorScheme
    var overlayColor: Color {
            colorScheme == .dark ? .gray : .white
        }
    
    var invertoverlayColor: Color {
        colorScheme == .light ? .black : .gray
    }
    
    let matrix: [[Bool]]
    
    var body: some View {
        VStack(spacing: 1) {
                   ForEach(0..<8, id: \.self) { y in
                       HStack(spacing: 1) {
                           ForEach(0..<8, id: \.self) { x in
                               Circle()
                                   .fill(self.matrix[y][x] ? overlayColor : invertoverlayColor)
                                   .frame(width: 5, height: 5)
                           }
                       }
                   }
               }
           }
       }
*/
struct InfoView: View {
    var body: some View {
        ScrollView {
            VStack {
                ZStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                    
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .blur(radius: 10)
                        .opacity(0.5)
                }
                .padding()
                Rectangle()
                    .foregroundStyle(.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                    .frame(height: 300)
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Text("About")
                                    .font(.title)
                                    .multilineTextAlignment(.leading)
                                    .fontDesign(.monospaced)
                                Spacer()
                            }
                            Text("LumiFur is an innovative iOS app designed to control LED and light systems for fursuits. It provides an intuitive interface for managing various lighting effects and patterns, enhancing the visual appeal of fursuit costumes.")
                            
                                .padding()
                        }
                            .padding()
                    )
                    .padding()
                Rectangle()
                    .foregroundStyle(.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
                    .frame(height: 800)
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Text("Features")
                                    .font(.title)
                                    .fontDesign(.monospaced)
                                    .padding()
                                Spacer()
                            }
                            .padding()
                            VStack {
                                Spacer()
                                Text("Bluetooth Connectivity")
                                    .font(.headline)
                                Text("Seamlessly connect to your fursuit's LED system using Bluetooth technology.")
                                Spacer()
                                Text("Wi-Fi Support")
                                    .font(.headline)
                                Text("Option to control your lighting system over Wi-Fi for extended range.")
                                Spacer()
                                Text("Multiple Connection Options")
                                    .font(.headline)
                                Text("Support for various connectivity methods including Bluetooth, Wi-Fi, Matter, and Z-Wave.")
                                Spacer()
                                Text("Interactive Dot Matrix Display")
                                    .font(.headline)
                                Text("Visualize and control your fursuit's LED patterns with an 8x8 dot matrix interface.")
                                Spacer()
                                Text("Customizable Lighting Patterns")
                                    .font(.headline)
                                Text("Create and save custom lighting sequences for your fursuit.")
                                Spacer()
                                Text("Real-time Preview")
                                    .font(.headline)
                                Text("See how your lighting patterns will look before applying them to your fursuit.")
                                Spacer()
                                Text("User-friendly Interface")
                                    .font(.headline)
                                Text("Intuitive controls designed for ease of use, even when wearing a fursuit.")
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            Spacer()
                                .padding()
                        }
                    )
                    .padding()
            }
                    
        }
        .padding()
    }
}
/*
struct ConnectTestView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    let addOBJObjectCommand = "ADD_OBJ_OBJECT"
    let addFBXObjectCommand = "ADD_FBX_OBJECT"
    let addImageMaterialCommand = "ADD_IMAGE_MATERIAL:path/to/image.png"
    let addGIFMaterialCommand = "ADD_GIF_MATERIAL:path/to/animation.gif"
    let createShaderMaterialCommand = "CREATE_SHADER_MATERIAL:shader code here"
    let modify3DObjectCommand = "MODIFY_3D_OBJECT:objectID:newProperties"
    let keyframeAnimationCommand = "KEYFRAME_ANIMATION:animationID:keyframes"
    
        let rows = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        var body: some View {
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, spacing: 20) {
                    Button(action: {
                        bluetoothManager.startScanning()
                    }) {
                        Text("Connect")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "ADD_OBJ_OBJECT".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Add OBJ")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "ADD_FBX_OBJECT".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Add FBX")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "ADD_IMAGE_MATERIAL:path/to/image.png".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Add Image")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "ADD_GIF_MATERIAL:path/to/animation.gif".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Add GIF")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "CREATE_SHADER_MATERIAL:shader code here".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Create Shader")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "MODIFY_3D_OBJECT:objectID:newProperties".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Modify 3D")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        let data = "KEYFRAME_ANIMATION:animationID:keyframes".data(using: .utf8)!
                        bluetoothManager.sendData(data: data)
                    }) {
                        Text("Keyframe")
                            .frame(width: 100, height: 100)
                            .background(.ultraThinMaterial)
                            
                            .cornerRadius(15)
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .border(Color.black)
        }
    }
*/
// MARK: -WORKING- Testing matrix arducode code
/*
struct MatrixTestView4_4: View {
    static let X_SEGMENTS = 2
    static let Y_SEGMENTS = 1
    static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS
    
    @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
    @State private var isAnimating = false
    @State private var timer: Timer?
    @State private var sx1: Int32 = 15 << 8
    @State private var sx2: Int32 = 15 << 8
    @State private var sy1: Int32 = 0
    @State private var sy2: Int32 = 0
    @State private var travel: UInt8 = 0
    
    var body: some View {
        VStack {
            VStack {
                // Display the LED matrix
                ForEach(0..<Self.Y_SEGMENTS, id: \.self) { y in
                    HStack {
                        ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
                            LEDMatrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25.0))
           
            Text("4x4_Test")
                .font(.title)
            
            // Button to start/stop the animation
            Button(action: toggleAnimation) {
                Text(isAnimating ? "Stop" : "Start")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .onAppear(perform: setup)
    }
    
    func setup() {
        clear()
    }
    
    func toggleAnimation() {
        isAnimating.toggle()
        if isAnimating {
            // Start the animation
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                loop()
            }
        } else {
            // Stop the animation
            timer?.invalidate()
            timer = nil
        }
    }
    
    func loop() {
        sx1 = sx1 - (sy1 >> 6)
        sy1 = sy1 + (sx1 >> 6)
        sx2 = sx2 - (sy2 >> 5)
        sy2 = sy2 + (sx2 >> 5)
        
        travel = travel &- 1
        
        let x_offset = Int32(sx1 >> 8) - Int32(Self.X_SEGMENTS * 4)
        let y_offset = Int32(sx2 >> 8) - Int32(Self.Y_SEGMENTS * 4)
        
        clear()
        drawCircles(x_offset: x_offset, y_offset: y_offset, travel: travel)
    }
    
    func drawCircles(x_offset: Int32, y_offset: Int32, travel: UInt8) {
        var x = x_offset
        var y = y_offset
        var ysumsquares = x_offset * x_offset + y * y
        var yroot = Int32(sqrtf(Float(ysumsquares)))
        var ynextsquare = yroot * yroot
        
        for screeny in 0..<(Self.Y_SEGMENTS * 8) {
            x = x_offset
            var xsumsquares = ysumsquares
            var xroot = yroot
            var xnextsquare = xroot * xroot
            
            for screenx in 0..<(Self.X_SEGMENTS * 8) {
                let output = UInt8(((xroot + Int32(travel)) & 8) >> 3)
                setPixel(x: UInt8(screenx), y: UInt8(screeny), mode: output)
                
                xsumsquares += 2 * x + 1
                x += 1
                
                if x <= 0 {
                    if xsumsquares < xnextsquare {
                        xnextsquare -= 2 * xroot - 1
                        xroot -= 1
                    }
                } else {
                    if xsumsquares >= xnextsquare {
                        xroot += 1
                        xnextsquare = (xroot + 1) * (xroot + 1)
                    }
                }
            }
            
            ysumsquares += 2 * y + 1
            y += 1
            
            if y <= 0 {
                if ysumsquares < ynextsquare {
                    ynextsquare -= 2 * yroot - 1
                    yroot -= 1
                }
            } else {
                if ysumsquares >= ynextsquare {
                    yroot += 1
                    ynextsquare = (yroot + 1) * (yroot + 1)
                }
            }
        }
    }
    
    func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
        let addr = Int(x / 8 + y * UInt8(Self.X_SEGMENTS))
        let mask: UInt8 = 128 >> (x % 8)
        switch mode {
        case 0: framebuffer[addr] &= ~mask // clear pixel
        case 1: framebuffer[addr] |= mask  // plot pixel
        default: break
        }
    }
    
    func clear() {
        framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
    }
}

struct MatrixTestView5: View {
    static let X_SEGMENTS = 2
    static let Y_SEGMENTS = 1
    static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS
    
    @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
    @State private var isAnimating = false
    @State private var timer: Timer?
    @State private var sx1: Int32 = 15 << 8
    @State private var sx2: Int32 = 15 << 8
    @State private var sy1: Int32 = 0
    @State private var sy2: Int32 = 0
    @State private var travel: UInt8 = 0
    
    var body: some View {
        LazyVStack {
           VStack {
                // Display the LED matrix
                ForEach((0...8), id: \.self){ y in
                    HStack {
                        ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
                            LEDMatrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25.0))
           
            Text("4x4_Test")
                .font(.title)
            
            // Button to start/stop the animation
            Button(action: toggleAnimation) {
                Text(isAnimating ? "Stop" : "Start")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .onAppear(perform: setup)
    }
    
    func setup() {
        clear()
    }
    
    func toggleAnimation() {
        isAnimating.toggle()
        if isAnimating {
            // Start the animation
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                loop()
            }
        } else {
            // Stop the animation
            timer?.invalidate()
            timer = nil
        }
    }
    
    func loop() {
        sx1 = sx1 - (sy1 >> 6)
        sy1 = sy1 + (sx1 >> 6)
        sx2 = sx2 - (sy2 >> 5)
        sy2 = sy2 + (sx2 >> 5)
        
        travel = travel &- 1
        
        let x_offset = Int32(sx1 >> 8) - Int32(Self.X_SEGMENTS * 4)
        let y_offset = Int32(sx2 >> 8) - Int32(Self.Y_SEGMENTS * 4)
        
        clear()
        drawCircles(x_offset: x_offset, y_offset: y_offset, travel: travel)
    }
    
    func drawCircles(x_offset: Int32, y_offset: Int32, travel: UInt8) {
        var x = x_offset
        var y = y_offset
        var ysumsquares = x_offset * x_offset + y * y
        var yroot = Int32(sqrtf(Float(ysumsquares)))
        var ynextsquare = yroot * yroot
        
        for screeny in 0..<(Self.Y_SEGMENTS * 8) {
            x = x_offset
            var xsumsquares = ysumsquares
            var xroot = yroot
            var xnextsquare = xroot * xroot
            
            for screenx in 0..<(Self.X_SEGMENTS * 8) {
                let output = UInt8(((xroot + Int32(travel)) & 8) >> 3)
                setPixel(x: UInt8(screenx), y: UInt8(screeny), mode: output)
                
                xsumsquares += 2 * x + 1
                x += 1
                
                if x <= 0 {
                    if xsumsquares < xnextsquare {
                        xnextsquare -= 2 * xroot - 1
                        xroot -= 1
                    }
                } else {
                    if xsumsquares >= xnextsquare {
                        xroot += 1
                        xnextsquare = (xroot + 1) * (xroot + 1)
                    }
                }
            }
            
            ysumsquares += 2 * y + 1
            y += 1
            
            if y <= 0 {
                if ysumsquares < ynextsquare {
                    ynextsquare -= 2 * yroot - 1
                    yroot -= 1
                }
            } else {
                if ysumsquares >= ynextsquare {
                    yroot += 1
                    ynextsquare = (yroot + 1) * (yroot + 1)
                }
            }
        }
    }
    
    func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
        let addr = Int(x / 8 + y * UInt8(Self.X_SEGMENTS))
        let mask: UInt8 = 128 >> (x % 8)
        switch mode {
        case 0: framebuffer[addr] &= ~mask // clear pixel
        case 1: framebuffer[addr] |= mask  // plot pixel
        default: break
        }
    }
    
    func clear() {
        framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
    }
}
*/

struct LEDPreview: View {
    // The state of the grid, with 64 rows and 32 columns
    @State private var ledStates: [[Color]] = Array(
            repeating: Array(repeating: .black, count: 32),
            count: 64
        )
    
    var body: some View {
        GeometryReader { geometry in
                    Canvas { context, size in
                        let ledWidth = size.width / 64
                        let ledHeight = size.height / 32
                        
                        for row in 0..<64 {
                            for col in 0..<32 {
                                let rect = CGRect(
                                    x: CGFloat(row) * ledWidth,
                                    y: CGFloat(col) * ledHeight,
                                    width: ledWidth - 1,
                                    height: ledHeight - 1
                                )
                                
                                context.fill(
                                    Path(rect),
                                    with: .color(ledStates[row][col])
                                )
                            }
                        }
                    }
                }
                .aspectRatio(64/32, contentMode: .fit)
                .drawingGroup() // Metal-accelerated rendering
                .padding(10)
            }
        
    
    private func toggleLED(row: Int, col: Int) {
        // Toggle between red and black for the tapped LED
        ledStates[row][col] = ledStates[row][col] == .black ? .red : .black
    }
}

/*
    // Individual LED arrays
struct LEDMatrix: View {
    @Binding var framebuffer: [UInt8]
    let xOffset: Int
    let yOffset: Int
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<64, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<32, id: \.self) { col in
                        Rectangle()
                            //.fill(ledColor(row: row, col: col))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .background(.gray)
        .clipShape(RoundedRectangle(cornerRadius: 2.0))
    }
    /*
    private func ledColor(row: Int, col: Int) -> Color {
        let index = (yOffset + row) * MatrixTestView5.X_SEGMENTS + (xOffset / 8)
        let bit = 7 - col
        return framebuffer[index] & (1 << bit) != 0 ? .green : .black
    }
*/
     }
 */
/*
struct MatrixTestView_FileImporter: View {
    static let X_SEGMENTS = 4
    static let Y_SEGMENTS = 4
    static let NUM_SEGMENTS = X_SEGMENTS * Y_SEGMENTS

    @State private var framebuffer = [UInt8](repeating: 0, count: 8 * NUM_SEGMENTS)
    @State private var isAnimating = false
    @State private var timer: Timer?
    @State private var sx1: Int32 = 15 << 8
    @State private var sx2: Int32 = 15 << 8
    @State private var sy1: Int32 = 0
    @State private var sy2: Int32 = 0
    @State private var travel: UInt8 = 0
    @State private var showingFileImporter = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileImport")
    
    
    var body: some View {
        VStack {
            VStack {
                // Display the LED matrix
                ForEach(0..<Self.Y_SEGMENTS, id: \.self) { y in
                    HStack {
                        ForEach(0..<Self.X_SEGMENTS, id: \.self) { x in
                            LED_Matrix(framebuffer: $framebuffer, xOffset: x * 8, yOffset: y * 8)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25.0))

            Text("4x4_Test_File_Importer")
                .font(.title)

            // Button to start/stop the animation
            Button(action: toggleAnimation) {
                Text(isAnimating ? "Stop" : "Start")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)

            // Button to upload the matrix file
            Button(action: { showingFileImporter = true }) {
                Text("Upload Matrix File")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.text]) { result in
                handleFileImport(result: result)
                print("importing")
            }
        }
        .onAppear(perform: setup)
    }

    func setup() {
        clear()
    }

    func toggleAnimation() {
        isAnimating.toggle()
        if isAnimating {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                loop()
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    func loop() {
        sx1 = sx1 - (sy1 >> 6)
        sy1 = sy1 + (sx1 >> 6)
        sx2 = sx2 - (sy2 >> 5)
        sy2 = sy2 + (sx2 >> 5)

        travel = travel &- 1

        let x_offset = Int32(sx1 >> 8) - Int32(Self.X_SEGMENTS * 4)
        let y_offset = Int32(sx2 >> 8) - Int32(Self.Y_SEGMENTS * 4)

        clear()
        drawCircles(x_offset: x_offset, y_offset: y_offset, travel: travel)
    }

    func drawCircles(x_offset: Int32, y_offset: Int32, travel: UInt8) {
        // Your drawing logic here
    }

    func setPixel(x: UInt8, y: UInt8, mode: UInt8) {
        // Your setPixel logic here
    }

    func clear() {
        framebuffer = [UInt8](repeating: 0, count: 8 * Self.NUM_SEGMENTS)
    }

    func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let fileURL):
            do {
                let content = try String(contentsOf: fileURL)
                parseMatrixFile(content: content)
            } catch {
                print("Error reading file: \(error.localizedDescription)")
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }

    func parseMatrixFile(content: String) {
        // Updated parsing logic to handle matrix format correctly
        guard let startIndex = content.range(of: "const vector<vector<bool>> grid0 = {")?.upperBound else { return }
        let matrixString = content[startIndex...].components(separatedBy: "};").first ?? ""

        let rows = matrixString.split(separator: "{").dropFirst().map { $0.split(separator: "}") }
        var matrix = [[Bool]]()

        for row in rows {
            let boolRow = row.first?.split(separator: ",").compactMap { $0.trimmingCharacters(in: .whitespaces) == "1" }
            if let boolRow = boolRow {
                matrix.append(boolRow)
            }
        }

        // Update the framebuffer
        updateFramebuffer(with: matrix)
    }

    func updateFramebuffer(with matrix: [[Bool]]) {
        // Convert matrix data to framebuffer format
        clear()
        for (y, row) in matrix.enumerated() {
            for (x, value) in row.enumerated() {
                let mode: UInt8 = value ? 1 : 0
                setPixel(x: UInt8(x), y: UInt8(y), mode: mode)
            }
        }
    }
}
*/
/*
struct LED_Matrix: View {
    @Binding var framebuffer: [UInt8]
    let xOffset: Int
    let yOffset: Int

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<8, id: \.self) { col in
                        Rectangle()
                            .fill(ledColor(row: row, col: col))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .background(.gray)
        .clipShape(RoundedRectangle(cornerRadius: 2.0))
    }

    private func ledColor(row: Int, col: Int) -> Color {
        let index = (yOffset + row) * MatrixTestView_FileImporter.X_SEGMENTS + (xOffset / 8)
        let bit = 7 - col
        return framebuffer[index] & (1 << bit) != 0 ? .green : .black
    }
}
*/

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FileImport")

struct DetailedParsingError: LocalizedError {
    let description: String
    let detailedDescription: String
    
    var errorDescription: String? {
        return description
    }
}

struct Grid: Equatable {
    let width: Int
    let height: Int
    private var data: [Bool]
    
    init(width: Int, height: Int, data: [Bool]) {
        self.width = width
        self.height = height
        self.data = data
    }
    
    subscript(x: Int, y: Int) -> Bool {
        get { data[y * width + x] }
        set { data[y * width + x] = newValue }
    }
    
    func swappedHalves() -> Grid {
        var newData = [Bool]()
        let halfWidth = width / 2
        for y in 0..<height {
            for x in 0..<width {
                if x < halfWidth {
                    newData.append(self[x + halfWidth, y])
                } else {
                    newData.append(self[x - halfWidth, y])
                }
            }
        }
        return Grid(width: width, height: height, data: newData)
    }
}

class MatrixConfig: ObservableObject {
    @Published var rows: Int = 32
    @Published var columns: Int = 64
    @Published var chain: Int = 2
    @Published var grids: [String: Grid] = [:]
    @Published var currentGridKey: String = ""
}

struct LEDMatrix3: View {
    let grid: Grid
    
    var body: some View {
        let swappedGrid = grid.swappedHalves()
        VStack(spacing: 1) {
            ForEach(0..<swappedGrid.height, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<swappedGrid.width, id: \.self) { column in
                        Rectangle()
                            .fill(swappedGrid[column, row] ? Color.white : Color.black)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .background(Color.gray)
        .padding()
    }
}
/*
struct ContentView3: View {
    @StateObject private var config = MatrixConfig()
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?
    @State private var detailedErrorInfo: String?
    @State private var isAnimating: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if let currentGrid = config.grids[config.currentGridKey] {
                LEDMatrix3(grid: currentGrid)
            } else {
                Text("No grid data available")
            }
            VStack {
                Text("Matrix: \(config.rows)x\(config.columns * config.chain)")
                Text("Current Grid: \(config.currentGridKey)")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack {
                Button("Import File") {
                    isImporting = true
                }
                .buttonStyle(.borderedProminent)
                
                Button(isAnimating ? "Stop Animation" : "Start Animation") {
                    isAnimating.toggle()
                    logger.info("Animation toggled: \(isAnimating)")
                }
                .buttonStyle(.borderedProminent)
                
                Button("Next Grid") {
                    showNextGrid()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            if let detailedErrorInfo = detailedErrorInfo {
                Text("Detailed Error Info:")
                    .font(.headline)
                Text(detailedErrorInfo)
                    .font(.caption)
            }
        }
        .onReceive(timer) { _ in
            if isAnimating {
                showNextGrid()
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }
 */
    /*
    func handleFileImport(result: Result<[URL], Error>) {
        do {
            guard let selectedFile: URL = try result.get().first else {
                throw NSError(domain: "FileImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])
            }
            logger.info("File selected: \(selectedFile.lastPathComponent)")
            
            guard selectedFile.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "FileImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to access the file. Please check app permissions."])
            }
            
            defer {
                selectedFile.stopAccessingSecurityScopedResource()
            }
            
            let content = try String(contentsOf: selectedFile)
            logger.info("File content read successfully, length: \(content.count) characters")
            
            try parseHeaderFile(content)
            logger.info("File parsing completed successfully")
        } catch {
            logger.error("Error importing file: \(error.localizedDescription)")
            errorMessage = "Error importing file: \(error.localizedDescription)"
            if let detailedError = error as? DetailedParsingError {
                detailedErrorInfo = detailedError.detailedDescription
            } else {
                detailedErrorInfo = nil
            }
        }
    }
    
    func parseHeaderFile(_ content: String) throws {
        logger.info("Starting to parse header file")
        var grids: [String: Grid] = [:]
        var currentGridData: [Bool] = []
        var currentGridKey: String = ""
        var rowCount = 0
        var columnCount = 0
        var linesParsed = 0
        var inGridDeclaration = false
        var openBraceCount = 0
        var continuationLine = ""
        
        let lines = content.components(separatedBy: .newlines)
        logger.info("Number of lines in file: \(lines.count)")
        
        for (index, line) in lines.enumerated() {
            linesParsed += 1
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.starts(with: "#") || trimmedLine.starts(with: "include") {
                logger.info("Skipping preprocessor line: \(trimmedLine)")
                continue
            }
            
            if trimmedLine.hasSuffix("=") {
                continuationLine = trimmedLine
                continue
            }
            
            let processLine = continuationLine + trimmedLine
            continuationLine = ""
            
            if processLine.contains("const vector<vector<bool>> grid") {
                inGridDeclaration = true
                if !currentGridData.isEmpty && !currentGridKey.isEmpty {
                    logger.info("Completed parsing grid: \(currentGridKey), size: \(columnCount)x\(rowCount)")
                    grids[currentGridKey] = Grid(width: columnCount, height: rowCount, data: currentGridData)
                    currentGridData = []
                    rowCount = 0
                }
                currentGridKey = processLine.components(separatedBy: " ").last?.replacingOccurrences(of: "=", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                logger.info("Started parsing new grid: \(currentGridKey)")
            }
            
            if inGridDeclaration {
                openBraceCount += processLine.filter { $0 == "{" }.count
                openBraceCount -= processLine.filter { $0 == "}" }.count
                
                let cleanedLine = processLine.replacingOccurrences(of: "[{},]", with: " ", options: .regularExpression)
                let values = cleanedLine.split(separator: " ").compactMap { Int($0) }
                
                if !values.isEmpty {
                    let boolValues = values.map { $0 == 1 }
                    currentGridData.append(contentsOf: boolValues)
                    rowCount += 1
                    columnCount = max(columnCount, boolValues.count)
                    logger.info("Parsed row \(rowCount) with \(boolValues.count) values")
                }
                
                if openBraceCount == 0 {
                    inGridDeclaration = false
                    if !currentGridData.isEmpty {
                        logger.info("Completed parsing grid: \(currentGridKey), size: \(columnCount)x\(rowCount)")
                        grids[currentGridKey] = Grid(width: columnCount, height: rowCount, data: currentGridData)
                        currentGridData = []
                        rowCount = 0
                        columnCount = 0
                    }
                }
            }
            
            if index % 100 == 0 {
                logger.info("Parsed \(index) lines")
            }
        }
        if !grids.isEmpty {
                    DispatchQueue.main.async {
                        self.config.grids = grids
                        self.config.rows = rowCount
                        self.config.columns = columnCount / self.config.chain
                        self.config.currentGridKey = grids.keys.sorted().first ?? ""
                        self.errorMessage = nil
                        self.detailedErrorInfo = nil
                        logger.info("Updated UI with parsed data. Current grid key: \(self.config.currentGridKey)")
                    }
                } else {
                    throw DetailedParsingError(
                        description: "No valid grid data found in the file",
                        detailedDescription: "Parsed \(linesParsed) lines, but couldn't extract any valid grid data."
                    )
                }
            }
    
    
    func showNextGrid() {
        let sortedKeys = config.grids.keys.sorted()
        logger.info("Sorted keys: \(sortedKeys)")
        if let currentIndex = sortedKeys.firstIndex(of: config.currentGridKey) {
            let nextIndex = (currentIndex + 1) % sortedKeys.count
            config.currentGridKey = sortedKeys[nextIndex]
            logger.info("Switched to grid: \(config.currentGridKey)")
        } else {
            logger.warning("Current grid key not found in sorted keys")
        }
    }
        }
*/
/*
struct BluetoothConnectionView: View {
    @EnvironmentObject var bluetoothManager: AccessoryViewModel
    
    var body: some View {
        VStack {
            Image("ESP32-S3")
            
            Text(bluetoothManager.connectionStatus)
                .font(.title2)
                .foregroundStyle(bluetoothManager.isConnected ? .green : .red)
                .padding()
            
            // Since PeripheralDevice is Identifiable (using its 'id' property), we can use the array directly in the List.
            List(bluetoothManager.discoveredDevices) { device in
                            HStack {
                                Text(device.name)
                                
                                Spacer()
                                
                                Button(action: {
                                    bluetoothManager.connect(to: device)
                                }) {
                                    // If connected and the connected device's id matches the device in this row,
                                    // show "Connected"; otherwise, show "Connect".
                                    Text((bluetoothManager.isConnected &&
                                          bluetoothManager.connectedPeripheralID == device.id)
                                         ? "Connected" : "Connect")
                                        .foregroundColor(.blue)
                                }
                                // Optionally disable the button if a connection is active.
                                .disabled(bluetoothManager.isConnected)
                            }
                        }
                        
                        Spacer()
        }
        //.background(Color(UIColor.systemBackground))
    }
}
*/
#Preview {
    ContentView()
        //.environmentObject(AccessoryViewModel.shared)
}
