//
//  rsmShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 13/04/21.
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
    float3 worldPos;
    float3 smoothNormal;
    float2 uv;
};

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
    float exposure;
};

struct ShadowUniforms {
    float4x4 P;
    float4x4 V;
    float3 sunDirection;
};

struct GbufferOut {
    float4 normal [[ color(0) ]];
    float4 worldPos [[ color(1) ]];
    float4 flux [[ color(2) ]];
};

struct Material {
    float3 baseColor;
    float roughness;
    float metallic;
    int mipmapCount;
};

vertex VertexOut vertexRSM(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]], constant ShadowUniforms &shadowUniforms [[buffer(2)]])  {
    VertexOut vOut;
    float4x4 PVM = shadowUniforms.P * shadowUniforms.V * uniforms.M;
    vOut.position = PVM * float4(vIn.position, 1.0);
    vOut.worldPos = (uniforms.M * float4(vIn.position, 1.0)).xyz;
    vOut.smoothNormal = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    vOut.uv = float2(vIn.texCoords.x, 1-vIn.texCoords.y);
    return vOut;
}

fragment GbufferOut fragmentRSMData (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColor [[texture(3)]]) {
    GbufferOut out;
    out.worldPos = float4(vOut.worldPos, 1);
    out.normal = float4(vOut.smoothNormal, 1);
    out.flux = float4(float3(15) * material.baseColor, 1);
    return out;
}

fragment GbufferOut lpvDataFragment (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColor [[texture(3)]], texture3d<float, access::write> volume [[texture(4)]]) {
    GbufferOut out;
    out.worldPos = float4(vOut.worldPos, 1);
    out.normal = float4(vOut.smoothNormal, 1);
    out.flux = float4(float3(15) * material.baseColor, 1);
    return out;
}
