//
//  Shaders.metal
//  SpriteKitSoftShadows
//
//  Created by Achraf Kassioui on 20/7/2026.
//

#include <metal_stdlib>
using namespace metal;

struct FullscreenVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenVertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    
    float2 textureCoordinates[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };
    
    FullscreenVertexOut output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.uv = textureCoordinates[vertexID];
    return output;
}

fragment half4 displayFragment(
                               FullscreenVertexOut rasterizedVertex [[stage_in]],
                               texture2d<half> contentTexture [[texture(0)]],
                               texture2d<half> firstShadowTexture [[texture(1)]],
                               texture2d<half> secondShadowTexture [[texture(2)]],
                               constant bool &showShadowMask [[buffer(0)]],
                               constant float *displayData [[buffer(1)]]
                               ) {
    constexpr sampler textureSampler(
                                     coord::normalized,
                                     address::clamp_to_edge,
                                     filter::linear
                                     );
    
    /// Clamp the oversized fullscreen triangle coordinates to the visible texture area.
    float2 uv = clamp(
                      rasterizedVertex.uv,
                      float2(0.0),
                      float2(1.0)
                      );
    
    float2 sceneSize = float2(displayData[0], displayData[1]);
    float2 firstLightPosition = float2(displayData[2], displayData[3]);
    float2 secondLightPosition = float2(displayData[4], displayData[5]);
    float lightFalloffRadius = displayData[6];
    
    half ambientLight = half(displayData[7]);
    half shadowOpacity = half(displayData[8]);
    half firstLightIntensity = half(displayData[9]);
    half secondLightIntensity = half(displayData[10]);
    
    half3 firstLightColor = half3(
                                  half(displayData[11]),
                                  half(displayData[12]),
                                  half(displayData[13])
                                  );
    
    half3 secondLightColor = half3(
                                   half(displayData[14]),
                                   half(displayData[15]),
                                   half(displayData[16])
                                   );
    
    if (showShadowMask) {
        /// Disabled lights contribute no shadow to the debug mask.
        half firstShadow = firstLightIntensity > 0
        ? firstShadowTexture.sample(textureSampler, uv).a * shadowOpacity
        : half(0.0);
        
        half secondShadow = secondLightIntensity > 0
        ? secondShadowTexture.sample(textureSampler, uv).a * shadowOpacity
        : half(0.0);
        
        half combinedShadow = max(firstShadow, secondShadow);
        return half4(combinedShadow, combinedShadow, combinedShadow, 1.0);
    }
    
    half4 contentColor = contentTexture.sample(textureSampler, uv);
    float2 scenePosition = (uv - 0.5) * float2(sceneSize.x, -sceneSize.y);
    
    /// Ambient light affects the entire scene, including areas reached by no direct light.
    /// Each enabled light adds its colored contribution after falloff and shadowing.
    /// A total light value of 1 preserves the SpriteKit color. Lower values darken it,
    /// while higher values brighten it.
    half3 lightAmount = half3(ambientLight);
    
    if (firstLightIntensity > 0) {
        float firstLightDistance = length(
                                          scenePosition - firstLightPosition
                                          );
        
        half firstLightFalloff = half(
                                      1.0 - smoothstep(
                                                       0.0,
                                                       lightFalloffRadius,
                                                       firstLightDistance
                                                       )
                                      );
        
        half firstShadow = firstShadowTexture
            .sample(textureSampler, uv).a * shadowOpacity;
        
        half firstVisibleLight = firstLightFalloff
        * (half(1.0) - firstShadow);
        
        lightAmount += firstLightColor
        * firstVisibleLight
        * firstLightIntensity;
    }
    
    if (secondLightIntensity > 0) {
        float secondLightDistance = length(
                                           scenePosition - secondLightPosition
                                           );
        
        half secondLightFalloff = half(
                                       1.0 - smoothstep(
                                                        0.0,
                                                        lightFalloffRadius,
                                                        secondLightDistance
                                                        )
                                       );
        
        half secondShadow = secondShadowTexture
            .sample(textureSampler, uv).a * shadowOpacity;
        
        half secondVisibleLight = secondLightFalloff
        * (half(1.0) - secondShadow);
        
        lightAmount += secondLightColor
        * secondVisibleLight
        * secondLightIntensity;
    }
    
    contentColor.rgb *= lightAmount;
    
    return contentColor;
}

struct ShadowVertexOutput {
    float4 position [[position]];
    float4 penumbraCoordinates;
    float edgeClip;
    float shadowStrength;
};

float2 safeNormalize(float2 vector) {
    return vector / max(length(vector), 0.0001);
}

