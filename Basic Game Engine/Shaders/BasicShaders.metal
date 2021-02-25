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

constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
constant float gamma     = 2.2;
constant float exposure  = 1.0;
constant float pureWhite = 1.0;

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
    float roughness;
    float metallic;
    int mipmapCount;
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

float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}

float3 approximateSpecularIBL( float3 SpecularColor , float Roughness, int mipmapCount, float3 N, float3 V, texture2d<float, access::sample> preFilterEnvMap [[texture(0)]], texture2d<float, access::sample> DFGlut [[texture(1)]]) {
    float NoV = saturate( dot( N, V ) );
    float3 R = 2 * dot( V, N ) * N - V;
//    R.y = -R.y;
    R.x = -R.x;
    R.z = -R.z;
    float3 PrefilteredColor = preFilterEnvMap.sample(s, sampleSphericalMap_(R), level(Roughness * 6)).rgb;
    float2 EnvBRDF = DFGlut.sample(s, float2(NoV, Roughness)).rg;
    return PrefilteredColor * ( SpecularColor * EnvBRDF.x + EnvBRDF.y );
}

float3 fresnelSchlick(float3 F0, float cosTheta)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
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

fragment float4 basicFragmentShader(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> preFilterEnvMap [[texture(0)]], texture2d<float, access::sample> DFGlut [[texture(1)]], texture2d<float, access::sample> irradianceMap [[texture(2)]]) {
    
    float3 albedo = material.baseColor;
    float metallic = material.metallic;
    float roughness = material.roughness;
    float3 eyeDir = normalize(vOut.eye - vOut.position);
    
    float3 N = vOut.smoothNormal;
    float3 V = eyeDir;
    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, 1.0*metallic);
    float3 F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - metallic;
    float3 R = N;
    R.x = -R.x;
    R.z = -R.z;
    float3 irradiance = irradianceMap.sample(s, sampleSphericalMap_(R)).rgb;
    float3 diffuse = irradiance * albedo;
    float3 specular = approximateSpecularIBL(F, roughness, material.mipmapCount, N, V, preFilterEnvMap, DFGlut);
    
    float3 color =  kD * diffuse + specular;
    color = color / (color + float3(1.0));
    color = pow(color, float3(1.0/2.2));
    return float4(color, 1.0);
    
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    float mappedLuminance = (luminance * (1.0 + luminance/(pureWhite*pureWhite))) / (1.0 + luminance);

    // Scale color by ratio of average luminances.
    float3 mappedColor = (mappedLuminance / luminance) * color;

    // Gamma correction.
    return float4(pow(mappedColor, 1.0/gamma), 1.0);
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
     float3 color = intensity * color * (diff + spec);
     color = pow(color, float3(1.0/2.2));
  //   return half4(1);
     return half4(color.x, color.y, color.z, 1.0);
  //   return half4(vOut.normal.x, vOut.normal.y, vOut.normal.z, 1.0);
 }

 */
