//
//  shadowShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 17/02/21.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 smoothNormal [[attribute(3)]];
    float3 tangent [[attribute(4)]];
};
struct VertexOut {
    float4 position [[position]];
};

struct ShadowUniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
    float exposure;
};

vertex VertexOut shadowVertexShader (const VertexIn vIn [[ stage_in ]], constant ShadowUniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 PVM = uniforms.P * uniforms.V;
    vOut.position = PVM * float4(vIn.position, 1.0);
    return vOut;
}

