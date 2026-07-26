/**
 
 # Renderer
 
 A Metal view that drives a custom Metal pipeline on top of SpriteKit rendering via SKRenderer.
 
 Achraf Kassioui
 Created 6 Jul 2026
 Updated 26 Jul 2026
 
 */
import MetalKit
import SpriteKit
import SwiftUI

class MetalView: MTKView, MTKViewDelegate {
    
    // MARK: Properties
    
    private let commandQueue: MTLCommandQueue
    
    /// SpriteKit Renderer
    let scene: SoftShadowsScene
    private let spriteKitRenderer: SKRenderer
    private var spriteKitStencilTexture: MTLTexture?
    
    /// Offscreen textures for rendering passes
    private var contentTexture: MTLTexture?
    private var firstShadowTexture: MTLTexture?
    private var secondShadowTexture: MTLTexture?
    
    /// Shaders
    private let displayPipeline: MTLRenderPipelineState
    private let shadowPipeline: MTLRenderPipelineState
    
    /// Triple buffer, industry practice.
    /// Three frames let the CPU prepare new shadow data while the GPU finishes previous frames.
    private static let framesInFlightCount = 3
    
    /// Prevents the CPU from overwriting buffers still being read by the GPU.
    /// Semaphere count = how many sets of buffers are currently free for the CPU to write.
    private let framesInFlightSemaphore: DispatchSemaphore = DispatchSemaphore(
        value: MetalView.framesInFlightCount
    )
    
    /// Vertex buffers for each light in a frame
    private struct FrameShadowBuffers {
        var shadowSegmentBuffers: [MTLBuffer?] = [nil, nil]
    }
    
    /// Three sets of shadow buffers, one for each frame in flight.
    private var frameShadowBuffers = Array(
        repeating: FrameShadowBuffers(),
        count: MetalView.framesInFlightCount
    )
    
    private var nextShadowBufferIndex = 0
    
    // MARK: Lifecycle
    
    init(scene: SoftShadowsScene) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        
        /// Xcode compiles all the Metal source files into a single default library.
        /// Shader functions are linked by the names passed to `makeFunction(name:)`.
        guard let metalLibrary = device.makeDefaultLibrary() else {
            fatalError("Could not load the default Metal library")
        }
        
        /// Create the render pipelines.
        do {
            /// Shaders for the compositing pass.
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = metalLibrary.makeFunction(name: "fullscreenVertex")
            pipelineDescriptor.fragmentFunction = metalLibrary.makeFunction(name: "displayFragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            self.displayPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            /// Shaders for the shadow pass.
            let shadowPipelineDescriptor = MTLRenderPipelineDescriptor()
            shadowPipelineDescriptor.vertexFunction = metalLibrary.makeFunction(name: "shadowVertex")
            shadowPipelineDescriptor.fragmentFunction = metalLibrary.makeFunction(name: "shadowFragment")
            shadowPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            shadowPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            shadowPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            shadowPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            shadowPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            shadowPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            shadowPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            shadowPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            self.shadowPipeline = try device.makeRenderPipelineState(descriptor: shadowPipelineDescriptor)
        } catch {
            fatalError("Could not create Metal pipelines: \(error)")
        }
        
        /// Setup SKRenderer
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        renderer.ignoresSiblingOrder = true
        //renderer.showsNodeCount = true
        //renderer.showsDrawCount = true
        
        /// Setup view
        self.scene = scene
        self.spriteKitRenderer = renderer
        self.commandQueue = commandQueue
        
        super.init(frame: .zero, device: device)
        
        isMultipleTouchEnabled = true
        contentMode = .center
        preferredFramesPerSecond = 120
        
        /// Auto refresh view
        delegate = self
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: View Resize
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        spriteKitStencilTexture = nil
        contentTexture = nil
        firstShadowTexture = nil
        secondShadowTexture = nil
    }
    
    // MARK: Render Loop
    
