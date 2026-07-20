//
//  scene.swift
//  MyApp
//
//  Created by Achraf Kassioui on 20/7/2026.
//
import SpriteKit
import SwiftUI

// MARK: Scene

@Observable
class AreaLightsScene: SKScene {
    
    // MARK: Properties
    
    private let contentLayer = SKNode()
    private var shadowCasters: [ShadowCaster] = []
    private var backgroundNode: SKSpriteNode?
    
    struct ShadowCaster {
        let node: SKShapeNode
        
        /// Convex outline in local space, wound counter-clockwise.
        let vertices: [CGPoint]
    }
    
    private var activeDrags: [UITouch: DragState] = [:]
    
    struct DragState {
        let node: SKNode
        let offset: CGPoint
    }
    
    // MARK: Rendering Knobs
    
    var firstLight = SKNode()
    var secondLight = SKNode()
    
    private let minimumLightTouchSize: CGFloat = 44
    private let lightVisualName = "lightVisual"
    private let lightHitAreaName = "lightHitArea"
    
    /// Controls whether the first light emits light and shadows.
    var firstLightEnabled = true {
        didSet {
            firstLight.isHidden = !firstLightEnabled
        }
    }
    
    /// Controls whether the second light emits light and shadows.
    var secondLightEnabled = true {
        didSet {
            secondLight.isHidden = !secondLightEnabled
        }
    }
    
    /// First direct light color.
    var firstLightColor: SKColor = .systemYellow {
        didSet {
            updateLights()
        }
    }
    
    /// Second direct light color.
    var secondLightColor: SKColor = .systemCyan {
        didSet {
            updateLights()
        }
    }
    
    /// Area light radius used by the soft shadow projection.
    var lightRadius: Double = 32 {
        didSet {
            updateLights()
        }
    }
    
    /// Distance where direct light fades out.
    var lightFalloffRadius: Double = 750
    
    /// Base light everywhere, even in shadow.
    var ambientLight: Double = 0.35
    
    /// Extra light near each light source.
    var directLight: Double = 0.9
    
    /// Final strength of shadow masks.
    var shadowOpacity: Double = 0.8
    
    /// Shadow caster color.
    var casterColor: SKColor = .systemRed {
        didSet {
            shadowCasters.forEach { shadowCaster in
                shadowCaster.node.fillColor = casterColor
            }
        }
    }
    
    /// Background color.
    var receiverColor: SKColor = .gray {
        didSet {
            backgroundNode?.color = receiverColor
        }
    }
    
    /// Shows the raw shadow mask instead of the final composite.
    var showShadowMask = false
    
    /// Distance in points between light circle and shadow caster at which shadow begins to fade
    var shadowFadeDistance: Double = 128
    
    // MARK: Lifecycle
    
