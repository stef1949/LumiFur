//
//  splashView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/10/25.
//
import SwiftUI

struct SplashView: View {
    //Protogen hover effect
    @State private var fadeTitle: CGFloat = 20
    @State private var fadeSubtitle: CGFloat = 20
    @State private var yOffset: CGFloat = -10
    @State private var appearing: Bool = true
    @State private var animationDirection: Bool = true // True for moving up, false for moving down
    @Binding var showSplash: Bool
    let animationDuration: Double =  2.0 //Duration for full hover effect
    var body: some View {
        NavigationStack {
            ZStack {
                if #available(iOS 18.0, *) {
                    MeshGradientView()
                        .ignoresSafeArea()
                        .opacity(0.2)
                } else {
                    // Fallback on earlier versions
                }
                //.saturation(1.2)
                VStack {
                    // MARK: Image
                    ZStack {
                        Image("Image")
                            .renderingMode(.template)
                            .resizable()
                            .offset(y: yOffset)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                                    yOffset = animationDirection ? -20 : 20
                                }
                            }
                            .aspectRatio(contentMode: .fill)
                        //.opacity(0.5)
                        //.background(Material.ultraThin)
                            .clipped()
                            .frame(minWidth: 30, maxHeight: .infinity)
                            .border(.red)
                        // MARK: Upper text
                            .overlay(alignment: .topLeading) {
                                // Hero
                                VStack(alignment: .leading, spacing: 11) {
                                    // App Icon
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(width: 72, height: 72)
                                        .clipped()
                                        .shadow(color: Color(.sRGBLinear, red: 0/255, green: 0/255, blue: 0/255).opacity(0.12), radius: 8, x: 0, y: 4)
                                        .overlay {
                                            Image("LumiFurFrontSymbol")
                                                .imageScale(.large)
                                                .font(.system(size: 31, weight: .regular, design: .default))
                                                .onAppear()
                                        }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("LumiFur")
                                        //.font(.largeTitle)
                                            .font(Font.custom("Meloriac", size: 45))
                                        //.fontDesign(.monospaced)
                                        //.fontWeight(.heavy)
                                            .blur(radius: fadeTitle)
                                            .onAppear {
                                                withAnimation(Animation.easeInOut(duration: 2)) {
                                                    fadeTitle = appearing ? 0 : 20
                                                }
                                            }
                                        Text("The worlds Most Advanced Fursuit software")
                                            .font(.system(.headline, weight: .medium))
                                            .frame(width: 190, alignment: .leading)
                                            .clipped()
                                            .multilineTextAlignment(.leading)
                                            .shadow(radius: 5)
                                            .blur(radius: fadeSubtitle)
                                            .onAppear {
                                                withAnimation(Animation.easeInOut(duration: 2).delay(1)) {
                                                    fadeSubtitle = appearing ? 0 : 20
                                                }
                                            }
                                    }
                                }
                                .padding(30)
                            }
                        // MARK: Lower Icons
                            .overlay(alignment: .bottom) {
                                // Planes Visual
                                HStack {
                                    Spacer()
                                    ForEach(0..<5) { _ in // Replace with your data model here
                                        //Spacer()
                                        Image(systemName: "sun.max.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image("bluetooth.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "thermometer")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "move.3d")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "applewatch")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "widget.extralarge.badge.plus")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "powersleep")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "keyboard.badge.ellipsis.fill")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        Spacer()
                                        Image(systemName: "lines.measurement.vertical")
                                            .symbolRenderingMode(.hierarchical)
                                        //.foregroundStyle(Color(.quaternaryLabel))
                                        //Spacer()
                                    }
                                }
                                .frame(maxWidth: 300)
                                .clipped()
                                .padding()
                                //                                .background {
                                //                                    RoundedRectangle(cornerRadius: 15)
                                //                                        .fill(Color.secondary.opacity(0.25))
                                //                                        .padding(.horizontal, 12)
                                //                                }
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25))
                                .padding()
                            }
                        //.mask {RoundedRectangle(cornerRadius: 24, style: .continuous)}
                            .padding()
                            .mask {RoundedRectangle(cornerRadius: 24, style: .continuous)}
                            .shadow(color: Color(.sRGBLinear, red: 0/255, green: 0/255, blue: 0/255).opacity(0.15), radius: 18, x: 0, y: 14)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25))
                    .padding(30)
                    .frame(maxWidth: .infinity,maxHeight: 550)
                    
                    // MARK: Splash view button & about
                    VStack/*(spacing: 10)*/ {
                        // Button to dismiss the splash view.
                        /// MARK: Splash view butotn
                        Button("Continue", systemImage: "aqi.medium") {
                            withAnimation {
                                showSplash = false
                            }
                        }
                        //.buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .border (.green)
                        .padding(20)
                        .padding(.horizontal, 16)
                        .glassEffect()
                        /// MARK: Splash view button
                        //                        NavigationLink {
                        //                            InfoView()
                        //                        } label: {
                        //                            Label("About", systemImage: "info.circle")
                        //                        }
                        //                        .padding(.top)
                        //                        .foregroundStyle(.secondary)
                        //                        .font(.subheadline)
                        
                    }
                    .padding(.horizontal)
                    .border(.blue)
                    
                    Spacer()
                    
                }
            }
            .background(Color.white)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Consider moving Info link into the About section?
                    NavigationLink(destination: InfoView()) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        //.drawingGroup()
        //.compositingGroup()
    }
}