    func draw(in view: MTKView) {
        /// Wait for Metal buffers that the GPU no longer uses.
        framesInFlightSemaphore.wait()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = currentDrawable
        else {
            framesInFlightSemaphore.signal()
            return
        }
        
        /// Select the shadow buffers used by this frame.
        let shadowBufferIndex = nextShadowBufferIndex
        
        /// Set the shadow buffers used by the next frame.
        nextShadowBufferIndex = (nextShadowBufferIndex + 1) % Self.framesInFlightCount
        
        /// Release these shadow buffers when the GPU finishes reading them.
        commandBuffer.addCompletedHandler { [framesInFlightSemaphore] _ in
            framesInFlightSemaphore.signal()
        }
        
        /// Update the scene.
        spriteKitRenderer.update(atTime: CACurrentMediaTime())
        
        /// Prepare render textures.
        createContentTextureIfNeeded()
        createShadowTexturesIfNeeded()
        
        guard let contentTexture,
              let spriteKitStencilTexture,
              let firstShadowTexture,
              let secondShadowTexture
        else {
            /// Commit so the completion handler releases the reserved shadow buffers.
            commandBuffer.commit()
            return
        }
        
        /// Prepare texture for SpriteKit offscreen rendering
        let contentPassDescriptor = MTLRenderPassDescriptor()
        contentPassDescriptor.colorAttachments[0].texture = contentTexture
        contentPassDescriptor.colorAttachments[0].loadAction = .clear
        contentPassDescriptor.colorAttachments[0].storeAction = .store
        contentPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        
        /// When Metal API validation is enabled in the product scheme, SKRenderer needs an explicit stencil attachment
        contentPassDescriptor.stencilAttachment.texture = spriteKitStencilTexture
        contentPassDescriptor.stencilAttachment.loadAction = .clear
        contentPassDescriptor.stencilAttachment.storeAction = .dontCare
        contentPassDescriptor.stencilAttachment.clearStencil = 0
        
        /// Draw calls managed by SpriteKit
        spriteKitRenderer.render(
            withViewport: .init(origin: .zero, size: drawableSize),
            commandBuffer: commandBuffer,
            renderPassDescriptor: contentPassDescriptor
        )
        
        /// Convert caster vertices once for both lights.
        let shadowCasterVertices = scene.shadowCasterVertices()
        
        /// Render one shadow mask per light.
        renderShadowMask(
            into: firstShadowTexture,
            for: scene.firstLight,
            isEnabled: scene.firstLightIntensity > 0,
            lightIndex: 0,
            shadowBufferIndex: shadowBufferIndex,
            shadowCasterVertices: shadowCasterVertices,
            commandBuffer: commandBuffer
        )
        
        renderShadowMask(
            into: secondShadowTexture,
            for: scene.secondLight,
            isEnabled: scene.secondLightIntensity > 0,
            lightIndex: 1,
            shadowBufferIndex: shadowBufferIndex,
            shadowCasterVertices: shadowCasterVertices,
            commandBuffer: commandBuffer
        )
        
        /// Draw into the view texture.
        let displayPassDescriptor = MTLRenderPassDescriptor()
        displayPassDescriptor.colorAttachments[0].texture = drawable.texture
        displayPassDescriptor.colorAttachments[0].loadAction = .clear
        displayPassDescriptor.colorAttachments[0].storeAction = .store
        displayPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        
        if let displayEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: displayPassDescriptor
        ) {
            /// Composite SpriteKit, lights, and shadows.
            var showShadowMask = scene.showShadowMask
            
            let firstLightColor = colorComponents(SKColor(scene.firstLightColor))
            let secondLightColor = colorComponents(SKColor(scene.secondLightColor))
            
            let displayData: [Float] = [
                Float(scene.size.width),
                Float(scene.size.height),
                Float(scene.firstLight.position.x),
                Float(scene.firstLight.position.y),
                Float(scene.secondLight.position.x),
                Float(scene.secondLight.position.y),
                Float(scene.lightFalloffRadius),
                Float(scene.ambientLight),
                Float(scene.shadowOpacity),
                Float(scene.firstLightIntensity),
                Float(scene.secondLightIntensity),
                firstLightColor.red,
                firstLightColor.green,
                firstLightColor.blue,
                secondLightColor.red,
                secondLightColor.green,
                secondLightColor.blue
            ]
            
            displayEncoder.setRenderPipelineState(displayPipeline)
            displayEncoder.setFragmentTexture(contentTexture, index: 0)
            displayEncoder.setFragmentTexture(firstShadowTexture, index: 1)
            displayEncoder.setFragmentTexture(secondShadowTexture, index: 2)
            displayEncoder.setFragmentBytes(
                &showShadowMask,
                length: MemoryLayout<Bool>.stride,
                index: 0
            )
            
            displayData.withUnsafeBufferPointer { displayDataPointer in
                displayEncoder.setFragmentBytes(
                    displayDataPointer.baseAddress!,
                    length: MemoryLayout<Float>.stride * displayData.count,
                    index: 1
                )
            }
            
            /// Draw call: composite the scene, lights, and shadow masks.
            displayEncoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: 3
            )
            displayEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: Shadow Mask
    
