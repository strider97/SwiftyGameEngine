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
    float4 lightFragPos;
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

constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);

float4 SHRotate(const float3 vcDir, const float2 vZHCoeffs) {
 // compute sine and cosine of thetta angle
 // beware of singularity when both x and y are 0 (no need to rotate at all)
    float2 theta12_cs = normalize(vcDir.xy);
    // compute sine and cosine of phi angle
    float2 phi12_cs;
    phi12_cs.x = sqrt(1.0 - vcDir.z * vcDir.z);
    phi12_cs.y = vcDir.z;
    float4 vResult;
    // The first band is rotation-independent
    vResult.x = vZHCoeffs.x;
    // rotating the second band of SH
    vResult.y = vZHCoeffs.y * phi12_cs.x * theta12_cs.y;
    vResult.z = -vZHCoeffs.y * phi12_cs.y;
    vResult.w = vZHCoeffs.y * phi12_cs.x * theta12_cs.x;
    return vResult;
}

float4 SHProject(const float3 vcDir) {
    const float2 vZHCoeffs = float2(.25, .5);
    return SHRotate(vcDir, vZHCoeffs);
}

ushort3 getTexelForPos(const float3 pos, const int d) {
//   return ushort3(pos + 32);
    return ushort3((pos + float3(20.0, 1.0, 14.0))*float3(d/40.0, d/16.0, d/28.0));
}

bool insideShadow_(float4 fragPosLightSpace, depth2d<float, access::sample> shadowMap [[texture(0)]]) {
    // perform perspective divide
    float2 xy = fragPosLightSpace.xy;// / fragPosLightSpace.w;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    float closestDepth = shadowMap.sample(s, xy);
    float currentDepth = fragPosLightSpace.z / fragPosLightSpace.w;
    return currentDepth - 0.00001 > closestDepth;
}

vertex VertexOut vertexRSM(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]], constant ShadowUniforms &shadowUniforms [[buffer(2)]])  {
    VertexOut vOut;
    float4x4 PVM = shadowUniforms.P * shadowUniforms.V * uniforms.M;
    vOut.position = PVM * float4(vIn.position, 1.0);
    vOut.worldPos = (uniforms.M * float4(vIn.position, 1.0)).xyz;
    vOut.smoothNormal = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    vOut.uv = float2(vIn.texCoords.x, 1-vIn.texCoords.y);
    vOut.lightFragPos = PVM * float4(vIn.position, 1.0);
    return vOut;
}

fragment GbufferOut fragmentRSMData (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColor [[texture(3)]]) {
    GbufferOut out;
    out.worldPos = float4(vOut.worldPos, 1);
    out.normal = float4(vOut.smoothNormal, 1);
    out.flux = float4(float3(15) * material.baseColor, 1);
    return out;
}

fragment GbufferOut lpvDataFragment (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColor [[texture(3)]], texture3d<float, access::read_write> volume [[texture(4)]], depth2d<float, access::sample> shadowMap [[texture(0)]]) {
    GbufferOut out;
    out.worldPos = float4(vOut.worldPos, 1);
    out.normal = float4(vOut.smoothNormal, 1);
    float3 flux = float3(15) * material.baseColor;
    out.flux = float4(flux, 1);
    
    /// SHprojection
    
    bool inShadow = insideShadow_(vOut.lightFragPos, shadowMap);
    if (inShadow)
        return out;
    float d = volume.get_depth();
    ushort3 texelPos = getTexelForPos(vOut.worldPos, d);
    float4 coeff = volume.read(texelPos) + SHProject(out.normal.xyz);// * max3(flux.r, flux.g, flux.b);
    volume.write(coeff, texelPos);
//    volume.write(float4(vOut.smoothNormal, 1), texelPos);
    return out;
}

//(-20, -1, -14)
//(20, 15, 14)
