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

constant float2 invPi = float2(0.15915, 0.31831);
constant float pi = 3.1415926;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 smoothNormal [[attribute(3)]];
};

struct VertexOut {
    float4 m_position [[position]];
    float3 position;
    float3 normal;
    float3 smoothNormal;
    float3 eye;
    float2 texCoords;
};

struct Material {
    float3 baseColor;
};

float2 sampleSphericalMap_(float3 dir) {
    float3 v = normalize(dir);
    float2 uv = float2(atan(-v.z/v.x), acos(v.y));
    if (v.x < 0) {
        uv.x += pi;
    }
    if (v.x >= 0 && -v.z < 0) {
        uv.x += 2*pi;
    }
    uv *= invPi;
    return uv;
}

float3 approximateSpecularIBL( float3 SpecularColor , float Roughness, float3 N, float3 V, texture2d<float, access::sample> irradianceMap [[texture(0)]], texture2d<float, access::sample> DFGlut [[texture(1)]]) {
    constexpr sampler s(coord::normalized, address::repeat, filter::linear);
    float NoV = saturate( dot( N, V ) );
    float3 R = 2 * dot( V, N ) * N - V;
//    R.y = -R.y;
    R.x = -R.x;
    R.z = -R.z;
    float3 PrefilteredColor = irradianceMap.sample(s, sampleSphericalMap_(R)).rgb;
    float2 EnvBRDF = DFGlut.sample(s, float2(Roughness, NoV)).rg;
    return PrefilteredColor * ( SpecularColor * EnvBRDF.x + EnvBRDF.y );
}

vertex VertexOut basicVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 VM = uniforms.V*uniforms.M;
    float4x4 PVM = uniforms.P*VM;
    vOut.m_position = PVM * float4(vIn.position, 1.0);
    vOut.normal = (uniforms.M*float4(vIn.normal, 0)).xyz;
    vOut.position = (uniforms.M*float4(vIn.position, 1.0)).xyz;
    vOut.texCoords = vIn.texCoords;
    vOut.eye = uniforms.eye;
    vOut.smoothNormal = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    return vOut;
}

fragment half4 basicFragmentShader(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> irradianceMap [[texture(0)]], texture2d<float, access::sample> DFGlut [[texture(1)]]) {
//    float3 color = baseColorTexture.sample(baseColorSampler, vOut.texCoords).rgb;
//    float intensity = 0.6;
//    float3 color = material.baseColor;
//    float3 lightDir = normalize(float3(-1, 2, 1));
    float3 eyeDir = normalize(vOut.eye - vOut.position);
//    float spec = 1.4 * pow(max(0.0, dot(normalize(lightDir + eyeDir), vOut.normal)), 32);
 //   float diff = max(0.2, dot(lightDir, vOut.normal));
    
    
 //   float3 outColor = intensity * color * (diff + spec);
    float roughness = 0.6;
    float3 outColor = approximateSpecularIBL(float3(0.1), roughness, vOut.smoothNormal, eyeDir, irradianceMap, DFGlut);
    outColor = pow(outColor, float3(1.0/2.2));
 //   return half4(1);
    return half4(outColor.x, outColor.y, outColor.z, 1.0);
 //   return half4(vOut.normal.x, vOut.normal.y, vOut.normal.z, 1.0);
}






/*
 fragment half4 basicFragmentShader(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColorTexture [[texture(0)]], sampler baseColorSampler [[sampler(0)]]) {
 //    float3 color = baseColorTexture.sample(baseColorSampler, vOut.texCoords).rgb;
     float intensity = 0.6;
     float3 color = material.baseColor;
     float3 lightDir = normalize(float3(-1, 2, 1));
     float3 eyeDir = normalize(vOut.eye - vOut.position);
     float spec = 1.4 * pow(max(0.0, dot(normalize(lightDir + eyeDir), vOut.normal)), 32);
     float diff = max(0.2, dot(lightDir, vOut.normal));
     float3 outColor = intensity * color * (diff + spec);
     outColor = pow(outColor, float3(1.0/2.2));
  //   return half4(1);
     return half4(outColor.x, outColor.y, outColor.z, 1.0);
  //   return half4(vOut.normal.x, vOut.normal.y, vOut.normal.z, 1.0);
 }

 */
