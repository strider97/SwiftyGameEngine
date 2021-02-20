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
};

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
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

float3 ImportanceSampleGGX( float2 Xi, float Roughness, float3 N )
{
    float a = Roughness * Roughness;
    float Phi = 2 * pi * Xi.x;
    float CosTheta = sqrt( (1 - Xi.y) / ( 1 + (a*a - 1) * Xi.y ) );
    float SinTheta = sqrt( 1 - CosTheta * CosTheta );
    float3 H;
    H.x = SinTheta * cos( Phi );
    H.y = SinTheta * sin( Phi );
    H.z = CosTheta;
    float3 UpVector = abs(N.z) < 0.999 ? float3(0,0,1) : float3(1,0,0);
    float3 TangentX = normalize( cross( UpVector, N ) );
    float3 TangentY = cross( N, TangentX );
    // Tangent to world space
    return TangentX * H.x + TangentY * H.y + N * H.z;
}

float3 prefilterEnvMap(float Roughness, float3 R, texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 N = R;
    float3 V = R;
    float totalWeight = 0.00001;
    float3 PrefilteredColor = 0;
    const uint numSamples = 4096;
    for( uint i = 0; i < numSamples; i++ ){
        float2 Xi = Hammersley(i, numSamples);
        float3 H = ImportanceSampleGGX( Xi, Roughness, N );
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

fragment float4 irradianceMapFragmentShader (VertexOut vOut [[ stage_in ]], texture2d<float, access::sample> baseColorTexture [[texture(3)]], sampler baseColorSampler [[sampler(0)]]) {
    float3 textureDir = getDirectionForPoint(vOut.pos);
 //   float3 skyColor = baseColorTexture.sample(baseColorSampler, sampleSphericalMap(textureDir)).rgb;
    float roughness = 0.4;
    float3 skyColor = prefilterEnvMap(roughness * roughness, textureDir, baseColorTexture, baseColorSampler);
//    skyColor = pow(skyColor, float3(1.0/2.2));
//    skyColor = vOut.position.xyz;
//    skyColor = textureDir;
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

float2 IntegrateBRDF( float r, float NoV ) {
    float Roughness = r;
    float3 V;
    V.x = sqrt( 1.0f - NoV * NoV ); // sin
    V.y = 0;
    V.z = NoV; // cos
    float3 N = float3(0.0f,0.0f,1.0f);
    float A = 0;
    float B = 0;
    const uint NumSamples = 1024;
    for( uint i = 0; i < NumSamples; i++ )
    {
        float2 Xi = Hammersley( i, NumSamples );
        float3 H = ImportanceSampleGGX( Xi, Roughness, N);
        float3 L = 2 * dot( V, H ) * H - V;
        float NoL = saturate( L.z );
        float NoH = saturate( H.z );
        float VoH = saturate( dot( V, H ) );
        if( NoL > 0 ) {
            float G = G_Smith( Roughness, NoV, NoL);
            float G_Vis = G * VoH / (NoH * NoV);
            float Fc = pow( 1 - VoH, 5 );
            A += (1 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }
    return float2( A, B ) / NumSamples;
}

vertex VertexOut DFGVertexShader (const SimpleVertex vIn [[ stage_in ]]) {
    VertexOut vOut;
    vOut.pos = (float2(vIn.position.x, vIn.position.y)+1.0)/2.0;
    vOut.position = float4(vIn.position, 1);
    return vOut;
}

fragment float4 DFGFragmentShader (VertexOut vOut [[ stage_in ]]) {
    float2 dfgLut = IntegrateBRDF(vOut.pos.x, vOut.pos.y);
    dfgLut = pow(dfgLut, float2(1.0/2.2));
    float4 color = float4(dfgLut, 0.0, 1);
 //   float4 color = float4(vOut.pos, 0.0, 1);
    return color;
}
