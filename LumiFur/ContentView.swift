//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI
import CoreBluetooth

struct SplashView: View {
    
    @State var isActive: Bool = false
    
    //Protogen hover effect
    @State private var yOffset: CGFloat = 0
    @State private var animationDirection: Bool = true // True for moving up, false for moving down
    let animationDuration: Double =  2.0 //Duratio for full hover effect
    
    var body: some View {
        ZStack {
            if self.isActive {
                ContentView()
            } else {
                
                VStack {
                    Image("Protogen")
                        .resizable()
                        .scaledToFit()
                        .frame(width: .infinity, height: .infinity)
                        .offset(y: yOffset)
                        .onAppear {
                            // Start the animation when the view appears
                            withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                                yOffset = animationDirection ? -20 : 20 // Adjust the vertical movement range
                            }
                        }
                    
                    Image(systemName: "light.ribbon")
                        .imageScale(.large)
                        .padding()
                    
                    Text("Welcome to LumiFur")
                        .font(.title)
                    
                    Text("An app designed to control your fursuit LEDs & light systems")
                        .multilineTextAlignment(.center)
                        .padding(.vertical)
                    
                    
                    Button(action: {
                      withAnimation {
                        self.isActive = true
                    }
                }) {
                    Text("Start")
                    .font(.title2)
                    .padding()
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 10)))
                    
                }
                .padding(.bottom, 40) // Adjust as needed
                }
                .padding()
                
            }
        }
    }
}

struct ContentView: View {
    
    //Connectivity Variables
    @State private var connectionBluetooth: Bool = true
    @State private var connectionWIFI: Bool = false
    @State private var connectionMatter: Bool = false
    @State private var connectionZ_Wave: Bool = false
    @State private var signalStrength: Int = 0
    
    //Connectivity Options
    enum Connection: String, CaseIterable, Identifiable {
        case bluetooth, wifi, matter, z_wave
        var id: Self { self }
    }
    @State private var selectedConnection: Connection = .bluetooth
    
    var body: some View {
        NavigationStack {
            //Title
            VStack {
                HStack {
                    Image("Protogen")
                        .resizable()
                        .scaledToFit()
                        .colorInvert()
                        .frame(width: 100, height: 100)
                    
                    Text("LumiFur")
                        .font(.title)
                        .fontDesign(.monospaced)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                }
                
                // Status Indicators and Signal Strength
                HStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "cellularbars")

                        Image(systemName: connectionWIFI ? "wifi": "wifi.slash")
                            .foregroundStyle(connectionWIFI ? .blue : .gray )
                        Image("Symbol")
                            .foregroundStyle(connectionBluetooth ? .blue : .gray )
                    }
                    .padding(.all, 10.0)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                }
                .offset(CGSize(width: 0.0, height: -40.0))
                
                // Grid of squares
                VStack {
                    HStack {
                        LedGridView()
                        LedGridView()
                    }
                    .padding([.leading, .bottom, .trailing])
                    ControlsGridView()
                    
                    Text("Actions")
                }
                