    /// Renders one light's shadow segments into its mask.
    private func renderShadowMask(
        into shadowTexture: MTLTexture,
        for light: SKNode,
        isEnabled: Bool,
        lightIndex: Int,
        shadowBufferIndex: Int,
        shadowCasterVertices: [[CGPoint]],
        commandBuffer: MTLCommandBuffer
    ) {
        let shadowPassDescriptor = MTLRenderPassDescriptor()
        shadowPassDescriptor.colorAttachments[0].texture = shadowTexture
        shadowPassDescriptor.colorAttachments[0].loadAction = .clear
        shadowPassDescriptor.colorAttachments[0].storeAction = .store
        shadowPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        guard let shadowEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: shadowPassDescriptor) else {
            return
        }
        
        /// Clear shadow mask without drawing when the light is disabled.
        guard isEnabled else {
            shadowEncoder.endEncoding()
            return
        }
        
        /// Get the segments lit from the SpriteKit scene with a CPU method.
        let shadowSegments = scene.shadowSegments(for: light, shadowCasterVertices: shadowCasterVertices)
        
        /// Each shadow segment contains five floats. Divide by 5 to find the segment count.
        let shadowSegmentCount = shadowSegments.count / 5
        
        /// Each segment becomes one quad. A quad is drawn as two triangles = 6 vertices total.
        let shadowVertexCount = shadowSegmentCount * 6
        
        guard shadowVertexCount > 0 else {
            shadowEncoder.endEncoding()
            return
        }
        
        let shadowData: [Float] = [
            Float(scene.size.width),
            Float(scene.size.height),
            Float(light.position.x),
            Float(light.position.y),
            Float(scene.lightRadius)
        ]
        
        let shadowSegmentDataLength = shadowSegments.count * MemoryLayout<Float>.stride
        
        guard let shadowSegmentBuffer = shadowSegmentBuffer(
            for: lightIndex,
            shadowBufferIndex: shadowBufferIndex,
            minimumLength: shadowSegmentDataLength
        ) else {
            shadowEncoder.endEncoding()
            return
        }
        
        /// Copy the shadow segments from the Swift array to the Metal buffer.
        shadowSegments.withUnsafeBytes { shadowSegmentBytes in
            guard let shadowSegmentAddress = shadowSegmentBytes.baseAddress else {
                return
            }
            
            shadowSegmentBuffer.contents().copyMemory(
                from: shadowSegmentAddress,
                byteCount: shadowSegmentDataLength
            )
        }
        
        /// Specify the associated shaders and blending settings
        shadowEncoder.setRenderPipelineState(shadowPipeline)
        
        /// Send the scene size and light values directly to the vertex shader (under 4 KB).
        shadowData.withUnsafeBufferPointer { shadowDataPointer in
            shadowEncoder.setVertexBytes(
                shadowDataPointer.baseAddress!,
                length: MemoryLayout<Float>.stride * shadowData.count,
                index: 0
            )
        }
        
        /// Bind the shadow segments Metal buffer to the vertex shader.
        shadowEncoder.setVertexBuffer(
            shadowSegmentBuffer,
            offset: 0,
            index: 1
        )
        
