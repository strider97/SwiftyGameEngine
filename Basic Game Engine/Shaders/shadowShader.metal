//
//  shadowShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 17/02/21.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
};
struct VertexOut {
    float4 position [[position]];
};

struct ShadowUniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
};

vertex VertexOut shadowVertexShader (const VertexIn vIn [[ stage_in ]], constant ShadowUniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 PVM = uniforms.P * uniforms.V * uniforms.M;
    vOut.position = (PVM * vIn.position);
    return vOut;
}