                // Settings Button
                HStack {
                    
                    Spacer()
                    
                    NavigationLink(destination: settingsView()) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                            .symbolRenderingMode(.multicolor)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .padding()
        .navigationTitle("LumiFur")
    }
}
    
    struct LedGridView: View {
        // Computed property to generate an array of random colors
            private var squares: [Color] {
                Array(repeating: Color.clear, count: 64).map { _ in randomColor() }
            }
        // Define the number of columns in the grid
        let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
        let spacing: CGFloat = 10 // Space between rows and columns
        
        var body: some View {
            
            LazyVGrid(columns: columns, spacing: 5) {  // Y Spacing
                ForEach(squares.indices, id: \.self) { index in
                    Rectangle()
                        .fill(squares[index])
                        .frame(width: 15, height: 15)
                        .cornerRadius(5)
                        //.blur(radius: /*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/) //Potential blur effect?
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
        }
    }
    // Function to generate a random color (red, green, or blue)
    private func randomColor() -> Color {
        let colors: [Color] = [.red, .green, .blue, .white]
        return colors.randomElement() ?? .clear
    }
    
let squareSize: CGFloat = 100
let spacingDesired: CGFloat = 20

// Define the grid layout with 2 rows
 let rows = [
     GridItem(.fixed(100), spacing: 20, alignment: .center), // Fixed size rows with desired spacing
     GridItem(.fixed(100), spacing: 20, alignment: .center)
 ]

struct ControlsGridView: View {
    
    let columns = [
        GridItem(spacing: spacingDesired, alignment: .center),
        GridItem(spacing: spacingDesired, alignment: .center)
    ]
    
    //Long Press Gesture
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    
    //Long press gesture
    var longPress: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .updating($isDetectingLongPress) { currentState, gestureState,
                transaction in
                gestureState = currentState
                transaction.animation = Animation.easeIn(duration: 1.0)
            }
            .onEnded { finished in
                self.completedLongPress = finished
            }
    }
    
    //Button States
    @State private var isActionPressed = false
    
    // State to track which button is pressed
    @State private var pressedButtonIndex: Int? = nil
    
    var body: some View {
        VStack {
            // Grid with 4 squares
            LazyHGrid(rows: rows, alignment: .center, spacing: spacingDesired) {
                ForEach(0..<4) { index in
                    Button(action: {
                        print("Button \(index + 1) Clicked")
                    }) {
                        RoundedRectangle(cornerRadius: 5.0)
                            .fill(.clear)
                            .overlay(
                                Text("Button \(index + 1)")
                                    .foregroundStyle(.primary)
                            )
                            .scaleEffect(pressedButtonIndex == index ? 0.8 : 1.0) // Scale down to 80% when pressed
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0),
                                value: pressedButtonIndex
                            )
                            .gesture(
                                TapGesture()
                                    .onEnded {
                                        // Set the pressed button index to the current button
                                        pressedButtonIndex = index
                                        
                                        // Reset the button state after a delay (to simulate pressing)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            pressedButtonIndex = nil
                                        }
                                    }
                            )
                    }
                    .scaleEffect(pressedButtonIndex == index ? 0.8 : 1.0) // Scale down to 80% when pressed
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0),
                        value: pressedButtonIndex
                    )
                    .gesture(
                        TapGesture()
                            .onEnded {
                                // Set the pressed button index to the current button
                                pressedButtonIndex = index
                                
                                // Reset the button state after a delay (to simulate pressing)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    pressedButtonIndex = nil
                                }
                            }
                    )
                    .buttonStyle(.bordered)
                    .frame(width: squareSize, height: squareSize)
                    //.border(Color.red)
                }
            }
        }
        .frame(width: .infinity, height: .infinity)
        .border(Color.white)
    }
}

    struct settingsView: View {
        
        //Connectivity Options
        enum Connection: String, CaseIterable, Identifiable {
            case bluetooth, wifi, matter, z_wave
            var id: Self { self }
        }
        
        //Matrix Options
        enum Matrixstyle: String, CaseIterable, Identifiable {
            case array, dot, wled
            var id: Self { self }
        }

        @State private var selectedConnection: Connection = .bluetooth
        @State private var selectedMatrix: Matrixstyle = .array

        
        var body: some View {
            VStack {
                
                    Text("Settings")
                        .font(.largeTitle)
                        .padding([.top, .bottom, .trailing])
                        .fontDesign(.monospaced)
                
                // Add your settings options here
                Text("Adjust your preferences here.")
                    .padding()
            
                // Connectivity List
                VStack {
                    Text("Connectivity")
                        .font(.title)
                    
                    List {
                        Picker("Connection", selection: $selectedConnection) {
                            Text("Wi-Fi").tag(Connection.wifi)
                            Text("Bluetooth").tag(Connection.bluetooth)
                            Text("Matter").tag(Connection.matter)
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(width: .infinity, height: 100)
                    
                    Text("Matrix style")
                        .font(.title)
                
                    List {
                        
                            LedGridView()

                            Picker("Matrix Style", selection: $selectedMatrix) {
                                Text("DOT").tag(Matrixstyle.dot)
                                Text("Array").tag(Matrixstyle.array)
                                Text("WLED").tag(Matrixstyle.wled)
                        }
                    }
                }
                Spacer()
                Spacer()
            }
            Spacer()
            //.navigationTitle("Settings") //navigationStack provides navigationTitle
            //.navigationBarTitleDisplayMode(.automatic)
        }
    }

#Preview {
    ContentView()
}