float2x2 adjugate(float2x2 matrix) {
    return float2x2(
                    float2(matrix[1][1], -matrix[0][1]),
                    float2(-matrix[1][0], matrix[0][0])
                    );
}

vertex ShadowVertexOutput shadowVertex(
                                       uint vertexID [[vertex_id]],
                                       constant float *shadowData [[buffer(0)]],
                                       constant float *shadowSegments [[buffer(1)]]
                                       ) {
    float2 sceneSize = float2(shadowData[0], shadowData[1]);
    float2 lightPosition = float2(shadowData[2], shadowData[3]);
    float lightRadius = shadowData[4];
    float2 halfSceneSize = sceneSize * 0.5;
    
    /// Each segment becomes one soft-shadow quad, drawn as two triangles.
    uint segmentIndex = vertexID / 6;
    uint segmentVertexIndex = vertexID % 6;
    uint segmentDataIndex = segmentIndex * 5;
    
    float2 segmentStart = float2(shadowSegments[segmentDataIndex], shadowSegments[segmentDataIndex + 1]);
    float2 segmentEnd = float2(shadowSegments[segmentDataIndex + 2], shadowSegments[segmentDataIndex + 3]);
    
    float shadowStrength = shadowSegments[segmentDataIndex + 4];
    
    /// Endpoint order used by the penumbra equations.
    float2 endpointA = segmentEnd;
    float2 endpointB = segmentStart;
    
    /// x chooses the endpoint; y chooses near edge or projected edge.
    float2 shadowCoordinates[6] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0),
        float2(0.0, 0.0)
    };
    
    float2 shadowCoordinate = shadowCoordinates[segmentVertexIndex];
    float2 endpoint = mix(endpointA, endpointB, shadowCoordinate.x);
    
    /// Lines from the light center through the segment endpoints.
    float2 directionA = endpointA - lightPosition;
    float2 directionB = endpointB - lightPosition;
    float2 endpointDirection = endpoint - lightPosition;
    
    /// Offset each projected side by the light radius to open the penumbra.
    float2 offsetA = float2(-lightRadius, lightRadius) * safeNormalize(directionA).yx;
    float2 offsetB = float2(lightRadius, -lightRadius) * safeNormalize(directionB).yx;
    float2 endpointOffset = mix(offsetA, offsetB, shadowCoordinate.x);
    
    /// Near vertices stay on the segment; far vertices project away from the light.
    float shadowNear = shadowCoordinate.y;
    float2 projectedPosition = mix(endpointDirection - endpointOffset, endpoint, shadowNear);
    
    /// Build the two penumbra coordinate systems for the fragment shader.
    float2 penumbraA = adjugate(float2x2(offsetA, -directionA)) * (endpointDirection - mix(endpointOffset, directionA, shadowNear));
    float2 penumbraB = adjugate(float2x2(-offsetB, directionB)) * (endpointDirection - mix(endpointOffset, directionB, shadowNear));
    
    /// Clip reversed projection in front of the segment.
    float2 segmentDelta = endpointB - endpointA;
    float2 segmentNormal = float2(-segmentDelta.y, segmentDelta.x);
    
    ShadowVertexOutput output;
    output.position = float4(projectedPosition / halfSceneSize, 0.0, shadowNear);
    output.penumbraCoordinates = lightRadius > 0.0 ? float4(penumbraA, penumbraB) : float4(0.0, 1.0, 0.0, 1.0);
    output.edgeClip = dot(segmentNormal, endpointDirection - endpointOffset) * (1.0 - shadowNear);
    output.shadowStrength = shadowStrength;
    
    return output;
}

fragment half4 shadowFragment(ShadowVertexOutput input [[stage_in]]) {
    /// Reconstruct the visible portions of the circular light at this fragment.
    float2 penumbraCoverage = smoothstep(
                                         float2(-1.0),
                                         float2(1.0),
                                         input.penumbraCoordinates.xz / input.penumbraCoordinates.yw
                                         );
    
    float visibleLight = dot(
                             penumbraCoverage,
                             step(input.penumbraCoordinates.yw, float2(0.0))
                             );
    
    /// Convert visible-light coverage into the occlusion contributed by this segment.
    ///
    /// Adjacent segment contributions are accumulated by additive blending. A seam
    /// correction must not be applied here because it would be repeated for every
    /// overlapping shadow quad.
    float shadowAmount = clamp(1.0 - visibleLight, 0.0, 1.0);
    shadowAmount *= step(input.edgeClip, 0.0);
    shadowAmount *= input.shadowStrength;
    
    return half4(1.0, 1.0, 1.0, half(shadowAmount));
}
