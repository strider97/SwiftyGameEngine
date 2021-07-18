//
//  BasicShaders.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 23/01/21.
//

#include <metal_stdlib>
#import "ShaderTypes.h"
using namespace metal;

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

constant float2 invPi = float2(0.15915, 0.31831);
constant float pi = 3.1415926;

constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);

constant int AMBIENT_DIR_COUNT = 6;
constant int RANDOM_KERNEL_SIZE = 64;
constant float3 ambientCubeDir[] = {
    float3(0.7071, 0, 0.7071),
    float3(0, 1, 0),
    float3(0.7071, 0, -0.7071),
    float3(-0.7071, 0, 0.7071),
    float3(0, -1, 0),
    float3(-0.7071, 0, -0.7071)
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 smoothNormal [[attribute(3)]];
    float3 tangent [[attribute(4)]];
};

struct VertexOut {
    float4 m_position [[position]];
    float3 position;
    float3 normal;
    float3 smoothNormal;
    float3 eye;
    float2 texCoords;
    float exposure;
    float3 bitangent;
    float3 tangent;
    float4 lightFragPosition;
    float3 sunDirection;
};

struct Material {
    float3 baseColor;
    float roughness;
    float metallic;
    int mipmapCount;
};

struct LightProbeData {
    float3 gridEdge;
    float3 gridOrigin;
    int probeGridWidth;
    int probeGridHeight;
    int3 probeCount;
};

