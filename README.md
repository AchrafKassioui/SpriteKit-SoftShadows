# SpriteKit Soft Shadows

This is an implementation of 2D soft shadows using Metal and Apple SpriteKit.

<img src="Media/SpriteKit Soft Shadows Composition.png" alt="SpriteKit Soft Shadows Composition" style="width:100%;" />

## Video

[YouTube Video Demo](https://www.youtube.com/watch?v=afh7Xi9GBjk) (1:55).

## Getting Started

<img src="Media/Device Composition.png" alt="Device Composition" style="width:100%;" />

The demo app runs on iOS and Mac Catalyst. To launch it:

- Download and open the project in Xcode.
- Update the project's signing.
- Select a target device or simulator.
- Run.

## How It Works

The app uses `MTKView` to drive the rendering loop at the desired frame rate. Each frame:

- SpriteKit renders the scene into a Metal texture using `SKRenderer`.
- The CPU sends each light's properties and the relevant shape edges to a Metal vertex shader.
- The vertex shader projects shadow geometry from each edge.
- A fragment shader calculates the shadow opacity at each pixel, producing a soft shadow mask for each light.
- A final fragment shader combines the SpriteKit texture, lights, and shadow masks to produce the displayed image.

The SwiftUI controls update variables inside the SpriteKit scene through `@Observable`. The rendering loop consumes the new values on its next cycle.

## SpriteKit & Metal

Technically, this proof of concept doesn't have to use SpriteKit. The shadow pipeline is bare Metal. SpriteKit is used as a convenient scene graph and base renderer:

- SpriteKit renders the base unlit image with the sprites.

- `SKScene` holds the data structures that define a shadow caster: a convex polygon defined with vertices, and the visual node associated with it:

  ```swift
  struct ShadowCaster {
      let node: SKSpriteNode
  
      /// Convex outline in local space, counter-clockwise winding.
      let vertices: [CGPoint]
  }
  ```

- `MTKView`  receives user input and passes it to `SKScene`. The scene uses SpriteKit hit testing to find and move the selected node.

- Each frame, `MTKView` asks `SKScene` for the caster vertices in scene coordinates, after the node transforms have been applied. The scene determines which edges face each light, and the renderer copies those edge endpoints into a Metal buffer for the shadow shaders.

It's possible to replace SpriteKit with a full custom rendering path. To me this shows how nice SpriteKit is: we can use it as base, then add or replace parts of it with a Metal pipeline as needed.

## Findings

- When Metal API Validation is enabled in Product > Scheme > Edit Scheme > Diagnostics, `SKRenderer` requires setting an explicit stencil texture attachment.
- When a project targets Mac Catalyst, the UI can be changed to look like iOS or macOS in Project Settings > Target > General > Deployment Info > Mac Catalyst Interface
- Sprite nodes can render Display P3 colors. However, shape nodes seem to only support sRGB. Colors outside the sRGB range may wrap, producing entirely different colors.

## Links

- Scott Lembcke, [2D Lighting with Soft Shadows](https://www.slembcke.net/blog/SuperFastSoftShadows/), 2021.
- Apple Documentation, [Metal View](https://developer.apple.com/documentation/metalkit/mtkview).
- Apple Documentation, [SKRenderer](https://developer.apple.com/documentation/spritekit/skrenderer).
- Apple Documentation Archive, [Metal Best Practices Guide - Triple Buffering](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html).
- Apple Documentation, [Observation](https://developer.apple.com/documentation/observation).
- Apple Developer Forums, [thread](https://developer.apple.com/forums/thread/817914?answerId=885088022) about color space and stencil attachment when rendering SKShapeNode content with SKRenderer.

## License

This project is licensed under the Apache License 2.0.

If this project helps your work, attribution or a link back is appreciated:
https://github.com/AchrafKassioui/SpriteKit-SoftShadows
