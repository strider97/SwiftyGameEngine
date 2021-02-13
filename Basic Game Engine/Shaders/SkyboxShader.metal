//
//  SkyboxShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 13/02/21.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
};
struct VertexOut {
    float4 position [[position]];
    float3 textureDir;
};

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
};

constant float2 invAtan = float2(0.1591, 0.3183);

float2 sampleSphericalMap(float3 dir)
{
    float3 v = normalize(dir);
    float2 uv = float2(atan(v.z/v.x), asin(-v.y));
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

vertex VertexOut skyboxVertexShader (const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 V_ = uniforms.V;
    V_.columns[3] = float4(0, 0, 0, V_[3][3]);
    float4x4 PVM = uniforms.P*V_*uniforms.M;
    vOut.position = (PVM * vIn.position).xyww;
    vOut.textureDir = vIn.position.xyz;
    return vOut;
}

fragment half4 skyboxFragmentShader (VertexOut vOut [[ stage_in ]], texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 skyColor = baseColorTexture.sample(baseColorSampler, sampleSphericalMap(vOut.textureDir)).rgb;
    half4 color = half4(skyColor.x, skyColor.y, skyColor.z, 1);
    return color;
}
