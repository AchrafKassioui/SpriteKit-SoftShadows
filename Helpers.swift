/**
 
 # Helpers
 
 Achraf Kassioui
 Created 6 Jul 2026
 Updated 20 Jul 2026
 
 */
import SpriteKit
import SwiftUI

// MARK: Texture Generators

/// Radial white-to-transparent texture.
func generateRadialGradientTexture(size: CGSize) -> SKTexture {
    let renderer = UIGraphicsImageRenderer(size: size)
    
    let image = renderer.image { context in
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let outerRadius = min(size.width, size.height) * 0.5
        
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        ) else { return }
        
        context.cgContext.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 12,
            endCenter: center,
            endRadius: outerRadius,
            options: [.drawsBeforeStartLocation]
        )
    }
    
    return SKTexture(image: image)
}

// MARK: Hex Color

private func hexColorComponents(_ hex: String) -> (red: Double, green: Double, blue: Double) {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
    
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)
    
    return (
        red:   Double((value >> 16) & 0xFF) / 255,
        green: Double((value >>  8) & 0xFF) / 255,
        blue:  Double( value        & 0xFF) / 255
    )
}

extension SKColor {
    
    /// Create a color from a hexadecimal RGB string, for example `"66CCCC"` or `"#66CCCC"`.
    convenience init(hex: String, alpha: CGFloat = 1) {
        let components = hexColorComponents(hex)
        
        self.init(
            red: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: alpha
        )
    }
    
}

extension Color {
    
    /// Create a color from a hexadecimal RGB string, for example `"66CCCC"` or `"#66CCCC"`.
    init(hex: String, alpha: Double = 1) {
        let components = hexColorComponents(hex)
        
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: alpha
        )
    }
    
}

extension SKColor {
    
    /// Preserves a SwiftUI color in the Display P3 color space for SpriteKit.
    convenience init(displayP3 color: Color) {
        let sourceColor = SKColor(color).cgColor
        let displayP3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        
        guard
            let displayP3Color = sourceColor.converted(
                to: displayP3ColorSpace,
                intent: .relativeColorimetric,
                options: nil
            ),
            let components = displayP3Color.components,
            components.count >= 4
                else {
            self.init(color)
            return
        }
        
        self.init(
            displayP3Red: components[0],
            green: components[1],
            blue: components[2],
            alpha: components[3]
        )
    }
}
