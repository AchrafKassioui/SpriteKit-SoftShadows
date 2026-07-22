/**
 
 # Helpers
 
 Achraf Kassioui
 Created 6 Jul 2026
 Updated 20 Jul 2026
 
 */
import SpriteKit

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
