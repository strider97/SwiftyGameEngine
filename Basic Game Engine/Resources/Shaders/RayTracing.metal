//
/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

// Add structs here

struct Ray {
  packed_float3 origin;
  float minDistance;
  packed_float3 direction;
  float maxDistance;
  float3 color = 0;
    float3 indirectColor = 0;
    float3 prevDirection;
};

struct Intersection {
  float distance;
  int primitiveIndex;
  float2 coordinates;
};

constant float PI = 3.14159265;
constexpr sampler s__(coord::normalized, address::repeat, filter::linear, mip_filter::linear);

constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
};

constant int AMBIENT_DIR_COUNT = 6;
constant float3 ambientCubeDir[] = {
    float3(0.7071, 0, 0.7071),
    float3(0, 1, 0),
    float3(0.7071, 0, -0.7071),
    float3(-0.7071, 0, 0.7071),
    float3(0, -1, 0),
    float3(-0.7071, 0, -0.7071)
};
constant float infDist = 10000;

float3 sphericalFibonacci(float i_, float n) {
    float i = i_ + 0.5;
    const float PHI = 1.6180339;
#   define madfrac(A, B) ((A)*(B)-floor((A)*(B)))
    float phi = 2.0 * PI * madfrac(i, PHI - 1);
    float cosTheta = 1.0 - (2.0 * i + 1.0) * (1.0 / n);
    float sinTheta = sqrt(saturate(1.0 - cosTheta * cosTheta));

    return float3(
        cos(phi) * sinTheta,
        sin(phi) * sinTheta,
        cosTheta);

#   undef madfrac
}

uint3 indexToGridPos(int index, int width, int height){
    int indexD = index / (width * height);
    int indexH = (index % (width * height)) / width;
    int indexW = (index % (width * height)) % width;
    return uint3(indexW, indexH, indexD);
}

uint2 indexToTexPos(int index, int width, int height){
    int indexD = index / (width * height);
    int indexH = (index % (width * height));
    return uint2(indexH, indexD);
}

/*
 float2 pixel = float2(tid.x % uniforms.probeWidth, tid.y % uniforms.probeHeight);
//   float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
//      r = 0;
//    pixel += r;
 float2 uv = (float2)pixel / float2(uniforms.probeWidth, uniforms.probeHeight);
 */

kernel void primaryRays(constant Uniforms_ & uniforms [[buffer(0)]],
                        device Ray *rays [[buffer(1)]],
                        device float2 *random [[buffer(2)]],
                        device LightProbe *probes [[buffer(3)]],
                        device float3 *probeDirections [[buffer(4)]],
                        texture2d<float, access::write> t [[texture(0)]],
                        uint2 tid [[thread_position_in_grid]])
{
  if (tid.x < uniforms.width && tid.y < uniforms.height && uniforms.frameIndex) {
      float2 pixel = float2(tid.x % uniforms.probeWidth, tid.y % uniforms.probeHeight);
     //   float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
     //      r = 0;
     //    pixel += r;
      float2 uv = (float2)pixel / float2(uniforms.probeWidth, uniforms.probeHeight);
    uv = uv * 2.0 - 1.0;
//    constant Camera_ & camera = uniforms.camera;
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
      
         int index = tid.x / uniforms.probeWidth;
       ray.origin = probes[index].location;
  //    ray.direction = normalize(float3(0, 1, 0));
      int rayDirIndex = tid.y*uniforms.probeWidth + tid.x % uniforms.probeWidth;
      ray.direction = probeDirections[rayDirIndex*((uniforms.frameIndex + 1) % 4000)];
  //    ray.direction = sphericalFibonacci(rayDirIndex, uniforms.probeWidth * uniforms.probeHeight);
//      ray.direction = normalize(ray.direction);
//    ray.origin = camera.position;
//    ray.direction = normalize(uv.x * camera.right + uv.y * camera.up + camera.forward);
    ray.minDistance = 0;
    ray.maxDistance = INFINITY;
    ray.color = float3(0.0);
//    t.write(float4(0.0), tid);
  }
}

// Interpolates vertex attribute of an arbitrary type across the surface of a triangle
// given the barycentric coordinates and triangle index in an intersection struct
template<typename T>
inline T interpolateVertexAttribute(device T *attributes, Intersection intersection) {
  float3 uvw;
  uvw.xy = intersection.coordinates;
  uvw.z = 1.0 - uvw.x - uvw.y;
  unsigned int triangleIndex = intersection.primitiveIndex;
  T T0 = attributes[triangleIndex * 3 + 0];
  T T1 = attributes[triangleIndex * 3 + 1];
  T T2 = attributes[triangleIndex * 3 + 2];
  return uvw.x * T0 + uvw.y * T1 + uvw.z * T2;
}

