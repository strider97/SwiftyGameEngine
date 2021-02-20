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

struct SimpleVertex {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 textureDir;
    float2 pos;
    float2 color;
};

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
};

struct Material {
    float3 baseColor;
    float roughness;
    int mipmapCount;
};

constant float2 invPi = float2(0.15915, 0.31831);
constant float pi = 3.1415926;

float2 sampleSphericalMap(float3 dir) {
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

// Irradiance map

float2 Hammersley(uint i, float numSamples) {
    uint bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);
    return float2(i / numSamples, bits / exp2(32.0));
}

float3 ImportanceSampleGGX(float2 Xi, float3 N, float roughness)
{
    float a = roughness*roughness;
    
    float phi = 2.0 * pi * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
    
    // from spherical coordinates to cartesian coordinates - halfway vector
    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
    
    // from tangent-space H vector to world-space sample vector
    float3 up          = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent   = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);
    
    float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

float3 prefilterEnvMap(float Roughness, float3 R, texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 N = R;
    float3 V = R;
    float totalWeight = 0.00001;
    float3 PrefilteredColor = 0;
    const uint numSamples = 4096;
    for( uint i = 0; i < numSamples; i++ ){
        float2 Xi = Hammersley(i, numSamples);
        float3 H = ImportanceSampleGGX( Xi, N, Roughness );
        float3 L = 2 * dot( V, H ) * H - V;
        float NoL = saturate( dot( N, L ) );
        if( NoL > 0 ) {
        //    NoL = 1;
            PrefilteredColor += min(100.0, baseColorTexture.sample(baseColorSampler, sampleSphericalMap(L)).rgb) * NoL;
            totalWeight += NoL;
        }
    }
//    totalWeight = numSamples;
    return PrefilteredColor / totalWeight;
}

float3 getDirectionForPoint(float2 point) {
    float2 p = (point + 1.0)/2.0;
    float theta = p.x * 2.0 * pi;
    float phi = p.y * pi;
    float3 dir = float3(-sin(phi)*cos(theta), cos(phi), sin(phi)*sin(theta));
    return dir;
}

vertex VertexOut irradianceMapVertexShader (const SimpleVertex vIn [[ stage_in ]]) {
    VertexOut vOut;
    vOut.pos = float2(vIn.position.x, -vIn.position.y);
    vOut.position = float4(vIn.position, 1);
    return vOut;
}

fragment float4 irradianceMapFragmentShader (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 textureDir = getDirectionForPoint(vOut.pos);
    float roughness = material.roughness;
    float3 skyColor = prefilterEnvMap(roughness * roughness, textureDir, baseColorTexture, baseColorSampler);
    float4 color = min(float4(exp2(10.0)), float4(abs(skyColor.x), abs(skyColor.y), abs(skyColor.z), 1.0));
    return color;
}


//DFG LUT
float G1V_Epic(float Roughness, float NoV) {
    // no hotness remapping for env BRDF as suggested by Brian Karis
    float k = Roughness * Roughness;
    return NoV / (NoV * (1.0f - k) + k);
}

float G_Smith(float Roughness, float NoV, float NoL) {
    return G1V_Epic(Roughness, NoV) * G1V_Epic(Roughness, NoL);
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    // note that we use a different k for IBL
    float a = roughness;
    float k = (a * a) / 2.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(float3 N, float3 V, float3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float2 IntegrateBRDF( float r, float NoV ) {
    float3 V;
    float roughness = r;
    V.x = sqrt(1.0 - NoV*NoV);
    V.y = 0.0;
    V.z = NoV;

    float A = 0.0;
    float B = 0.0;

    float3 N = float3(0.0, 0.0, 1.0);
    
    const uint SAMPLE_COUNT = 1024u;
    for(uint i = 0u; i < SAMPLE_COUNT; ++i)
    {
        // generates a sample vector that's biased towards the
        // preferred alignment direction (importance sampling).
        float2 Xi = Hammersley(i, SAMPLE_COUNT);
        float3 H = ImportanceSampleGGX(Xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(L.z, 0.0);
        float NdotH = max(H.z, 0.0);
        float VdotH = max(dot(V, H), 0.0);

        if(NdotL > 0.0)
        {
            float G = GeometrySmith(N, V, L, roughness);
            float G_Vis = (G * VdotH) / (NdotH * NoV);
            float Fc = pow(1.0 - VdotH, 5.0);

            A += (1.0 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    A /= float(SAMPLE_COUNT);
    B /= float(SAMPLE_COUNT);
    return float2(A, B);
}

vertex VertexOut DFGVertexShader (const SimpleVertex vIn [[ stage_in ]]) {
    VertexOut vOut;
    vOut.pos = (float2(vIn.position.x, vIn.position.y)+1.0)/2.0;
    vOut.position = float4(vIn.position, 1);
    vOut.color = vIn.color.xy;
    return vOut;
}

fragment float4 DFGFragmentShader (VertexOut vOut [[ stage_in ]]) {
    float2 dfgLut = IntegrateBRDF(vOut.color.x, vOut.color.y);
//    dfgLut = pow(dfgLut, float2(1.0/2.2));
    float4 color = float4(dfgLut, 0.0, 1);
//     color = float4(vOut.color, 0.0, 1);
    return color;
}
