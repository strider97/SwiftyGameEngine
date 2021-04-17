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
    rsmDepth
};

constant float2 invPi = float2(0.15915, 0.31831);
constant float pi = 3.1415926;

constexpr sampler s(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
constexpr sampler s1(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);

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

int ClipQuadToHorizon(float3 L[5])
{
    // detect clipping config
    int config = 0;
    if (L[0].z > 0.0) config += 1;
    if (L[1].z > 0.0) config += 2;
    if (L[2].z > 0.0) config += 4;
    if (L[3].z > 0.0) config += 8;

    // clip
    int n = 0;

    if (config == 0)
    {
        // clip all
    }
    else if (config == 1) // V1 clip V2 V3 V4
    {
        n = 3;
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
        L[2] = -L[3].z * L[0] + L[0].z * L[3];
    }
    else if (config == 2) // V2 clip V1 V3 V4
    {
        n = 3;
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
    }
    else if (config == 3) // V1 V2 clip V3 V4
    {
        n = 4;
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
        L[3] = -L[3].z * L[0] + L[0].z * L[3];
    }
    else if (config == 4) // V3 clip V1 V2 V4
    {
        n = 3;
        L[0] = -L[3].z * L[2] + L[2].z * L[3];
        L[1] = -L[1].z * L[2] + L[2].z * L[1];
    }
    else if (config == 5) // V1 V3 clip V2 V4) impossible
    {
        n = 0;
    }
    else if (config == 6) // V2 V3 clip V1 V4
    {
        n = 4;
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
        L[3] = -L[3].z * L[2] + L[2].z * L[3];
    }
    else if (config == 7) // V1 V2 V3 clip V4
    {
        n = 5;
        L[4] = -L[3].z * L[0] + L[0].z * L[3];
        L[3] = -L[3].z * L[2] + L[2].z * L[3];
    }
    else if (config == 8) // V4 clip V1 V2 V3
    {
        n = 3;
        L[0] = -L[0].z * L[3] + L[3].z * L[0];
        L[1] = -L[2].z * L[3] + L[3].z * L[2];
        L[2] =  L[3];
    }
    else if (config == 9) // V1 V4 clip V2 V3
    {
        n = 4;
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
        L[2] = -L[2].z * L[3] + L[3].z * L[2];
    }
    else if (config == 10) // V2 V4 clip V1 V3) impossible
    {
        n = 0;
    }
    else if (config == 11) // V1 V2 V4 clip V3
    {
        n = 5;
        L[4] = L[3];
        L[3] = -L[2].z * L[3] + L[3].z * L[2];
        L[2] = -L[2].z * L[1] + L[1].z * L[2];
    }
    else if (config == 12) // V3 V4 clip V1 V2
    {
        n = 4;
        L[1] = -L[1].z * L[2] + L[2].z * L[1];
        L[0] = -L[0].z * L[3] + L[3].z * L[0];
    }
    else if (config == 13) // V1 V3 V4 clip V2
    {
        n = 5;
        L[4] = L[3];
        L[3] = L[2];
        L[2] = -L[1].z * L[2] + L[2].z * L[1];
        L[1] = -L[1].z * L[0] + L[0].z * L[1];
    }
    else if (config == 14) // V2 V3 V4 clip V1
    {
        n = 5;
        L[4] = -L[0].z * L[3] + L[3].z * L[0];
        L[0] = -L[0].z * L[1] + L[1].z * L[0];
    }
    else if (config == 15) // V1 V2 V3 V4
    {
        n = 4;
    }
    
    if (n == 3)
        L[3] = L[0];
    if (n == 4)
        L[4] = L[0];
    
    return n;
}

float IntegrateEdge(float3 v1, float3 v2) {
    float cosTheta = dot(v1, v2);
    float theta = acos(cosTheta);
    float res = cross(v1, v2).z * ((theta > 0.001) ? theta/sin(theta) : 1.0);

    return res;
}

float3 LTC_Evaluate(
    float3 N, float3 V, float3 P, float3x3 Minv, constant float3 *points, bool twoSided) {
    // construct orthonormal basis around N
    float3 T1, T2;
    T1 = normalize(V - N*dot(V, N));
    T2 = cross(N, T1);

    // rotate area light in (T1, T2, N) basis
    Minv = Minv * transpose(float3x3(T1, T2, N));

    // polygon (allocate 5 vertices for clipping)
    float3 L[5];
    L[0] = Minv * (points[0] - P);
    L[1] = Minv * (points[1] - P);
    L[2] = Minv * (points[2] - P);
    L[3] = Minv * (points[3] - P);

    int n = 0;
    n = ClipQuadToHorizon(L);
    
    if (n == 0)
        return float3(0, 0, 0);

    // project onto sphere
    L[0] = normalize(L[0]);
    L[1] = normalize(L[1]);
    L[2] = normalize(L[2]);
    L[3] = normalize(L[3]);
    L[4] = normalize(L[4]);

    // integrate
    float sum = 0.0;

    sum += IntegrateEdge(L[0], L[1]);
    sum += IntegrateEdge(L[1], L[2]);
    sum += IntegrateEdge(L[2], L[3]);
    if (n >= 4)
        sum += IntegrateEdge(L[3], L[4]);
    if (n == 5)
        sum += IntegrateEdge(L[4], L[0]);

    sum = twoSided ? abs(sum) : max(0.0, sum);

    float3 Lo_i = float3(sum, sum, sum);

    return Lo_i;
}

bool insideShadow(float4 fragPosLightSpace, float3 normal, float3 l, depth2d<float, access::sample> shadowMap [[texture(shadowMap)]])
{
    // perform perspective divide
    float2 xy = fragPosLightSpace.xy;// / fragPosLightSpace.w;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    float closestDepth = shadowMap.sample(s, xy);
    float currentDepth = fragPosLightSpace.z / fragPosLightSpace.w;
//    return closestDepth > 0.055;
//    return currentDepth;
    return currentDepth - 0.002 > closestDepth;
}

float3 getRSMGlobalIllumination (float4 fragPosLightSpace, float3 pos, float3 smoothNormal, depth2d<float, access::sample> shadowMap [[texture(shadowMap)]], texture2d<float, access::sample> worldPos [[texture(rsmPos)]], texture2d<float, access::sample> worldNormal [[texture(rsmNormal)]], texture2d<float, access::sample> flux [[texture(rsmFlux)]]) {
    float2 xy = fragPosLightSpace.xy;// / fragPosLightSpace.w;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    float radius = 0.16;
//    float4 bounds = clamp(float4(xy - radius, xy + radius), 0, 1);
    float samples = 00;
//    float2 sampleStep = float2(bounds.z - bounds.x, bounds.w - bounds.y)/(samples);
    float3 radiance = float3(0);
    //(s+rmaxξ1 sin(2πξ2),t +rmaxξ1 cos(2πξ2)).
    for (uint i = 0; i < samples; ++i) {
        float2 Xi = Hammersley_(i, samples);
        float2 point = float2(xy.x + radius*Xi.x*sin(2.0*pi*Xi.y), xy.y + radius*Xi.x*cos(2.0*pi*Xi.y));
        float3 N = worldNormal.sample(s1, point).rgb;
        float3 sampledLightflux = flux.sample(s1, point).rgb;
        float3 lightSamplePos = worldPos.sample(s1, point).rgb;
        float3 dist = max(0.001, length(pos - lightSamplePos));
        float3 attenuation = 1.0 / (dist * dist);
        float weight = length(point - xy);
        radiance += sampledLightflux * saturate(dot(N, pos - lightSamplePos)) * saturate(dot(smoothNormal, lightSamplePos - pos)) * weight * 10 * attenuation / (samples) ;
    }
    /*
    for(int i = 0; i<samples; i++) {
        for(int j = 0; j <samples; j++) {
            float2 point = bounds.xy + float2(j*sampleStep.x, i*sampleStep.y);
            float3 N = worldNormal.sample(s1, point).rgb;
            float3 sampledLightflux = flux.sample(s1, point).rgb;
            float3 lightSamplePos = worldPos.sample(s1, point).rgb;
            float3 dist = max(0.001, length(pos - lightSamplePos));
            float3 attenuation = 1.0 / (dist * dist);
            radiance += sampledLightflux * saturate(dot(N, pos - lightSamplePos)) * saturate(dot(smoothNormal, lightSamplePos - pos)) * attenuation / (samples * samples) ;
        }
    }
     */
//    return float3(0);
    return radiance;
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

fragment float4 basicFragmentShader(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], constant float3 *lightPolygon[[buffer(1)]], texture2d<float, access::sample> preFilterEnvMap [[texture(textureIndexPreFilterEnvMap)]], texture2d<float, access::sample> DFGlut [[texture(textureIndexDFGlut)]], texture2d<float, access::sample> irradianceMap [[texture(textureIndexirradianceMap)]], texture2d<float, access::sample> baseColor [[texture(textureIndexBaseColor)]], texture2d<float, access::sample> roughnessMap [[texture(textureIndexRoughness)]], texture2d<float, access::sample> metallicMap [[texture(textureIndexMetallic)]], texture2d<float, access::sample> normalMap [[texture(normalMap)]], texture2d<float, access::sample> aoTexture [[texture(ao)]], texture2d<float, access::sample> ltc_mat [[texture(ltc_mat)]], texture2d<float, access::sample> ltc_mag [[texture(ltc_mag)]], depth2d<float, access::sample> shadowMap [[texture(shadowMap)]], texture2d<float, access::sample> worldPos [[texture(rsmPos)]], texture2d<float, access::sample> worldNormal [[texture(rsmNormal)]], texture2d<float, access::sample> flux [[texture(rsmFlux)]]){
    
    float3 albedo = material.baseColor;
    albedo *= pow(baseColor.sample(s, vOut.texCoords).rgb, 3.0);
    float metallic = material.metallic;
    metallic *= metallicMap.sample(s, vOut.texCoords).b;
    float roughness = material.roughness;
    roughness *= roughnessMap.sample(s, vOut.texCoords).g;
    float3 eyeDir = normalize(vOut.eye - vOut.position);
    
    float3 smoothN = vOut.smoothNormal;
//    float3 tangentNormal = normalMap.sample(s, vOut.texCoords).xyz * 2.0 - 1.0;
//    float3x3 TBN(vOut.tangent, vOut.bitangent, vOut.smoothNormal);
//    float3 N = normalize(TBN * tangentNormal);
//    float3 N = getNormalFromMap(vOut.position.xyz, smoothN, vOut.texCoords, tangentNormal);
    float3 V = eyeDir;
    float3 l = vOut.sunDirection;
    bool inShadow = insideShadow(vOut.lightFragPosition, smoothN, l, shadowMap);
 //   inShadow = false;
 //   return float4(float3(inShadow), 1);
    float3 ambient = (getRSMGlobalIllumination(vOut.lightFragPosition, vOut.position, smoothN, shadowMap, worldPos, worldNormal, flux) + 0.0) * albedo;
    float3 diffuse = inShadow ? 0 : albedo * saturate(dot(smoothN, l));
    float3 color = diffuse + ambient;

    
//    float3 F0 = float3(0.04);
//    F0 = mix(F0, albedo, 1.0*metallic);
//    float3 F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
//    float3 kS = F;
//    float3 kD = float3(1.0) - kS;
//    kD *= 1.0 - metallic;
//    float3 R = N;
//    R.x = -R.x;
//    R.z = -R.z;
//    float ao = aoTexture.sample(s, vOut.texCoords).r;
//
//
//    float3 irradiance = irradianceMap.sample(s, sampleSphericalMap_(R)).rgb;
//    float3 diffuse = irradiance * albedo;
//    float3 specular = approximateSpecularIBL(F, roughness, material.mipmapCount, N, V, preFilterEnvMap, DFGlut);
//    float3 color =  kD * diffuse + specular;
    
    // calculate for area light
    /*
    float intensity = 14.0;
    float3 lightColor = float3(1, 1, 1);
    float theta = acos(dot(N, V));
    float2 uv = float2(roughness, theta/(0.5*pi));
    float4 t = ltc_mat.sample(s, uv);
    float3x3 Minv = float3x3(
                 float3(  1,   0, t.y),
                 float3(  0, t.z,   0),
                 float3(t.w,   0, t.x)
            );
    float3 spec = LTC_Evaluate(N, V, vOut.position, Minv, lightPolygon, true);
    spec *= ltc_mag.sample(s, uv).w;
    float3 diff = LTC_Evaluate(N, V, vOut.position, float3x3(1), lightPolygon, true);
    float3 colorAL = kD * albedo * diff + F * spec;
    colorAL *= lightColor * intensity / (2.0 * pi);
    color *= 0.0;
    color += max(0, colorAL);
    */
//    color *= ao;
//    return float4(abs(N), 1);
    float exposure = max(0.01, vOut.exposure);
  //  color = color / (color + float3(1.0));
    color = 1 - exp(-color * exposure);
    color = pow(color, float3(1.0/2.2));
    return float4(color, 1.0);
}

fragment float4 fragmentRSM(VertexOut vOut [[ stage_in ]], constant Material &material[[buffer(0)]], constant float3 *lightPolygon[[buffer(1)]], texture2d<float, access::sample> worldPos [[texture(rsmPos)]], texture2d<float, access::sample> worldNormal [[texture(rsmNormal)]], texture2d<float, access::sample> flux [[texture(rsmFlux)]], depth2d<float, access::sample> rsmDepth [[texture(rsmDepth)]]) {
    return float4(0);
}


