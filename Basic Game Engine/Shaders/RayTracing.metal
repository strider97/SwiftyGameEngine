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
  float3 color;
};

struct Intersection {
  float distance;
  int primitiveIndex;
  float2 coordinates;
};

constant float PI = 3.14159265;

constant unsigned int primes[] = {
    2,   3,  5,  7,
    11, 13, 17, 19,
    23, 29, 31, 37,
    41, 43, 47, 53,
};

constant int AMBIENT_DIR_COUNT = 6;
constant float3 ambientCubeDir[] = {
    float3(1, 0, 0),
    float3(0, 1, 0),
    float3(0, 0, 1),
    float3(-1, 0, 0),
    float3(0, -1, 0),
    float3(0, 0, -1)
};

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
                        constant float3 *probeLocations [[buffer(3)]], device float3 *probeDirections [[buffer(4)]],
                        texture2d<float, access::write> t [[texture(0)]],
                        uint2 tid [[thread_position_in_grid]])
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
      float2 pixel = float2(tid.x % uniforms.probeWidth, tid.y % uniforms.probeHeight);
     //   float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
     //      r = 0;
     //    pixel += r;
      float2 uv = (float2)pixel / float2(uniforms.probeWidth, uniforms.probeHeight);
    uv = uv * 2.0 - 1.0;
    constant Camera_ & camera = uniforms.camera;
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
      
         int index = tid.x / uniforms.probeWidth;
       ray.origin = probeLocations[index];
  //    ray.direction = normalize(float3(0, 1, 0));
      int rayDirIndex = tid.y*uniforms.probeWidth + tid.x % uniforms.probeWidth;
      ray.direction = probeDirections[rayDirIndex];
//      ray.direction = normalize(ray.direction);
//    ray.origin = camera.position;
//    ray.direction = normalize(uv.x * camera.right + uv.y * camera.up + camera.forward);
    ray.minDistance = 0;
    ray.maxDistance = INFINITY;
    ray.color = float3(0.0);
    t.write(float4(0.0), tid);
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

kernel void shadeKernel(uint2 tid [[thread_position_in_grid]],
                        constant Uniforms_ & uniforms,
                        device Ray *rays,
                        device Ray *shadowRays,
                        device Intersection *intersections,
                        device float3 *vertexColors,
                        device float3 *vertexNormals,
                        device float2 *random,
                        texture2d<float, access::write> renderTarget)
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
    device Ray & shadowRay = shadowRays[rayIdx];
    device Intersection & intersection = intersections[rayIdx];
    float3 color = ray.color;
    if (ray.maxDistance >= 0.0 && intersection.distance >= 0.0) {
      float3 intersectionPoint = ray.origin + ray.direction
      * intersection.distance;
      float3 surfaceNormal = interpolateVertexAttribute(vertexNormals,
                                                        intersection);
      surfaceNormal = normalize(surfaceNormal);
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
      shadowRay.color = lightColor * color;
    //    shadowRay.color = abs(surfaceNormal)*2;
      
  //    float3 sampleDirection = sampleCosineWeightedHemisphere(r);
  //    sampleDirection = alignHemisphereWithNormal(sampleDirection,
  //                                                surfaceNormal);
  //    ray.origin = intersectionPoint + surfaceNormal * 1e-3f;
  //    ray.direction = sampleDirection;
  //    ray.color = color;
    }
    else {
        ray.maxDistance = -1.0;
        shadowRay.maxDistance = -1.0;
    //    shadowRay.color = saturate(dot(ray.direction, uniforms.sunDirection));
        shadowRay.color = 0;
    }
  }
}

kernel void shadowKernel(uint2 tid [[thread_position_in_grid]], device Uniforms_ & uniforms, device Ray *shadowRays, device float *intersections, device float3 *probeLocations [[buffer(3)]], device float3 *probeDirections [[buffer(4)]], texture2d<float, access::read_write> renderTarget, texture3d<float, access::read_write> lightProbeTexture) {
    if (tid.x < uniforms.width && tid.y < uniforms.height) {
        unsigned int rayIdx = tid.y * uniforms.width + tid.x;
        device Ray & shadowRay = shadowRays[rayIdx];
        float intersectionDistance = intersections[rayIdx];
        float3 color = 0;
        if ((shadowRay.maxDistance >= 0.0 && intersectionDistance < 0.0)) {
            color = shadowRay.color;
      //    color += renderTarget.read(tid).xyz;
      //    renderTarget.write(float4(color, 1.0), tid);
            
          int index = tid.x / uniforms.probeWidth;
            int rayDirIndex = tid.y*uniforms.probeWidth + tid.x % uniforms.probeWidth;
            float3 direction = probeDirections[rayDirIndex];
            direction = normalize(direction);
          uint2 texPos = indexToTexPos(index, uniforms.probeGridWidth, uniforms.probeGridHeight);
          float3 oldValue1 = lightProbeTexture.read(ushort3(texPos.x, texPos.y, 0)).rgb;
          float3 oldValue2 = lightProbeTexture.read(ushort3(texPos.x, texPos.y, 1)).rgb;
          float oldValues[6] = {oldValue1.x, oldValue1.y, oldValue1.z, oldValue2.x, oldValue2.y, oldValue2.z};
          float newValues[6] = { 0, 0, 0, 0, 0, 0 };
          for (int i = 0; i<AMBIENT_DIR_COUNT; i++) {
              float newValue = max(0.0, dot(direction * color, ambientCubeDir[i]));
              newValues[i] = mix(oldValues[i], newValue, 0.04);
          //    newValues[i] = oldValues[i] + newValue*0.06;
          //    newValues[i] = shadowRay.color.r;
          //    newValues[i] = newValue;
          }
          lightProbeTexture.write(float4(newValues[0], newValues[1], newValues[2], 1), ushort3(texPos.x, texPos.y, 0));
          lightProbeTexture.write(float4(newValues[3], newValues[4], newValues[5], 1), ushort3(texPos.x, texPos.y, 1));
        }
    }
}