struct FragmentUniform {
    float exposure;
    float normalBias;
    float depthBias;
    float ka;
    float kd;
    uint width;
    uint height;
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

float3 getNormalFromMap(float3 worldPos, float3 normal, float2 texCoords, float3 tangentNormal) {
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

float2 Hammersley_(uint i, float numSamples) {
    uint bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);
    return float2(i / numSamples, bits / exp2(32.0));
}

int gridPosToProbeIndex_(float3 pos, LightProbeData probe) {
    float3 texPos_ = (pos - probe.gridOrigin)/probe.gridEdge;
    int3 texPos = int3(texPos_);
    return  texPos.x +
            texPos.y * probe.probeGridWidth +
            texPos.z * probe.probeGridWidth * probe.probeGridHeight;
}

void SHProjectLinear_(float3 dir, float coeff[9]) {
    float l0 = 0.282095;
    float l1 = 0.488603;
    float l20 = 1.092548;
    float l21 = 0.315392;
    float l22 = 0.546274;
    float x = dir.x, y = dir.y, z = dir.z;
    
    coeff[0] = l0;
    coeff[1] = y * l1;
    coeff[2] = z * l1;
    coeff[3] = x * l1;
    
    coeff[4] = x * y * l20;
    coeff[5] = y * z * l20;
    coeff[6] = (3*z*z - 1.0) * l21;
    coeff[7] = x * z * l20;
    coeff[8] = (x*x - y*y) * l22;
}

float signum_(float v) {
    return v > 0 ? 1.0 : (v+1);
}

constant float3 probePos[8] = {
    float3(0, 0, 0),
    float3(1, 0, 0),
    float3(0, 1, 0),
    float3(1, 1, 0),
    
    float3(0, 0, 1),
    float3(1, 0, 1),
    float3(0, 1, 1),
    float3(1, 1, 1),
};

float ScTP(float3 a, float3 b, float3 c) {
    return dot(cross(a, b), c);
}

float4 bary_tet(float3 a, float3 b, float3 c, float3 d, float3 p)
{
    float3 vap = p - a;
    float3 vbp = p - b;

    float3 vab = b - a;
    float3 vac = c - a;
    float3 vad = d - a;

    float3 vbc = c - b;
    float3 vbd = d - b;
    // ScTP computes the scalar triple product
    float va6 = ScTP(vbp, vbd, vbc);
    float vb6 = ScTP(vap, vac, vad);
    float vc6 = ScTP(vap, vad, vab);
    float vd6 = ScTP(vap, vab, vac);
    float v6 = 1 / ScTP(vab, vac, vad);
    return float4(va6*v6, vb6*v6, vc6*v6, vd6*v6);
}

uint2 indexToTexPos___(int index, int width, int height){
    int indexD = index / (width * height);
    int indexH = (index % (width * height));
    return uint2(indexH, indexD);
}

float2 octWrap_( float2 v ) {
    return ( 1.0 - abs( v.yx ) ) * ( (v.x >= 0.0 && v.y >=0) ? 1.0 : -1.0 );
}

float signNotZero_(float k) {
    return (k >= 0.0) ? 1.0 : -1.0;
}

float2 signNotZero_(float2 v) {
    return float2(signNotZero_(v.x), signNotZero_(v.y));
}
 
float2 octEncode_( float3 v ) {
    float l1norm = abs(v.x) + abs(v.y) + abs(v.z);
    float2 result = v.xy * (1.0 / l1norm);
    if (v.z < 0.0) {
        result = (1.0 - abs(result.yx)) * signNotZero_(result.xy);
    }
    result = result*0.5 + 0.5;
    return result;
}

float sq(float s) {
    return s*s;
}

float pow3(float s) { return s*s*s; }
int signOf(float a) {
    return a >= 0 ? 1 : -1;
}

float3 getDDGI(float3 position,
               float3 smoothNormal,
               FragmentUniform uniforms,
               device LightProbe *probes,
               LightProbeData probeData,
               texture2d<float, access::sample> octahedralMap,
               texture2d<float, access::sample> radianceMap)
{
    float3 transformedPos = (position - probeData.gridOrigin)/probeData.gridEdge;
    transformedPos -= float3(int3(transformedPos));
    float x = transformedPos.x;
    float y = transformedPos.y;
    float z = transformedPos.z;
    
    float trilinearWeights[8] = {
        (1 - x)*(1 - y)*(1 - z),
        x*(1 - y)*(1 - z),
        (1 - x)*y*(1 - z),
        x*y*(1 - z),

        (1 - x)*(1 - y)*z,
        x*(1 - y)*z,
        (1 - x)*y*z,
        x*y*z,
    };
    
//    for(int i = 0; i < 8; i++) {
//        float3 trueDirectionToProbe = normalize(probePos[i] - transformedPos);
//        float w = max(0.0001, signum_(dot(trueDirectionToProbe, smoothNormal)) * 1);
//        trilinearWeights[i] *= w*w + 0.2;
//    }
    
    int probeIndex = gridPosToProbeIndex_(position, probeData);
    
    ushort2 lightProbeTexCoeff[8] = {
        ushort2(0, 0),
        ushort2(1, 0),
        ushort2(probeData.probeCount.x, 0),
        ushort2(probeData.probeCount.x + 1, 0),
        ushort2(0, 1),
        ushort2(1, 1),
        ushort2(probeData.probeCount.x, 1),
        ushort2(probeData.probeCount.x + 1, 1)
    };
    
    float3 color = 0;
    float shCoeff[9];
    SHProjectLinear_(smoothNormal, shCoeff);
    float aCap[9] = {   3.141593,
                        2.094395, 2.094395, 2.094395,
                        0.785398, 0.785398, 0.785398, 0.785398, 0.785398, };
    for (int iCoeff = 0; iCoeff < 8; iCoeff++) {
        float3 color_ = 0;
        int index = probeIndex +
                    lightProbeTexCoeff[iCoeff][0] +
                    lightProbeTexCoeff[iCoeff][1] * probeData.probeGridWidth * probeData.probeGridHeight;
        device LightProbe &probe = probes[index];
        
        float normalBias = uniforms.normalBias;
        float depthBias = uniforms.depthBias;
        float3 dirFromProbe = normalize(position - (probe.location + probe.offset));
        float dotPN = dot(dirFromProbe, smoothNormal);
        if (dotPN > 0)
            continue;
    //    int signDot = signOf(-dotPN);
    //    normalBias *= signDot;
    //    depthBias *= signDot;
    //    float w = max(0.0001, signum_(-dotPN) * 1);
    //    trilinearWeights[iCoeff] *= w*w + 0.2;
        
        float3 newPosition = position + normalBias * smoothNormal;
        dirFromProbe = normalize(newPosition - (probe.location + probe.offset));
        float distToProbe = length(newPosition - (probe.location + probe.offset));
        uint2 texPos = indexToTexPos___(index, probeData.probeGridWidth, probeData.probeGridHeight);
        int shadowProbeReso = 64;
        int3 probeCount = probeData.probeCount;
        float2 encodedUV = octEncode_(dirFromProbe);
        float2 encodedUV_ = octEncode_(smoothNormal);
        float minimumUV = 1.0/shadowProbeReso;
        if (encodedUV.x < minimumUV)
            encodedUV.x += minimumUV;
        if (encodedUV.x > 1-minimumUV)
            encodedUV.x -= minimumUV;
        if (encodedUV.y < minimumUV)
            encodedUV.y += minimumUV;
        if (encodedUV.y > 1-minimumUV)
            encodedUV.y -= minimumUV;
        
        int radianceMapSize = 16;
        minimumUV = 1.0/radianceMapSize;
        if (encodedUV_.x < minimumUV)
            encodedUV_.x += minimumUV;
        if (encodedUV_.x > 1-minimumUV)
            encodedUV_.x -= minimumUV;
        if (encodedUV_.y < minimumUV)
            encodedUV_.y += minimumUV;
        if (encodedUV_.y > 1-minimumUV)
            encodedUV_.y -= minimumUV;
            
        float2 uv = (float2(texPos) + encodedUV)*float2(1.0/(probeCount.x * probeCount.y), 1.0/probeCount.z);
        float4 d = octahedralMap.sample(s, uv);
        
        float2 uv_ = (float2(texPos) + encodedUV_)*float2(1.0/(probeCount.x * probeCount.y), 1.0/probeCount.z);
        color_ = radianceMap.sample(s, uv_).rgb;
        
        float2 temp = d.rg;
        float mean = temp.x;
        float variance = abs(sq(temp.x) - temp.y);

        /// http://www.punkuser.net/vsm/vsm_paper.pdf; equation 5
        /// Need the max in the denominator because biasing can cause a negative displacement
        float chebyshevWeight = variance / (variance + sq(max(distToProbe - mean, 0.0)));
            
        /// Increase contrast in the weight
        chebyshevWeight = max(pow3(chebyshevWeight), 0.0);

        float finalShadowingWeight = (distToProbe <= mean + depthBias || d.a == 0.0 ) ? 1.0 : chebyshevWeight;
        
//        for (int i = 0; i<9; i++) {
//            color_.r += max(0.0, aCap[i] * probe.shCoeffR[i] * shCoeff[i]);
//            color_.g += max(0.0, aCap[i] * probe.shCoeffG[i] * shCoeff[i]);
//            color_.b += max(0.0, aCap[i] * probe.shCoeffB[i] * shCoeff[i]);
//        }
        color += color_ * trilinearWeights[iCoeff] * finalShadowingWeight;
    //    color += color_ * (1.0/8);
    }
  return color;
}

float getSSAO(float3 origin, float3 normal, float3 noise, float4x4 P, constant float3* uSampleKernel, depth2d<float, access::sample> depthTex) {
    float3 rvec = noise;
    float3 tangent = normalize(rvec - normal * dot(rvec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 tbn = float3x3(tangent, bitangent, normal);
    float occlusion = 0.0;
    float uRadius = 0.5;
    for (int i = 0; i < 16; i++) {
    // get sample position:
        float3 sample = tbn * uSampleKernel[i];
        sample = sample * uRadius + origin;

        // project sample position:
        float4 offset = float4(sample, 1.0);
        offset = P * offset;
        offset.xy /= offset.w;
        offset.xy = offset.xy * 0.5 + 0.5;

        // get sample depth:
        float sampleDepth = depthTex.sample(s, offset.xy);

        // range check & accumulate:
        float rangeCheck= abs(origin.z - sampleDepth) < uRadius ? 1.0 : 0.0;
        occlusion += (sampleDepth <= sample.z ? 1.0 : 0.0) * rangeCheck;
    }
    occlusion = 1.0 - (occlusion / RANDOM_KERNEL_SIZE);
    return occlusion;
}

vertex VertexOut basicVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]], constant ShadowUniforms &shadowUniforms [[buffer(2)]])  {
    VertexOut vOut;
    float4x4 VM = uniforms.V*uniforms.M;
    float4x4 PVM = uniforms.P*VM;
    float4x4 lightPV = shadowUniforms.P * shadowUniforms.V;
    vOut.m_position = PVM * float4(vIn.position, 1.0);
    vOut.normal = (uniforms.M*float4(vIn.normal, 0)).xyz;
    vOut.position = (uniforms.M*float4(vIn.position, 1.0)).xyz;
    vOut.texCoords = float2(vIn.texCoords.x, 1 - vIn.texCoords.y);
    vOut.eye = uniforms.eye;
    vOut.smoothNormal = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    vOut.exposure = uniforms.exposure;
    vOut.tangent = (uniforms.M*float4(vIn.tangent, 0)).xyz;
    vOut.bitangent = (uniforms.M*float4(cross(vIn.normal, vIn.tangent), 0)).xyz;
    vOut.lightFragPosition = lightPV * uniforms.M * float4(vIn.position, 1.0);
    vOut.sunDirection = shadowUniforms.sunDirection;
    return vOut;
}