        /// Draw call: draw all shadow segments for this light in one call.
        shadowEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: shadowVertexCount
        )
        
        shadowEncoder.endEncoding()
    }
    
    /// Reuses the current shadow segment buffer, or creates a larger one when needed.
    private func shadowSegmentBuffer(for lightIndex: Int, shadowBufferIndex: Int, minimumLength: Int) -> MTLBuffer? {
        let currentBuffer = frameShadowBuffers[shadowBufferIndex].shadowSegmentBuffers[lightIndex]
        
        if let currentBuffer,
           currentBuffer.length >= minimumLength {
            return currentBuffer
        }
        
        /// Grow the buffer geometrically to avoid frequent small reallocations.
        let currentLength = currentBuffer?.length ?? 0
        let doubledLength = currentLength * 2
        let newLength = max(minimumLength, max(doubledLength, 4_096))
        
        guard let newBuffer = device?.makeBuffer(
            length: newLength,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        newBuffer.label = "Frame \(shadowBufferIndex) Light \(lightIndex) Shadow Segments"
        
        frameShadowBuffers[shadowBufferIndex].shadowSegmentBuffers[lightIndex] = newBuffer
        
        return newBuffer
    }
    
    // MARK: Texture Allocation
    
    private func createContentTextureIfNeeded() {
        let textureWidth = Int(drawableSize.width)
        let textureHeight = Int(drawableSize.height)
        
        guard textureWidth > 0, textureHeight > 0 else {
            return
        }
        
        /// Reuse the SpriteKit render target when both attachments match the drawable.
        if contentTexture?.width == textureWidth,
           contentTexture?.height == textureHeight,
           spriteKitStencilTexture?.width == textureWidth,
           spriteKitStencilTexture?.height == textureHeight {
            return
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: self.colorPixelFormat,
            width: textureWidth,
            height: textureHeight,
            mipmapped: false
        )
        
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        
        contentTexture = device?.makeTexture(descriptor: descriptor)
        
        /// Stencil texture for SKRenderer
        let stencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .stencil8,
            width: textureWidth,
            height: textureHeight,
            mipmapped: false
        )
        stencilDescriptor.usage = [.renderTarget]
        stencilDescriptor.storageMode = .private
        
        spriteKitStencilTexture = device?.makeTexture(descriptor: stencilDescriptor)
    }
    
    private func createShadowTexturesIfNeeded() {
        let textureWidth = Int(drawableSize.width)
        let textureHeight = Int(drawableSize.height)
        
        guard textureWidth > 0, textureHeight > 0 else {
            return
        }
        
        if firstShadowTexture?.width == textureWidth,
           firstShadowTexture?.height == textureHeight,
           secondShadowTexture?.width == textureWidth,
           secondShadowTexture?.height == textureHeight {
            return
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: self.colorPixelFormat,
            width: textureWidth,
            height: textureHeight,
            mipmapped: false
        )
        
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        
        firstShadowTexture = device?.makeTexture(descriptor: descriptor)
        secondShadowTexture = device?.makeTexture(descriptor: descriptor)
    }
    
    // MARK: Helpers
    
    private func colorComponents(_ color: SKColor) -> (red: Float, green: Float, blue: Float) {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        
        color.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        )
        
        return (
            red: Float(red),
            green: Float(green),
            blue: Float(blue)
        )
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            scene.beginDrag(for: touch, at: scenePoint(from: touch.location(in: self)))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            /// Testing coalesced touches for high frequency input devices
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]
            
            for coalescedTouch in coalescedTouches {
                scene.updateDrag(for: touch, to: scenePoint(from: coalescedTouch.location(in: self)))
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            scene.endDrag(for: touch)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            scene.endDrag(for: touch)
        }
    }
    
    private func scenePoint(from viewPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: (viewPoint.x / bounds.width - 0.5) * scene.size.width,
            y: (0.5 - viewPoint.y / bounds.height) * scene.size.height
        )
    }
    
}
