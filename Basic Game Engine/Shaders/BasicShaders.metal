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
    float3 eye;
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
    float3 position;
    float3 normal;
    float3 eye;
    float2 texCoords;
};

struct Material {
    float3 baseColor;
};

vertex VertexOut basicVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 VM = uniforms.V*uniforms.M;
    float4x4 PVM = uniforms.P*VM;
    vOut.m_position = PVM * float4(vIn.position, 1.0);
    vOut.normal = (uniforms.M*float4(vIn.normal, 0)).xyz;
    vOut.position = (uniforms.M*float4(vIn.position, 1.0)).xyz;
    vOut.texCoords = vIn.texCoords;
    vOut.eye = uniforms.eye;
    return vOut;
}

fragment half4 basicFragmentShader(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColorTexture [[texture(0)]], sampler baseColorSampler [[sampler(0)]]) {
//    float3 color = baseColorTexture.sample(baseColorSampler, vOut.texCoords).rgb;
    float3 color = material.baseColor;
    float3 lightDir = normalize(float3(-1, 2, 1));
    float3 eyeDir = normalize(vOut.eye - vOut.position);
    float spec = 1*pow(max(0.0, dot(normalize(lightDir + eyeDir), vOut.normal)), 32);
    float diff = max(0.2, dot(lightDir, vOut.normal));
    float3 outColor = color * (diff + spec);
 //   return half4(1);
    return half4(outColor.x, outColor.y, outColor.z, 1.0);
 //   return half4(vOut.normal.x, vOut.normal.y, vOut.normal.z, 1.0);
}
