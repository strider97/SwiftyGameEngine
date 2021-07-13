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
    float4 lightFragPos;
    float2 uv;
    float3 tangent;
    float3 biTangent;
};

enum {
    textureIndexPreFilterEnvMap,
    textureIndexDFGlut,
    textureIndexirradianceMap,
    textureIndexBaseColor,
    textureIndexMetallic,
    textureIndexRoughness,
    normalMap,
    ao,
    ltc_mat,
    ltc_mag,
    shadowMap,
    rsmPos,
    rsmNormal,
    rsmFlux,
    rsmDepth,
    textureDDGI
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
    half4 normal [[ color(0) ]];
    float4 worldPos [[ color(1) ]];
    half4 flux [[ color(2) ]];
    float depth [[ color(3)]];
};

struct Material {
    float3 baseColor;
    float roughness;
    float metallic;
    int mipmapCount;
};

constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
float insideShadow_(float4 fragPosLightSpace, float3 normal, depth2d<float, access::sample> shadowMap)
{
    // perform perspective divide
    float2 xy = fragPosLightSpace.xy;// / fragPosLightSpace.w;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    float shadowMapDepth = shadowMap.sample(s, xy);
    float currentDepth = fragPosLightSpace.z / fragPosLightSpace.w;
//    return closestDepth > 0.055;
//    return currentDepth;
    return (currentDepth < shadowMapDepth + 0.0002) ? 1.0 : 0.0;
}

float3 getNormalFromMap_(float3 worldPos, float3 normal, float2 texCoords, float3 tangentNormal) {
    float3 Q1  = dfdx(worldPos);
    float3 Q2  = dfdy(worldPos);
    float2 st1 = dfdx(texCoords);
    float2 st2 = dfdy(texCoords);

    float3 N   = normalize(normal);
    float3 T  = normalize(Q1 * st2.y - Q2 * st1.y);
    float3 B  = -normalize(cross(N, T));
    float3x3 TBN = float3x3(T, B, N);

    return normalize(TBN * tangentNormal);
}

vertex VertexOut vertexRSM(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]], constant ShadowUniforms &shadowUniforms [[buffer(2)]])  {
    VertexOut vOut;
    float4x4 PVM = uniforms.P * uniforms.V * uniforms.M;
    vOut.position = PVM * float4(vIn.position, 1.0);
    vOut.worldPos = (uniforms.M * float4(vIn.position, 1.0)).xyz;
    float3 N = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    vOut.smoothNormal = N;
    vOut.uv = float2(vIn.texCoords.x, 1-vIn.texCoords.y);
    vOut.lightFragPos = shadowUniforms.P * shadowUniforms.V * uniforms.M * float4(vIn.position, 1.0);
    vOut.tangent = vIn.tangent;
    vOut.biTangent = -cross(vIn.tangent, N);
    return vOut;
}

fragment GbufferOut fragmentRSMData (VertexOut vOut [[ stage_in ]],
                                     constant Material &material[[buffer(0)]],
                                     depth2d<float, access::sample> shadowMap [[texture(0)]],
                                     texture2d<float, access::sample> baseColorTexture [[texture(textureIndexBaseColor)]],
                                     texture2d<float, access::sample> normalMapTexture [[texture(normalMap)]],
                                     texture2d<float, access::sample> roughnessTexture [[texture(textureIndexRoughness)]],
                                     texture2d<float, access::sample> metallicTexture [[texture(textureIndexMetallic)]],
                                     texture2d<float, access::sample> AO [[texture(ao)]]) {
    GbufferOut out;
    float inShadow = insideShadow_(vOut.lightFragPos, vOut.smoothNormal, shadowMap);
    float3 baseColor = baseColorTexture.sample(s, vOut.uv).rgb;
    baseColor *= material.baseColor;
//    float4 normal = normalMapTexture.sample(s, vOut.uv);
    float roughness = roughnessTexture.sample(s, vOut.uv).r;
    float metallic = metallicTexture.sample(s, vOut.uv).r;
    
    float3 tangentNormal = normalMapTexture.sample(s, vOut.uv).xyz * 2.0 - 1.0;
    float3x3 TBN(vOut.tangent, vOut.biTangent, vOut.smoothNormal);
    float3 normal = normalize(TBN * tangentNormal);
//    float3 N = getNormalFromMap_(vOut.worldPos, vOut.smoothNormal, vOut.uv, tangentNormal);
    
//    float4 ao = AO.sample(s, vOut.uv);
    out.worldPos = float4(vOut.worldPos, roughness);
    out.normal = half4(normal.x, normal.y, normal.z, inShadow);
    out.flux = half4(baseColor.r, baseColor.g, baseColor.b, metallic);
    out.depth = vOut.position.z;
    return out;
}

//fragment GbufferOut lpvDataFragment (VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], texture2d<float, access::sample> baseColor [[texture(3)]], texture3d<float, access::write> volume [[texture(4)]]) {
//    GbufferOut out;
//    out.worldPos = float4(vOut.worldPos, 1);
//    out.normal = float4(vOut.smoothNormal, 1);
//    out.flux = float4(float3(15) * material.baseColor, 1);
//    return out;
//}
