/**
 
 # App & UI
 
 The app entry point and the demo user interface.
 
 Achraf Kassioui
 Created 20 Jul 2026
 Updated 22 Jul 2026
 
 */
import SwiftUI
import SpriteKit

// MARK: App

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ControlView()
        }
    }
}

// MARK: Control View

struct ControlView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var scene = SoftShadowsScene(size: CGSize(width: 200, height: 200))
    
    var body: some View {
        if horizontalSizeClass == .compact {
            mobileView
        } else {
            desktopView
        }
    }
    
    /// Default system sidebar for wide screens.
    private var desktopView: some View {
        NavigationSplitView {
            ControlPanel(scene: scene)
                .navigationTitle("Controls")
                .navigationSplitViewColumnWidth(
                    min: 240,
                    ideal: 320,
                    max: 480
                )
        } detail: {
            sceneView
        }
        .navigationSplitViewStyle(.automatic)
    }
    
    /// Mobile layout for narrow screens.
    @ViewBuilder
    private var mobileView: some View {
        /// iPhone landscape
        if verticalSizeClass == .compact {
            HStack(spacing: 0) {
                ControlPanel(scene: scene)
                    .frame(width: 300)
                
                //Divider()
                
                sceneView
            }
        /// iPhone portrait
        } else {
            VStack(spacing: 0) {
                sceneView
                
                //Divider()
                
                ControlPanel(scene: scene)
                    .frame(height: 280)
            }
        }
    }
    
    /// Metal view with SpriteKit scene.
    private var sceneView: some View {
        AreaLightsRepresentable(scene: scene)
            .ignoresSafeArea()
            .background(.black)
    }
}

// MARK: Panel

private struct ControlPanel: View {
    @Bindable var scene: SoftShadowsScene
    
    var body: some View {
        List {
            LightsSection
            ColorsSection
            LightingSection
        }
        .environment(\.defaultMinListRowHeight, 36)
    }
    
    private var LightsSection: some View {
        Section {
            LightControl(
                title: "Light A",
                color: colorBinding(\.firstLightColor),
                isEnabled: $scene.firstLightEnabled
            )
            
            LightControl(
                title: "Light B",
                color: colorBinding(\.secondLightColor),
                isEnabled: $scene.secondLightEnabled
            )
            
            Toggle("Show Shadow Mask", isOn: $scene.showShadowMask)
        } header: {
            Label("Switches", systemImage: "lightswitch.on")
        }
    }
    
    private var ColorsSection: some View {
        Section {
            ColorControl(
                title: "Shape Color",
                color: colorBinding(\.casterColor)
            )
            
            ColorControl(
                title: "Background Color",
                color: colorBinding(\.receiverColor)
            )
        } header: {
            Label("Scene", systemImage: "paintpalette.fill")
        }
    }
    
    private var LightingSection: some View {
        Section {
            SliderControl(
                title: "Light Radius",
                value: $scene.lightRadius,
                defaultValue: RenderingDefaults.lightRadius,
                range: 0...120,
                decimalPlaces: 0
            )
            
            SliderControl(
                title: "Light Falloff",
                value: $scene.lightFalloffRadius,
                defaultValue: RenderingDefaults.lightFalloffRadius,
                range: 80...1400,
                decimalPlaces: 0
            )
            
            SliderControl(
                title: "Ambient Light",
                value: $scene.ambientLight,
                defaultValue: RenderingDefaults.ambientLight,
                range: 0...1,
                decimalPlaces: 2
            )
            
            SliderControl(
                title: "Light Intensity",
                value: $scene.directLight,
                defaultValue: RenderingDefaults.directLight,
                range: 0...3,
                decimalPlaces: 2
            )
            
            SliderControl(
                title: "Shadow Opacity",
                value: $scene.shadowOpacity,
                defaultValue: RenderingDefaults.shadowOpacity,
                range: 0...1,
                decimalPlaces: 2
            )
            
            SliderControl(
                title: "Shadow Fade-In Distance",
                value: $scene.shadowFadeDistance,
                defaultValue: RenderingDefaults.shadowFadeDistance,
                range: 0...128,
                decimalPlaces: 0
            )
            
        } header: {
            Label("Lighting", systemImage: "slider.horizontal.3")
        }
    }
    
    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<SoftShadowsScene, SKColor>) -> Binding<Color> {
        Binding(
            get: {
                Color(scene[keyPath: keyPath])
            },
            set: { color in
                scene[keyPath: keyPath] = SKColor(color)
            }
        )
    }
}

// MARK: Controls

private struct LightControl: View {
    let title: String
    
    @Binding var color: Color
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle(title, isOn: $isEnabled)
            
            ColorPicker(
                "\(title) Color",
                selection: $color,
                supportsOpacity: false
            )
            .labelsHidden()
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

private struct ColorControl: View {
    let title: String
    
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            ColorPicker(
                "\(title) Color",
                selection: $color,
                supportsOpacity: false
            )
            .labelsHidden()
        }
    }
}

private struct SliderControl: View {
    let title: String
    
    @Binding var value: Double
    
    let defaultValue: Double
    let range: ClosedRange<Double>
    let decimalPlaces: Int
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                /// Technical values always use a decimal point.
                Text(
                    value.formatted(
                        .number
                            .locale(Locale(identifier: "en_US_POSIX"))
                            .precision(.fractionLength(decimalPlaces))
                    )
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                
                Button {
                    value = defaultValue
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(value == defaultValue)
                .accessibilityLabel("Reset \(title)")
            }
            
            Slider(value: $value, in: range)
        }
    }
}

// MARK: Metal View

struct AreaLightsRepresentable: UIViewRepresentable {
    let scene: SoftShadowsScene
    
    func makeUIView(context: Context) -> MetalView {
        MetalView(scene: scene)
    }
    
    func updateUIView(_ metalView: MetalView, context: Context) {
        
    }
}
