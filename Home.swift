/**
 
 # Home
 
 The app entry point and main view.
 
 Achraf Kassioui
 Created 20 Jul 2026
 Updated 20 Jul 2026
 
 */
import SwiftUI
import SpriteKit

// MARK: App

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}

// MARK: Home View

struct AppView: View {
    @State private var scene = SoftShadowsScene(size: CGSize(width: 200, height: 200))
    @State private var selectedControl: Controls = .lightRadius
    
    enum Controls: String, CaseIterable, Identifiable {
        case lightRadius = "Light Radius"
        case lightFalloffRadius = "Light Falloff"
        case ambientLight = "Ambient"
        case directLight = "Light Intensity"
        case shadowOpacity = "Shadow Opacity"
        case shadowFadeDistance = "Shadow Fade Distance"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            AreaLightsRepresentable(scene: scene)
                .ignoresSafeArea()
                .background(.black)
            
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    Toggle(isOn: $scene.showShadowMask) {
                        Text("Shadow Mask")
                            .foregroundStyle(.blue)
                    }
                    .fixedSize()
                    
                    Toggle("Light A", isOn: $scene.firstLightEnabled)
                        .fixedSize()
                    
                    ColorPicker("Light A", selection: colorBinding(\.firstLightColor))
                        .labelsHidden()
                        .fixedSize()
                    
                    Toggle("Light B", isOn: $scene.secondLightEnabled)
                        .fixedSize()
                    
                    ColorPicker("Light B", selection: colorBinding(\.secondLightColor))
                        .labelsHidden()
                        .fixedSize()
                    
                    ColorPicker("Caster", selection: colorBinding(\.casterColor))
                        .labelsHidden()
                        .fixedSize()
                    
                    ColorPicker("Receiver", selection: colorBinding(\.receiverColor))
                        .labelsHidden()
                        .fixedSize()
                    
                    Picker("Control", selection: $selectedControl) {
                        ForEach(Controls.allCases) { control in
                            Text(control.rawValue)
                                .tag(control)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    
                    selectedSlider
                        .frame(width: 220)
                }
                .padding()
            }
        }
    }
    
    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<SoftShadowsScene, SKColor>) -> Binding<Color> {
        Binding(
            get: {
                Color(scene[keyPath: keyPath])
            },
            set: {
                scene[keyPath: keyPath] = SKColor($0)
            }
        )
    }
    
    @ViewBuilder
    private var selectedSlider: some View {
        switch selectedControl {
        case .lightRadius:
            Slider(value: $scene.lightRadius, in: 0...120)
            
        case .lightFalloffRadius:
            Slider(value: $scene.lightFalloffRadius, in: 80...1400)
            
        case .ambientLight:
            Slider(value: $scene.ambientLight, in: 0...1)
            
        case .directLight:
            Slider(value: $scene.directLight, in: 0...3)
            
        case .shadowOpacity:
            Slider(value: $scene.shadowOpacity, in: 0...1)
            
        case .shadowFadeDistance:
            Slider(value: $scene.shadowFadeDistance, in: 0...128)
        }
    }
}

struct AreaLightsRepresentable: UIViewRepresentable {
    let scene: SoftShadowsScene
    
    func makeUIView(context: Context) -> MetalView {
        MetalView(scene: scene)
    }
    
    func updateUIView(_ metalView: MetalView, context: Context) {
        
    }
}