    override init(size: CGSize) {
        super.init(size: size)
        
        scaleMode = .resizeFill
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        createContent()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Content
    
    private func createContent() {
        addChild(contentLayer)
        
        /// Lights.
        firstLight = makeLight(position: CGPoint(x: -320, y: 180))
        secondLight = makeLight(position: CGPoint(x: 320, y: -140))
        
        contentLayer.addChild(firstLight)
        contentLayer.addChild(secondLight)
        
        updateLights()
        
        /// Background.
        let background = SKSpriteNode(color: receiverColor, size: CGSize(width: 2000, height: 2000))
        background.zPosition = 0
        contentLayer.addChild(background)
        backgroundNode = background
        
        /// Shadow casters.
        createGrid(casterNumbers: 1...12)
    }
    
    /// Creates a centered grid containing different convex caster shapes.
    private func createGrid(casterNumbers: ClosedRange<Int>) {
        let casterCount = casterNumbers.count
        let columns = Int(ceil(sqrt(Double(casterCount))))
        let rows = Int(ceil(Double(casterCount) / Double(columns)))
        let casterSpacing: CGFloat = 150
        
        let gridWidth = CGFloat(columns - 1) * casterSpacing
        let gridHeight = CGFloat(rows - 1) * casterSpacing
        
        for casterNumber in casterNumbers {
            let casterIndex = casterNumber - casterNumbers.lowerBound
            let column = casterIndex % columns
            let row = casterIndex / columns
            
            let shadowCaster: ShadowCaster
            
            /// Cycle through outlines that exercise different shadow geometries.
            switch casterIndex % 6 {
            case 0:
                shadowCaster = makeRoundedRectangleShadowCaster(
                    size: CGSize(width: 75, height: 75),
                    cornerRadius: 12,
                    cornerPoints: 4
                )
                
            case 1:
                shadowCaster = makeRegularPolygonShadowCaster(
                    sides: 3,
                    radius: 48,
                    rotation: -.pi * 0.5
                )
                
            case 2:
                shadowCaster = makeRegularPolygonShadowCaster(
                    sides: 4,
                    radius: 48,
                    rotation: .pi * 0.25
                )
                
            case 3:
                shadowCaster = makeRegularPolygonShadowCaster(
                    sides: 6,
                    radius: 44,
                    rotation: 0
                )
                
            case 4:
                shadowCaster = makeEllipseShadowCaster(
                    size: CGSize(width: 82, height: 82),
                    vertexCount: 32
                )
                
            default:
                shadowCaster = makeEllipseShadowCaster(
                    size: CGSize(width: 92, height: 58),
                    vertexCount: 32
                )
            }
            
            let casterNode = shadowCaster.node
            casterNode.name = "draggable"
            
            /// Center the grid around the scene origin.
            casterNode.position = CGPoint(
                x: CGFloat(column) * casterSpacing - gridWidth * 0.5,
                y: CGFloat(row) * casterSpacing - gridHeight * 0.5
            )
            
            casterNode.zPosition = 20
            contentLayer.addChild(casterNode)
            shadowCasters.append(shadowCaster)
        }
    }
    
    // MARK: Lights
    
    private func makeLight(position: CGPoint) -> SKNode {
        let light = SKNode()
        light.name = "draggable"
        light.position = position
        light.zPosition = 100
        
        /// Visible light radius.
        let lightVisual = SKSpriteNode(texture: generateRadialGradientTexture(size: CGSize(width: 44, height: 44)))
        lightVisual.name = lightVisualName
        lightVisual.zPosition = 1
        lightVisual.alpha = 0.5
        light.addChild(lightVisual)
        
        /// Drag area.
        let lightHitArea = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.001),
            size: CGSize(width: minimumLightTouchSize, height: minimumLightTouchSize)
        )
        lightHitArea.name = lightHitAreaName
        lightHitArea.zPosition = 2
        light.addChild(lightHitArea)
        
