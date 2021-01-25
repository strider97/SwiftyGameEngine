//
//  BasicShaders.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
};

/*
struct VertexIn {
    float3 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
};

struct VertexOut {
    float4 gl_position [[position]];
    float4 color;
};

vertex VertexOut basicVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut p;
    float4x4 mvpMatrix = uniforms.P*uniforms.V*uniforms.M;
    p.gl_position = mvpMatrix * float4(vIn.position, 1.0);
    p.color = vIn.color;
    return p;
}

fragment half4 basicFragmentShader(VertexOut vOut [[ stage_in ]]) {
    float4 color = vOut.color;
    return half4(color.r, color.g, color.b, color.a);
}
*/

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 m_position [[position]];
    float4 position;
    float4 normal;
    float2 texCoords;
};

vertex VertexOut basicVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 VM = uniforms.V*uniforms.M;
    float4x4 PVM = uniforms.P*VM;
    vOut.m_position = PVM * float4(vIn.position, 1.0);
    vOut.normal = VM*float4(vIn.normal, 0);
    vOut.position = VM*float4(vIn.position, 1.0);
    vOut.texCoords = vIn.texCoords;
    return vOut;
}

fragment half4 basicFragmentShader(VertexOut vOut [[ stage_in ]]) {
    return half4(1);
}
