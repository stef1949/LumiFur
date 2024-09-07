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

// IOS 18.0 features
//import AccessorySetupKit


struct SplashView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var overlayColor: Color {
        colorScheme == .dark ? .black : .white
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


struct ContentView: View {
    //Environment Variables
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var sharedViewModel: SharedViewModel
    
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
    @State private var selectedMatrix: SettingsView.Matrixstyle = .array
    
    private let twoColumnGrid = [
        GridItem(.flexible(minimum: 40)),
        GridItem(.flexible(minimum: 40)),
        //GridItem(.flexible(minimum: 40)),
    ]
    
    // Array of SF Symbol names
    private var protoAction: [String] = ["mic.and.signal.meter.fill", "headlight.low.beam.fill", "sensor.fill", "bell"]
   
    //dotMatrix variable
    @State private var dotMatrices: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)
    
    @State private var errorMessage: String? = nil
    
    //Protogen image variables
    @State private var yOffset: CGFloat = 0
        private let animationDuration: Double = 1.0
    
    var overlayColor: Color {
            colorScheme == .dark ? .gray : .white
        }
    
    var body: some View {
        NavigationStack {
            
            //Title
            VStack {
                HStack {
                    // Use the common utility function to display and animate the image
                                animatedProtogenImage(yOffset: $yOffset, animationDirection: true, animationDuration: animationDuration)
                        
                        .border(Color.red)
                        .scaledToFill()
                        .frame(height: 100)
                        .offset(CGSize(width: 0.0, height: 30.0))
                    
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
                
                HStack {
                    
                    Spacer()
                    
                    if let videoURL = Bundle.main.url(forResource: "blinking", withExtension: "mp4") {
                        VideoDotMatrixView(videoURL: videoURL)
                    } else {
                        Text("Error: Video file not found.")
                            .foregroundColor(.red)
                    }
                    
                    if let videoURL = Bundle.main.url(forResource: "blinking", withExtension: "mp4") {
                        VideoDotMatrixView(videoURL: videoURL)
                    } else {
                        Text("Error: Video file not found.")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                }
                
                Spacer()
                
                // Grid of squares
                LazyVGrid(columns: twoColumnGrid, alignment: .center) {
                    ForEach(protoAction , id: \.self) { item in
                        GeometryReader { gr in
                            Button(action: {
                                // Define the action for the button here
                                print("\(item) button pressed")
                            }) {
                                Image(systemName: item)
                                    .imageScale(.large)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Makes the image fill the available space
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .frame(width: 125)
                    }
                }
                .border(Color.yellow)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                
                
                // Settings Button
                HStack {
                    
                    Spacer()
                    
                    
                    NavigationLink(destination: SettingsView(selectedMatrix: $selectedMatrix)) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                            .symbolRenderingMode(.multicolor)
                    }
                    .padding()
                }
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
    
    struct SettingsView: View {
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
        @Binding var selectedMatrix: Matrixstyle

        
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
                    .frame(maxWidth: .infinity)
                    
                    Text("Matrix style")
                        .font(.title)
                
                    List {
                        HStack {
                            Spacer()
                            if let videoURL = Bundle.main.url(forResource: "blinking", withExtension: "mp4") {
                                VideoDotMatrixView(videoURL: videoURL)
                            } else {
                                Text("Error: Video file not found.")
                                    .foregroundColor(.red)
                            }
                            Spacer()
                                
                        }
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

struct VideoDotMatrixView: View {
    let videoURL: URL
    @State private var dotMatrix: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                DotMatrixView(matrix: dotMatrix)
            }
        }
        .onAppear {
            Task {
                do {
                    // Check if the file exists
                    guard FileManager.default.fileExists(atPath: videoURL.path) else {
                        throw VideoProcessingError.fileNotFound
                    }
                    
                    // Extract frames
                    let frames = try await extractFrames(from: videoURL)
                    
                    // Process the first frame only
                    if let firstFrame = frames.first {
                        guard let downscaled = downscaleImageTo8x8(firstFrame) else {
                            throw VideoProcessingError.imageDownscaleFailed
                        }
                        guard let matrix = convertImageToDotMatrix(downscaled) else {
                            throw VideoProcessingError.imageConversionFailed
                        }
                        // Assign the first matrix to the state
                        self.dotMatrix = matrix
                    }
                } catch {
                    // Handle errors
                    self.errorMessage = (error as? VideoProcessingError)?.localizedDescription ?? "An unknown error occurred."
                    print("Error processing video: \(error)")
                }
            }
        }
    }
}

enum VideoProcessingError: LocalizedError {
    case fileNotFound
    case frameExtractionFailed
    case imageDownscaleFailed
    case imageConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The video file was not found."
        case .frameExtractionFailed:
            return "Failed to extract frames from the video."
        case .imageDownscaleFailed:
            return "Failed to downscale the image."
        case .imageConversionFailed:
            return "Failed to convert the image to a dot matrix."
        }
    }
}

func extractFrames(from url: URL) async throws -> [CIImage] {
    let asset = AVAsset(url: url)
    let assetGenerator = AVAssetImageGenerator(asset: asset)
    assetGenerator.appliesPreferredTrackTransform = true

    let duration = try await asset.load(.duration)
    let totalSeconds = CMTimeGetSeconds(duration)
    let times = stride(from: 0.0, to: totalSeconds, by: 0.1).map { CMTime(seconds: $0, preferredTimescale: 600) }

    var frames: [CIImage] = []

    for time in times {
        do {
            let cgImage = try assetGenerator.copyCGImage(at: time, actualTime: nil)
            let ciImage = CIImage(cgImage: cgImage)
            frames.append(ciImage)
        } catch {
            throw VideoProcessingError.frameExtractionFailed
        }
    }

    return frames
}

func downscaleImageTo8x8(_ ciImage: CIImage) -> CIImage? {
    let size = CGSize(width: 8, height: 8)  // Adjusted size for 8x8 matrix
    let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
    scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
    scaleFilter.setValue(size.width / ciImage.extent.width, forKey: kCIInputScaleKey)
    scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

    return scaleFilter.outputImage
}

func convertImageToDotMatrix(_ ciImage: CIImage) -> [[Bool]]? {
    var matrix: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)
    let context = CIContext()
    
    // Get CGImage from CIImage
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        return nil
    }
    
    // Access pixel data
    guard let cgImageData = cgImage.dataProvider?.data else { return nil }
    let data = CFDataGetBytePtr(cgImageData)
    
    // Assuming each pixel is represented by 4 bytes (RGBA)
    let bytesPerPixel = 4
    let bytesPerRow = cgImage.bytesPerRow
    
    // Compute width and height
    let width = 8
    let height = 8
    
    // Loop through each pixel in the 8x8 grid
    for y in 0..<height {
        for x in 0..<width {
            let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
            let r = CGFloat(data![pixelIndex]) / 255.0
            let g = CGFloat(data![pixelIndex + 1]) / 255.0
            let b = CGFloat(data![pixelIndex + 2]) / 255.0
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            
            // Set pixel value based on threshold
            matrix[y][x] = gray > 0.9 ? false : true
        }
    }
    
    return matrix
}

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
                    HStack(spacing: 1) {
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


#Preview {
    ContentView()
}
