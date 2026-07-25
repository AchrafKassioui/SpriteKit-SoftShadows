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
    /// ID to reset the view and the scene
    @State private var viewID = UUID()
    
    var body: some Scene {
        WindowGroup {
            ControlView(reset: {
                viewID = UUID()
            })
            .id(viewID)
        }
    }
}

// MARK: Control View

struct ControlView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var scene = SoftShadowsScene(size: CGSize(width: 200, height: 200))
    
    let reset: () -> Void
    
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
            ControlPanel(scene: scene, reset: reset)
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
    
    /// Custom layout for narrow screens.
    @ViewBuilder
    private var mobileView: some View {
        /// iPhone landscape
        if verticalSizeClass == .compact {
            HStack(spacing: 0) {
                ControlPanel(scene: scene, reset: reset)
                    .frame(width: 300)
                
                Divider()
                
                sceneView
            }
        /// iPhone portrait
        } else {
            VStack(spacing: 0) {
                sceneView
                
                Divider()
                
                ControlPanel(scene: scene, reset: reset)
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

struct AreaLightsRepresentable: UIViewRepresentable {
    let scene: SoftShadowsScene
    
    func makeUIView(context: Context) -> MetalView {
        MetalView(scene: scene)
    }
    
    func updateUIView(_ metalView: MetalView, context: Context) {
        
    }
}

// MARK: Control Panel

private struct ControlPanel: View {
    @Bindable var scene: SoftShadowsScene
    let reset: () -> Void
    
    var body: some View {
        List {
            LightsSection
            ColorsSection
            LightingSection
            
            Section {
                Button(action: reset) {
                    Label(
                        "Reset App",
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.defaultMinListRowHeight, 36)
    }
    
    private var LightsSection: some View {
        Section {
            LightControl(
                title: "Light A",
                intensity: $scene.firstLightIntensity,
                color: $scene.firstLightColor,
                defaultIntensity: RenderingDefaults.lightIntensity,
                defaultColor: RenderingDefaults.firstLightColor
            )
            
            LightControl(
                title: "Light B",
                intensity: $scene.secondLightIntensity,
                color: $scene.secondLightColor,
                defaultIntensity: RenderingDefaults.lightIntensity,
                defaultColor: RenderingDefaults.secondLightColor
            )
        } header: {
            Label("Lights", systemImage: "lightbulb.2.fill")
        }
    }
    
    private var ColorsSection: some View {
        Section {
            ColorControl(
                title: "Shape Color",
                color: $scene.casterColor,
                defaultColor: RenderingDefaults.shapeColor
            )
            
            ColorControl(
                title: "Background Color",
                color: $scene.receiverColor,
                defaultColor: RenderingDefaults.backgroundColor
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
            
            /// Show the shadow mask before lighting is composited.
            Toggle("Show Shadow Mask", isOn: $scene.showShadowMask)
            
        } header: {
            Label("Lighting", systemImage: "slider.horizontal.3")
        }
    }
}

// MARK: Light Control

private struct LightControl: View {
    let title: String
    
    @Binding var intensity: Double
    @Binding var color: Color
    
    let defaultIntensity: Double
    let defaultColor: Color
    
    /// Whether both light settings have their initial values.
    private var isAtDefault: Bool {
        intensity == defaultIntensity && color == defaultColor
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text(
                    intensity.formatted(
                        .number
                            .locale(Locale(identifier: "en_US_POSIX"))
                            .precision(.fractionLength(2))
                    )
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                
                Button {
                    intensity = defaultIntensity
                    color = defaultColor
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 24)
                }
                .buttonStyle(.borderless)
                .disabled(isAtDefault)
                .accessibilityLabel("Reset \(title)")
            }
            
            HStack(spacing: 12) {
                Slider(value: $intensity, in: 0...3)
                
                ColorPicker(
                    "\(title) Color",
                    selection: $color,
                    supportsOpacity: false
                )
                .labelsHidden()
                .frame(width: 24)
            }
        }
    }
}

// MARK: Color Control

private struct ColorControl: View {
    let title: String
    
    @Binding var color: Color
    let defaultColor: Color
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            Button {
                color = defaultColor
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24)
            }
            .buttonStyle(.borderless)
            .disabled(color == defaultColor)
            .accessibilityLabel("Reset \(title)")
            
            ColorPicker(
                "\(title) Color",
                selection: $color,
                supportsOpacity: false
            )
            .labelsHidden()
        }
    }
}

// MARK: Slider

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