struct SimpleVertexDR {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOutDR {
    float4 position [[position]];
    float3 textureDir;
    float2 pos;
    float2 color;
};

vertex VertexOutDR DeferredRendererVS (const SimpleVertexDR vIn [[ stage_in ]]) {
    VertexOutDR vOut;
//    vOut.pos = (float2(vIn.position.x, vIn.position.y)+1.0)/2.0;
    vOut.pos = float2(vIn.color.x, 1 - vIn.color.y);
    vOut.position = float4(vIn.position, 1);
    vOut.color = vIn.color.xy;
    return vOut;
}

kernel void DefferedShadeKernel(uint2 tid [[thread_position_in_grid]],
                                constant ShadowUniforms &shadowUniforms [[buffer(0)]],
                                constant LightProbeData &probe [[buffer(1)]],
                                constant FragmentUniform &uniforms [[buffer(2)]],
                                constant float3 *kernelAndNoise [[buffer(3)]],
                                device LightProbe *probes [[buffer(4)]],
                                texture2d<float, access::sample> worldPos [[texture(rsmPos)]],
                                texture2d<float, access::sample> worldNormal [[texture(rsmNormal)]],
                                texture2d<float, access::sample> albedoTex [[texture(rsmFlux)]],
                                depth2d<float, access::sample> depthTex [[texture(rsmDepth)]],
                                texture2d<float, access::write> outputTex [[texture(0)]],
                                texture2d<float, access::sample> octahedralMap[[texture(10)]],
                                texture2d<float, access::sample> radianceMap[[texture(1)]]) {
    if (tid.x < uniforms.width && tid.y < uniforms.height) {
        float2 uv = float2(tid)/float2(uniforms.width, uniforms.height);
        float3 pos = worldPos.sample(s, uv).rgb;
        float4 normalShadow = worldNormal.sample(s, uv);
        float3 smoothN = normalShadow.xyz;
        float4 albedo_ = albedoTex.sample(s, uv);
        float3 albedo = albedo_.rgb;
        if(albedo.r==0 && albedo.g==0 && albedo.b==0 ) {
            outputTex.write(float4(113, 164, 243, 255)/255, tid);
            return;
        }
    //    albedo = 0.8;
        float3 l = shadowUniforms.sunDirection;
        float inShadow = normalShadow.a;
        
        float3 ambient = 0;
        ambient = (getDDGI(pos, smoothN, uniforms, probes, probe, octahedralMap, radianceMap) + 0.0000);
        float3 diffuse = inShadow * 4.0 * albedo * saturate(dot(smoothN, l));
        float3 color = uniforms.kd * diffuse + uniforms.ka * ambient * albedo;
        
    //    float4x4 PV = shadowUniforms.P * shadowUniforms.V;
    //    float ssao = getSSAO(pos, smoothN, kernelAndNoise[64 + tid.x % 16], PV, kernelAndNoise, depthTex);
        
        float exposure = uniforms.exposure;
        color = 1 - exp(-color * exposure);
        color = pow(color, float3(1.0/2.2));
    //    color = ssao * albedo;
    //    color = float3(kernelAndNoise[64 + tid.x % 16].xy, 1);
        outputTex.write(float4(color, 1), tid);
    }
}

fragment float4 DeferredRendererFS_(VertexOutDR vOut [[ stage_in ]], texture2d<float, access::sample> radianceTex [[texture(0)]]) {
    float4 radiance = radianceTex.sample(s, vOut.pos);
    return radiance;
}
