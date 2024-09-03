//
//  ContentView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 03/09/2024.
//

import SwiftUI

struct SplashView: View {
    
    @State var isActive: Bool = false
    
    var body: some View {
        ZStack {
            if self.isActive {
                ContentView()
            } else {
                //Rectangle()
                //  .background(Color.black)
                VStack {
                    Image("Protogen")
                        .resizable()
                        .scaledToFit()
                        .frame(width: .infinity, height: .infinity)
                    
                    Image(systemName: "light.ribbon")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .padding()
                    Text("Welcome to LumiFur")
                        .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 40) // Adjust as needed
                }
                .padding()
                
            }
        }
    }
}

struct ContentView: View {
    
    // Computed property to generate an array of random colors
        private var squares: [Color] {
            Array(repeating: Color.clear, count: 64).map { _ in randomColor() }
        }
    
    // Define the number of columns in the grid
    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 0), count: 8)
    let spacing: CGFloat = 10 // Space between rows and columns
    
    var body: some View {
        
        //Title
        VStack {
            HStack {
                Image("Protogen")
                    .resizable()
                    .scaledToFit()
                    .colorInvert()
                    .frame(width: 100, height: 100)
                
                Text("LumiFur")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .fontDesign(.rounded)
                    .padding()
            }
            
            Spacer()
            
            // Grid of squares
            LazyVGrid(columns: columns, spacing: 5) {  // Y Spacing
                ForEach(squares.indices, id: \.self) { index in
                    Rectangle()
                        .fill(squares[index])
                        .frame(width: 20, height: 20)
                        .cornerRadius(5)
                    // .blur(radius: /*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/) //Potential blur effect?
                }
            }
            .padding(.top, spacing)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
            Spacer()
            
            // Settings Button
            NavigationLink(destination: settingsPage()) {
                Text("Settings")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("LumiFur")
    }

    // Function to generate a random color (red, green, or blue)
    private func randomColor() -> Color {
        let colors: [Color] = [.red, .green, .blue, .white]
        return colors.randomElement() ?? .clear
    }
    
    struct settingsPage: View {
        var body: some View {
            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                
                // Add your settings options here
                Text("Adjust your preferences here.")
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
        }
    }
}
#Preview {
    ContentView()
}
