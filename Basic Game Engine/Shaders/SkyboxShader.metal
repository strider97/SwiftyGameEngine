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

constant float2 invAtan = float2(0.15915, 0.31831);
constant float pi = 3.1415926;

float2 sampleSphericalMap(float3 dir)
{
    float3 v = normalize(dir);
    float2 uv = float2(atan(-v.z/v.x), acos(v.y));
    if (v.x < 0) {
        uv.x += pi;
    }
    if (v.x >= 0 && -v.z < 0) {
        uv.x += 2*pi;
    }
    uv *= invAtan;
    return uv;
}

vertex VertexOut skyboxVertexShader (const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 PVM = uniforms.P*uniforms.V;
    vOut.position = (PVM * vIn.position).xyww;
    vOut.textureDir = vIn.position.xyz;
    return vOut;
}

fragment half4 skyboxFragmentShader (VertexOut vOut [[ stage_in ]], texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 skyColor = baseColorTexture.sample(baseColorSampler, sampleSphericalMap(vOut.textureDir)).rgb;
    skyColor = pow(skyColor, float3(1.0/2.2));
    half4 color = half4(skyColor.x, skyColor.y, skyColor.z, 1);
    return color;
}

vertex VertexOut irradianceMapVertexShader (const VertexIn vIn [[ stage_in ]]) {
    VertexOut vOut;
    float2 pos = sampleSphericalMap(vIn.position.xyz);
    pos = (pos - 0.5)*2;
    vOut.position = float4(pos.x, pos.y, 1, 1);
    vOut.textureDir = float3(vIn.position.x, -vIn.position.y, vIn.position.z);
    return vOut;
}

fragment half4 irradianceMapFragmentShader (VertexOut vOut [[ stage_in ]], texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 skyColor = baseColorTexture.sample(baseColorSampler, sampleSphericalMap(vOut.textureDir)).rgb;
    skyColor = pow(skyColor, float3(1.0/2.2));
    half4 color = half4(skyColor.x, skyColor.y, skyColor.z, 1);
    return color;
}