// Uses the inversion method to map two uniformly random numbers to a three dimensional
// unit hemisphere where the probability of a given sample is proportional to the cosine
// of the angle between the sample direction and the "up" direction (0, 1, 0)
inline float3 sampleCosineWeightedHemisphere(float2 u) {
  float phi = 2.0f * M_PI_F * u.x;
  
  float cos_phi;
  float sin_phi = sincos(phi, cos_phi);
  
  float cos_theta = sqrt(u.y);
  float sin_theta = sqrt(1.0f - cos_theta * cos_theta);
  
  return float3(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

// Maps two uniformly random numbers to the surface of a two-dimensional area light
// source and returns the direction to this point, the amount of light which travels
// between the intersection point and the sample point on the light source, as well
// as the distance between these two points.
inline void sampleAreaLight(constant AreaLight & light,
                            float2 u,
                            float3 position,
                            thread float3 & lightDirection,
                            thread float3 & lightColor,
                            thread float & lightDistance)
{
  // Map to -1..1
  u = u * 2.0f - 1.0f;
  
  // Transform into light's coordinate system
  float3 samplePosition = light.position +
  light.right * u.x +
  light.up * u.y;
  
  // Compute vector from sample point on light source to intersection point
  lightDirection = samplePosition - position;
  
  lightDistance = length(lightDirection);
  
  float inverseLightDistance = 1.0f / max(lightDistance, 1e-3f);
  
  // Normalize the light direction
  lightDirection *= inverseLightDistance;
  
  // Start with the light's color
  lightColor = light.color;
  
  // Light falls off with the inverse square of the distance to the intersection point
  lightColor *= (inverseLightDistance * inverseLightDistance);
  
  // Light also falls off with the cosine of angle between the intersection point and
  // the light source
  lightColor *= saturate(dot(-lightDirection, light.forward));
}

// Aligns a direction on the unit hemisphere such that the hemisphere's "up" direction
// (0, 1, 0) maps to the given surface normal direction
inline float3 alignHemisphereWithNormal(float3 sample, float3 normal) {
  // Set the "up" vector to the normal
  float3 up = normal;
  
  // Find an arbitrary direction perpendicular to the normal. This will become the
  // "right" vector.
  float3 right = normalize(cross(normal, float3(0.0072f, 1.0f, 0.0034f)));
  
  // Find a third vector perpendicular to the previous two. This will be the
  // "forward" vector.
  float3 forward = cross(right, up);
  
  // Map the direction on the unit hemisphere to the coordinate system aligned
  // with the normal.
  return sample.x * right + sample.y * up + sample.z * forward;
}

constant float2 invPi_ = float2(0.15915, 0.31831);

float2 sampleSphericalMap__(float3 dir) {
    float3 v = normalize(dir);
    float2 uv = float2(atan(-v.z/v.x), acos(v.y));
    if (v.x < 0) {
        uv.x += M_PI_F;
    }
    if (v.x >= 0 && -v.z < 0) {
        uv.x += 2*M_PI_F;
    }
    uv *= invPi_;
    return uv;
}

float2 octWrap( float2 v ) {
    return ( 1.0 - abs( v.yx ) ) * ( (v.x >= 0.0 && v.y >=0) ? 1.0 : -1.0 );
}

float signNotZero(float k) {
    return (k >= 0.0) ? 1.0 : -1.0;
}

float2 signNotZero(float2 v) {
    return float2(signNotZero(v.x), signNotZero(v.y));
}
 
float2 octEncode( float3 v ) {
    float l1norm = abs(v.x) + abs(v.y) + abs(v.z);
    float2 result = v.xy * (1.0 / l1norm);
    if (v.z < 0.0) {
        result = (1.0 - abs(result.yx)) * signNotZero(result.xy);
    }
    result = result*0.5 + 0.5;
    return result;
}
 
float3 octDecode( float2 f ) {
    f = f * 2.0 - 1.0;
 
    // https://twitter.com/Stubbesaurus/status/937994790553227264
    float3 n = float3( f.x, f.y, 1.0 - abs( f.x ) - abs( f.y ) );
    float t = saturate( -n.z );
    n.xy += (n.x >= 0.0 && n.y >=0) ? -t : t;
    return normalize( n );
}

int gridPosToProbeIndex(float3 pos, LightProbeData_ probe) {
    float3 texPos_ = (pos - probe.gridOrigin)/probe.gridEdge;
    int3 texPos = int3(texPos_);
    return  texPos.x +
            texPos.y * probe.probeCount.x +
            texPos.z * probe.probeCount.x * probe.probeCount.y;
}

float signum__(float v) {
    return v > 0 ? 1.0 : 0.0;
}

void SHProjectLinear__(float3 dir, float coeff[9]) {
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

float3 getDDGI_(float3 position,
               float3 smoothNormal,
               device LightProbe *probes,
               LightProbeData_ probeData)
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
//        float w = max(0.0001, (dot(trueDirectionToProbe, smoothNormal) + 1.0) * 0.5);
//        trilinearWeights[i] *= w*w + 0.2;
//    }
    
    int probeIndex = gridPosToProbeIndex(position, probeData);
    
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
    SHProjectLinear__(smoothNormal, shCoeff);
    float aCap[9] = {   3.141593,
                        2.094395, 2.094395, 2.094395,
                        0.785398, 0.785398, 0.785398, 0.785398, 0.785398, };
    for (int iCoeff = 0; iCoeff < 8; iCoeff++) {
        float3 color_ = 0;
        device LightProbe &probe = probes[probeIndex + lightProbeTexCoeff[iCoeff][0] +
                               lightProbeTexCoeff[iCoeff][1] * probeData.probeCount.x *
                               probeData.probeCount.y];
        for (int i = 0; i<9; i++) {
            color_.r += max(0.0, aCap[i] * probe.shCoeffR[i] * shCoeff[i]);
            color_.g += max(0.0, aCap[i] * probe.shCoeffG[i] * shCoeff[i]);
            color_.b += max(0.0, aCap[i] * probe.shCoeffB[i] * shCoeff[i]);
        }
        color += color_ * trilinearWeights[iCoeff];
    //    color += color_ * (1.0/8);
    }
  return color;
}

kernel void shadeKernel(uint2 tid [[thread_position_in_grid]],
                        constant Uniforms_ & uniforms,
                        device Ray *rays,
                        device Ray *shadowRays,
                        device Intersection *intersections,
                        device float3 *vertexColors,
                        device float3 *vertexNormals,
                        device LightProbe *probes,
                        texture3d<float, access::read> lightProbeTextureR,
                        texture3d<float, access::read> lightProbeTextureG,
                        texture3d<float, access::read> lightProbeTextureB,
                        texture2d<float, access::sample> irradianceMap)
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
    device Ray & shadowRay = shadowRays[rayIdx];
    device Intersection & intersection = intersections[rayIdx];
    float3 color = ray.color;
      shadowRay.indirectColor = 0;
      shadowRay.prevDirection = ray.direction;
    if (ray.maxDistance >= 0.0 && intersection.distance >= 0.0) {
        float3 intersectionPoint = ray.origin + ray.direction * intersection.distance;
        float3 surfaceNormal = interpolateVertexAttribute(vertexNormals,
                                                        intersection);
        surfaceNormal = normalize(surfaceNormal);
        if (dot(surfaceNormal, ray.direction) >= 0)
            return;
  //      surfaceNormal = dot(surfaceNormal, ray.direction) < 0 ? surfaceNormal : -surfaceNormal;
  //    float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
  //      r = 0;
        float3 lightDirection = uniforms.sunDirection;
        float3 lightColor = uniforms.light.color;
        float lightDistance = INFINITY;
        //    sampleAreaLight(uniforms.light, r, intersectionPoint, lightDirection, lightColor, lightDistance);
        lightColor = saturate(dot(surfaceNormal, lightDirection));
        color = interpolateVertexAttribute(vertexColors, intersection);
        shadowRay.origin = intersectionPoint + surfaceNormal * 1e-3;
        shadowRay.direction = uniforms.sunDirection;
        shadowRay.maxDistance = lightDistance;
        shadowRay.color = 4 * lightColor * color;// / max(1.0,intersection.distance * intersection.distance);
  //      shadowRay.color = max((ray.origin);
  //      shadowRay.color = 1;
  //      shadowRay.indirectColor = 1;
  //      shadowRay.color = float3(1, 0.1, 0);
        shadowRay.indirectColor = getDDGI_(shadowRay.origin, surfaceNormal, probes, uniforms.probeData);
  //      shadowRay.indirectColor = 0.1;
  //      shadowRay.indirectColor.g = 2 * getDDGI_(shadowRay.origin, surfaceNormal, lightProbeTextureG, uniforms.probeData);
  //      shadowRay.indirectColor.b = 2 * getDDGI_(shadowRay.origin, surfaceNormal, lightProbeTextureB, uniforms.probeData);
  //      shadowRay.indirectColor = 0;
      
  //    float3 sampleDirection = sampleCosineWeightedHemisphere(r);
  //    sampleDirection = alignHemisphereWithNormal(sampleDirection,
  //                                                surfaceNormal);
  //    ray.origin = intersectionPoint + surfaceNormal * 1e-3f;
  //    ray.direction = sampleDirection;
  //    ray.color = color;
        shadowRay.maxDistance = infDist + intersection.distance;
    }
    else {
        ray.maxDistance = -1.0;
        shadowRay.maxDistance = -1.0;
        float3 R = ray.direction;
        R.x = -R.x;
        R.z = -R.z;
        float3 irradiance = irradianceMap.sample(s__, sampleSphericalMap__(R)).rgb;
        irradiance = float3(113, 164, 243)/255;
    //    shadowRay.indirectColor += 0.1 * float3(0.6, 0.6, 1)*saturate(dot(ray.direction, float3(0, 1, 0)));
        shadowRay.indirectColor = irradiance;
    }
  }
}

