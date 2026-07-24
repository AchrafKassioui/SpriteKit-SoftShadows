# SpriteKit Soft Shadows

## Findings

- When Metal API Validation is enabled in Product > Scheme > Edit Scheme > Diagnostics, SKRenderer requires setting an explicit stencil texture attachement.
- When a project targets Mac Catalyst, the UI can be changed to look like iOS or macOS in Project Settings > Target > General > Deployement Info > Mac Catalyst Interface
- Sprite nodes can render Display P3 colors. However, shape nodes seem to support only sRGB colors. Components outside the sRGB range may wrap, producing entirely different colors.

## Links

- Apple, [Metal Best Practices Guide, Triple Buffering](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html).
- A thread mentioning [SKRenderer color space](https://developer.apple.com/forums/thread/817914?answerId=885088022) on Apple Developer Forums. May be relevant to shape nodes color space issues.