        return light
    }
    
    private func updateLights() {
        updateLight(firstLight, color: firstLightColor)
        updateLight(secondLight, color: secondLightColor)
    }
    
    private func updateLight(_ light: SKNode, color: SKColor) {
        let visualSize = max(CGFloat(lightRadius) * 2, 1)
        let touchSize = max(visualSize, minimumLightTouchSize)
        
        /// Show the actual light radius.
        if let lightVisual = light.childNode(withName: lightVisualName) as? SKSpriteNode {
            lightVisual.size = CGSize(width: visualSize, height: visualSize)
            lightVisual.color = color
            lightVisual.colorBlendFactor = 1
        }
        
        /// Keep dragging easy when the visible light is tiny.
        if let lightHitArea = light.childNode(withName: lightHitAreaName) as? SKSpriteNode {
            lightHitArea.size = CGSize(width: touchSize, height: touchSize)
        }
    }
    
    // MARK: Shapes
    
    /// Creates a visible caster and its matching shadow outline.
    private func makeShadowCaster(vertices: [CGPoint]) -> ShadowCaster {
        let shapeNode = SKShapeNode(path: makePath(from: vertices))
        shapeNode.fillColor = casterColor
        shapeNode.strokeColor = .black.withAlphaComponent(0.3)
        shapeNode.lineWidth = 1
        
        return ShadowCaster(
            node: shapeNode,
            vertices: vertices
        )
    }
    
    /// Creates a rounded rectangle caster.
    private func makeRoundedRectangleShadowCaster(size: CGSize, cornerRadius: CGFloat, cornerPoints: Int) -> ShadowCaster {
        makeShadowCaster(
            vertices: roundedRectangleVertices(
                size: size,
                cornerRadius: cornerRadius,
                cornerPoints: cornerPoints
            )
        )
    }
    
    /// Creates a regular polygon caster.
    private func makeRegularPolygonShadowCaster(sides: Int, radius: CGFloat, rotation: CGFloat = 0) -> ShadowCaster {
        makeShadowCaster(
            vertices: regularPolygonVertices(
                sides: sides,
                radius: radius,
                rotation: rotation
            )
        )
    }
    
    /// Creates an elliptical caster from a polygonal outline.
    private func makeEllipseShadowCaster(size: CGSize, vertexCount: Int) -> ShadowCaster {
        makeShadowCaster(
            vertices: ellipseVertices(
                size: size,
                vertexCount: vertexCount
            )
        )
    }
    
    /// Generates a counter-clockwise rounded rectangle outline.
    private func roundedRectangleVertices(size: CGSize, cornerRadius: CGFloat, cornerPoints: Int) -> [CGPoint] {
        let halfWidth = size.width * 0.5
        let halfHeight = size.height * 0.5
        let pointCount = max(cornerPoints, 1)
        let radius = min(cornerRadius, halfWidth, halfHeight)
        
        guard radius > 0, pointCount > 1 else {
            return rectangleVertices(size: size)
        }
        
        let cornerCenters = [
            CGPoint(x:  halfWidth - radius, y: -halfHeight + radius),
            CGPoint(x:  halfWidth - radius, y:  halfHeight - radius),
            CGPoint(x: -halfWidth + radius, y:  halfHeight - radius),
            CGPoint(x: -halfWidth + radius, y: -halfHeight + radius)
        ]
        
        let cornerAngleRanges: [(start: CGFloat, end: CGFloat)] = [
            (-CGFloat.pi * 0.5, 0),
            (0, CGFloat.pi * 0.5),
            (CGFloat.pi * 0.5, CGFloat.pi),
            (CGFloat.pi, CGFloat.pi * 1.5)
        ]
        
        var vertices: [CGPoint] = []
        vertices.reserveCapacity(cornerCenters.count * pointCount)
        
        for cornerIndex in cornerCenters.indices {
            let cornerCenter = cornerCenters[cornerIndex]
            let angleRange = cornerAngleRanges[cornerIndex]
            
            /// More points produce a smoother corner.
            for pointIndex in 0..<pointCount {
                let progress = CGFloat(pointIndex) / CGFloat(pointCount - 1)
                let angle =
                angleRange.start
                + (angleRange.end - angleRange.start) * progress
                
                vertices.append(
                    CGPoint(
                        x: cornerCenter.x + cos(angle) * radius,
                        y: cornerCenter.y + sin(angle) * radius
                    )
                )
            }
        }
        
        return vertices
    }
    
    /// Generates a counter-clockwise rectangle outline.
    private func rectangleVertices(size: CGSize) -> [CGPoint] {
        let halfWidth = size.width * 0.5
        let halfHeight = size.height * 0.5
        
        return [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x:  halfWidth, y: -halfHeight),
            CGPoint(x:  halfWidth, y:  halfHeight),
            CGPoint(x: -halfWidth, y:  halfHeight)
        ]
    }
    
    /// Generates a counter-clockwise regular polygon outline.
    private func regularPolygonVertices(sides: Int, radius: CGFloat, rotation: CGFloat = 0) -> [CGPoint] {
        let sideCount = max(sides, 3)
        
        return (0..<sideCount).map { vertexIndex in
            let progress = CGFloat(vertexIndex) / CGFloat(sideCount)
            let angle = rotation + progress * CGFloat.pi * 2
            
            return CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
        }
    }
    
    /// Generates a counter-clockwise elliptical outline.
    private func ellipseVertices(size: CGSize, vertexCount: Int) -> [CGPoint] {
        let pointCount = max(vertexCount, 8)
        let horizontalRadius = size.width * 0.5
        let verticalRadius = size.height * 0.5
        
        return (0..<pointCount).map { vertexIndex in
            let progress = CGFloat(vertexIndex) / CGFloat(pointCount)
            let angle = progress * CGFloat.pi * 2
            
            return CGPoint(
                x: cos(angle) * horizontalRadius,
                y: sin(angle) * verticalRadius
            )
        }
    }
    
    /// Builds the visible path from the caster's shadow vertices.
    private func makePath(from vertices: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        
        guard let firstVertex = vertices.first else {
            return path
        }
        
        /// Draw the same polygon used by the shadow code.
        path.move(to: firstVertex)
        
        for vertex in vertices.dropFirst() {
            path.addLine(to: vertex)
        }
        
        path.closeSubpath()
        return path
    }
    
    // MARK: CPU Pass
    
    /// Packs every caster edge reached by the circular light.
    func shadowSegments(for light: SKNode, shadowCasterVertices: [[CGPoint]]) -> [Float] {
        var shadowSegments: [Float] = []
        let lightRadius = CGFloat(self.lightRadius)
        let safeShadowFadeDistance = max(CGFloat(shadowFadeDistance), 0.0001)
        
        for casterVertices in shadowCasterVertices {
            guard casterVertices.count >= 3 else {
                continue
            }
            
            let distanceToCaster = distanceFromPointToConvexPolygon(
                light.position,
                polygonVertices: casterVertices
            )
            
            /// Fade from zero when the light disk touches the caster to full strength after the configured transition distance.
            let shadowStrength = smoothstep(
                lightRadius,
                lightRadius + safeShadowFadeDistance,
                distanceToCaster
            )
            
            guard shadowStrength > 0.001 else {
                continue
            }
            
            for vertexIndex in casterVertices.indices {
                let segmentStart = casterVertices[vertexIndex]
                let segmentEnd =
                casterVertices[(vertexIndex + 1) % casterVertices.count]
                
                guard lightDiskFacesSegment(
                    start: segmentStart,
                    end: segmentEnd,
                    lightPosition: light.position,
                    lightRadius: lightRadius
                ) else {
                    continue
                }
                
                /// Store the endpoints and the uniform strength of the complete caster.
                shadowSegments.append(Float(segmentStart.x))
                shadowSegments.append(Float(segmentStart.y))
                shadowSegments.append(Float(segmentEnd.x))
                shadowSegments.append(Float(segmentEnd.y))
                shadowSegments.append(Float(shadowStrength))
            }
        }
        
        return shadowSegments
    }
    
    /// Returns whether any part of the circular light can reach the segment's outside face.
    ///
    /// The polygon points are counter-clockwise, so rotating the segment clockwise
    /// produces its outward normal. The radius expands the facing test by the light
    /// disk's projected reach across the segment normal.
    private func lightDiskFacesSegment(start: CGPoint, end: CGPoint, lightPosition: CGPoint, lightRadius: CGFloat) -> Bool {
        let segmentVector = CGPoint(
            x: end.x - start.x,
            y: end.y - start.y
        )
        
        let outsideNormal = CGPoint(
            x: segmentVector.y,
            y: -segmentVector.x
        )
        
        let segmentMidpoint = CGPoint(
            x: (start.x + end.x) * 0.5,
            y: (start.y + end.y) * 0.5
        )
        
        let midpointToLight = CGPoint(
            x: lightPosition.x - segmentMidpoint.x,
            y: lightPosition.y - segmentMidpoint.y
        )
        
        let lightSide = dot(outsideNormal, midpointToLight)
        let segmentLength = hypot(segmentVector.x, segmentVector.y)
        let lightDiskReach = lightRadius * segmentLength
        
        return lightSide > -lightDiskReach
    }
    
    private func distanceFromPointToConvexPolygon(_ point: CGPoint, polygonVertices: [CGPoint]) -> CGFloat {
        var pointIsInsidePolygon = true
        var closestDistance = CGFloat.infinity
        
        for vertexIndex in polygonVertices.indices {
            let segmentStart = polygonVertices[vertexIndex]
            let segmentEnd = polygonVertices[(vertexIndex + 1) % polygonVertices.count]
            let segmentVector = CGPoint(
                x: segmentEnd.x - segmentStart.x,
                y: segmentEnd.y - segmentStart.y
            )
            let outsideNormal = CGPoint(
                x: segmentVector.y,
                y: -segmentVector.x
            )
            let segmentStartToPoint = CGPoint(
                x: point.x - segmentStart.x,
                y: point.y - segmentStart.y
            )
            
            if dot(outsideNormal, segmentStartToPoint) > 0 {
                pointIsInsidePolygon = false
            }
            
            closestDistance = min(
                closestDistance,
                distanceFromPointToSegment(
                    point,
                    segmentStart: segmentStart,
                    segmentEnd: segmentEnd
                )
            )
        }
        
        return pointIsInsidePolygon ? 0 : closestDistance
    }
    
    private func distanceFromPointToSegment(_ point: CGPoint, segmentStart: CGPoint, segmentEnd: CGPoint) -> CGFloat {
        let segmentVector = CGPoint(
            x: segmentEnd.x - segmentStart.x,
            y: segmentEnd.y - segmentStart.y
        )
        let segmentLengthSquared = max(dot(segmentVector, segmentVector), 0.0001)
        let segmentStartToPoint = CGPoint(
            x: point.x - segmentStart.x,
            y: point.y - segmentStart.y
        )
        let projection = dot(segmentStartToPoint, segmentVector) / segmentLengthSquared
        let clampedProjection = min(max(projection, 0), 1)
        let closestPoint = CGPoint(
            x: segmentStart.x + segmentVector.x * clampedProjection,
            y: segmentStart.y + segmentVector.y * clampedProjection
        )
        
        return hypot(point.x - closestPoint.x, point.y - closestPoint.y)
    }
    
    // MARK: Helpers
    
    /// Converts every shadow caster's vertices to scene coordinates.
    func shadowCasterVertices() -> [[CGPoint]] {
        shadowCasters.map { shadowCaster in
            sceneVertices(for: shadowCaster)
        }
    }
    
    private func sceneVertices(for shadowCaster: ShadowCaster) -> [CGPoint] {
        shadowCaster.vertices.map { localPoint in
            shadowCaster.node.convert(localPoint, to: self)
        }
    }
    
    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let progress = min(max((value - edge0) / max(edge1 - edge0, 0.0001), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
    
    private func dot(_ firstVector: CGPoint, _ secondVector: CGPoint) -> CGFloat {
        firstVector.x * secondVector.x + firstVector.y * secondVector.y
    }
    
    // MARK: Dragging
    
    func beginDrag(for touch: UITouch, at scenePoint: CGPoint) {
        guard let node = draggableNode(at: scenePoint) else {
            return
        }
        
        guard activeDrags.values.contains(where: { $0.node === node }) == false else {
            return
        }
        
        activeDrags[touch] = DragState(
            node: node,
            offset: CGPoint(
                x: node.position.x - scenePoint.x,
                y: node.position.y - scenePoint.y
            )
        )
    }
    
    func updateDrag(for touch: UITouch, to scenePoint: CGPoint) {
        guard let dragState = activeDrags[touch] else {
            return
        }
        
        dragState.node.position = CGPoint(
            x: scenePoint.x + dragState.offset.x,
            y: scenePoint.y + dragState.offset.y
        )
    }
    
    func endDrag(for touch: UITouch) {
        activeDrags.removeValue(forKey: touch)
    }
    
    private func draggableNode(at scenePoint: CGPoint) -> SKNode? {
        var candidate: SKNode? = atPoint(scenePoint)
        
        while let node = candidate {
            if node.name == "draggable" {
                return node
            }
            
            candidate = node.parent
        }
        
        return nil
    }
    
}
