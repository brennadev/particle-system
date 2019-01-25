//
//  Shaders.metal
//  ParticleSystem
//
//  Created by Brenna Olson on 1/25/19.
//  Copyright © 2019 Brenna Olson. All rights reserved.
//


#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;


# pragma mark - Ball Shading (provided in Apple's template)
vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant float3 *floorVertices [[ buffer(BufferIndexFloor) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;

    return out;
}


fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

    return float4(colorSample);
}


# pragma mark - Floor Shading (very simple)
/// Only returns the position - no texture coordinates or other data; based off of the Apple-provided vertex function above
vertex float4 vertexFloor(uint vertexID [[ vertex_id ]],
                          constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                          constant float3 *floorVertices [[ buffer(BufferIndexFloor) ]]) {
    float4 position = float4(floorVertices[vertexID], 1.0);
    position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    return position;
}


/// Just returns white to keep things simple
fragment float4 fragmentFloor(float4 vertexIn [[ stage_in ]]) {
    return float4(1, 1, 1, 1);
}