kernel void shadowKernel(uint2 tid [[thread_position_in_grid]],
                         device Uniforms_ & uniforms,
                         device Ray *shadowRays,
                         device float *intersections,
                         texture2d<float, access::write> renderTarget,
                         texture3d<float, access::write> lightProbeTextureR,
                         texture3d<float, access::write> lightProbeTextureG,
                         texture3d<float, access::write> lightProbeTextureB,
                         texture2d<float, access::read_write> octahedralMap) {
    if (tid.x < uniforms.width && tid.y < uniforms.height) {
        unsigned int rayIdx = tid.y * uniforms.width + tid.x;
        device Ray & shadowRay = shadowRays[rayIdx];
        float intersectionDistance = intersections[rayIdx];
        float3 color = 0;
        color += shadowRay.indirectColor;
        float oldValuesR[4] = { 0, 0, 0, 0 };
        float oldValuesG[4] = { 0, 0, 0, 0 };
        float oldValuesB[4] = { 0, 0, 0, 0 };
        if ((shadowRay.maxDistance >= 0.0 && intersectionDistance < 0.0)) {
            color += shadowRay.color;
        }
        int index = tid.x / uniforms.probeWidth;
        int rayDirIndex = tid.y*uniforms.probeWidth + tid.x % uniforms.probeWidth;
        uint2 raycount = uint2(64, 64);
        float3 direction = shadowRay.prevDirection;
        uint2 texPos = indexToTexPos(index, uniforms.probeGridWidth, uniforms.probeGridHeight);
        
        if (shadowRay.maxDistance >= 0) {
            uint2 texPosOcta = texPos * raycount + uint2(octEncode(direction) * float2(raycount));
            float d = shadowRay.maxDistance - infDist;
            float d2 = d*d;
            float4 texColor = octahedralMap.read(texPosOcta);
            int frame = texColor.a;
            float d_before = texColor.r;
            float d_final = (d_before * frame + d)/(frame + 1.0);
            float d2_before = texColor.g;
            float d2_final = (d2_before * frame + d2)/(frame + 1.0);
       //     octahedralMap.write(float4(d_final, d2_final, 0, 1), texPosOcta);
            octahedralMap.write(float4(float3(d_final, d2_final, 0), frame+1), texPosOcta);
        }
        
        oldValuesR[0] = direction.x;
        oldValuesR[1] = direction.y;
        oldValuesR[2] = direction.z;
        oldValuesR[3] = color.r;
        
        oldValuesG[0] = direction.x;
        oldValuesG[1] = direction.y;
        oldValuesG[2] = direction.z;
        oldValuesG[3] = color.g;
        
        oldValuesB[0] = direction.x;
        oldValuesB[1] = direction.y;
        oldValuesB[2] = direction.z;
        oldValuesB[3] = color.b;
        
        lightProbeTextureR.write(float4(oldValuesR[0], oldValuesR[1], oldValuesR[2], oldValuesR[3]), ushort3(texPos.x, texPos.y, rayDirIndex));
     //   lightProbeTextureR.write(float4(oldValuesR[3], oldValuesR[4], oldValuesR[5], 1), ushort3(texPos.x, texPos.y, rayDirIndex*2 + 1));
        
        lightProbeTextureG.write(float4(oldValuesG[0], oldValuesG[1], oldValuesG[2], oldValuesG[3]), ushort3(texPos.x, texPos.y, rayDirIndex));
     //   lightProbeTextureG.write(float4(oldValuesG[3], oldValuesG[4], oldValuesG[5], 1), ushort3(texPos.x, texPos.y, rayDirIndex*2 + 1));
        
        lightProbeTextureB.write(float4(oldValuesB[0], oldValuesB[1], oldValuesB[2], oldValuesB[3]), ushort3(texPos.x, texPos.y, rayDirIndex));
     //   lightProbeTextureB.write(float4(oldValuesB[3], oldValuesB[4], oldValuesB[5], 1), ushort3(texPos.x, texPos.y, rayDirIndex*2 + 1));
    }
}