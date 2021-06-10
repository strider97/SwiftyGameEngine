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

struct Vertex {
  float4 position [[position]];
  float2 uv;
};

constant float2 quadVertices[] = {
  float2(-1, -1),
  float2(-1,  1),
  float2( 1,  1),
  float2(-1, -1),
  float2( 1,  1),
  float2( 1, -1)
};

struct Uniforms {
    float4x4 M;
    float4x4 V;
    float4x4 P;
    float3 eye;
    float exposure;
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
    float3 smoothNormal;
    float3 normal;
    float2 texCoords;
};

struct LightProbeData {
    float3 gridEdge;
    float3 gridOrigin;
    int probeGridWidth;
    int probeGridHeight;
    int3 probeCount;
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

/*
 func indexToGridPos(_ index: Int, _ origin: Float3, _ gridEdge: Float3) -> Float3{
     let indexD = index / (width * height)
     let indexH = (index % (width * height)) / width
     let indexW = (index % (width * height)) % width
     return origin + Float3(Float(indexW), Float(indexH), Float(indexD)) * gridEdge
 }
 */

/*
int2 indexToTexPos_(int index, int width, int height){
    int indexD = index / (width * height);
    int indexH = (index % (width * height));
    return int2(indexH, indexD);
}
int2 gridPosToTex(float3 pos, float3 gridEdge, float3 gridOrigin, int probeGridWidth, int probeGridHeight) {
    float3 texPos = (pos - gridOrigin)/gridEdge;
    int index = int(texPos.z) * probeGridWidth * probeGridHeight + int(texPos.y)*probeGridWidth + int(texPos.x);
    return indexToTexPos_(index, probeGridWidth, probeGridHeight);
}*/

ushort2 gridPosToTex(float3 pos, float3 gridEdge, float3 gridOrigin, int probeGridWidth, int probeGridHeight) {
    float3 texPos_ = (pos - gridOrigin)/gridEdge;
    int3 texPos = int3(rint(texPos_.x), rint(texPos_.y), rint(texPos_.z));
    return ushort2(texPos.y * probeGridWidth + texPos.x, texPos.z);
}

vertex Vertex vertexShaderRT(unsigned short vid [[vertex_id]])
{
  float2 position = quadVertices[vid];
  Vertex out;
  out.position = float4(position, 0, 1);
  out.uv = position * 0.5 + 0.5;
  return out;
}

fragment float4 fragmentShaderRT(Vertex in [[stage_in]], texture2d<float> tex) {
  constexpr sampler s(min_filter::nearest,
                      mag_filter::nearest,
                      mip_filter::none);
  float3 color = tex.sample(s, in.uv).xyz;
  return float4(color, 1.0);
}

vertex VertexOut lightProbeVertexShader(const VertexIn vIn [[ stage_in ]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vOut;
    float4x4 VM = uniforms.V*uniforms.M;
    float4x4 PVM = uniforms.P*VM;
    vOut.m_position = PVM * float4(vIn.position, 1.0);
    vOut.position = (uniforms.M*float4(vIn.position, 1.0)).xyz;
    vOut.texCoords = float2(vIn.texCoords.x, 1 - vIn.texCoords.y);
    vOut.smoothNormal = (uniforms.M*float4(vIn.smoothNormal, 0)).xyz;
    vOut.normal = (uniforms.M*float4(vIn.normal, 0)).xyz;
    return vOut;
}

float signum(float a) {
    return a > 0 ? 1 : 0;
}

fragment float4 lightProbeFragmentShader(VertexOut vOut [[stage_in]], constant LightProbeData &probe [[buffer(0)]], texture3d<float, access::read> lightProbeTexture) {
    ushort2 texPos = gridPosToTex(vOut.position - vOut.smoothNormal * 0.2, probe.gridEdge, probe.gridOrigin, probe.probeGridWidth, probe.probeGridHeight);
    float3 col1 = lightProbeTexture.read(ushort3(texPos, 0)).rgb;
    float3 col2 = lightProbeTexture.read(ushort3(texPos, 1)).rgb;
    float colors[6] = {col1.x, col1.y, col1.z, col2.x, col2.y, col2.z};
    float3 color = 0;
    for (int i = 0; i<AMBIENT_DIR_COUNT; i++) {
        color += saturate(dot(colors[i] * ambientCubeDir[i], vOut.smoothNormal));
    }
  return float4(color * 10, 1.0);
}

uint2 indexToTexPos__(int index, int width, int height){
    int indexD = index / (width * height);
    int indexH = (index % (width * height));
    return uint2(indexH, indexD);
}

float sumVec(float3 a) {
    return a.r + a.g + a.b;
}

float3 lerp(float3 a, float3 b, float t) {
    return a*t + b*(1-t);
}

float4 lerp(float4 a, float4 b, float t) {
    return a*t + b*(1-t);
}

float4 SHProjectLinear(float3 dir) {
    float l0 = 0.282095;
    float l1 = 0.488603;
    return float4(l0, dir.y * l1, dir.z*l1, dir.x*l1);
}

kernel void accumulateKernel(constant Uniforms_ & uniforms, texture3d<float, access::read_write> lightProbeTextureR, texture3d<float, access::read_write> lightProbeTextureG, texture3d<float, access::read_write> lightProbeTextureB, texture3d<float, access::read_write> lightProbeTextureFinalR, texture3d<float, access::read_write> lightProbeTextureFinalG, texture3d<float, access::read_write> lightProbeTextureFinalB, uint2 tid [[thread_position_in_grid]])
{
  if (int(tid.x) < (uniforms.probeGridWidth * uniforms.probeGridHeight) && int(tid.y) < uniforms.probeGridHeight) {
      float t = 0.5;
    if (uniforms.frameIndex > 0) {
        float4 coeffR = 0;
        float4 coeffG = 0;
        float4 coeffB = 0;
        int samples = uniforms.probeWidth * uniforms.probeHeight;
        for(int i = 0; i < samples; i++) {
            float4 valR = lightProbeTextureR.read(ushort3(tid.x, tid.y, i));
            float3 dir = valR.xyz;
            float colR = valR.a;
            float colG = lightProbeTextureG.read(ushort3(tid.x, tid.y, i)).a;
            float colB = lightProbeTextureB.read(ushort3(tid.x, tid.y, i)).a;
            
            float4 coeffSH = SHProjectLinear(dir);
            coeffR += colR * coeffSH;
            coeffG += colG * coeffSH;
            coeffB += colB * coeffSH;
            lightProbeTextureR.write(0, ushort3(tid.x, tid.y, i));
            lightProbeTextureG.write(0, ushort3(tid.x, tid.y, i));
            lightProbeTextureB.write(0, ushort3(tid.x, tid.y, i));
        }
        
        float w = 1.0 / samples;
        coeffR *= w;
        coeffG *= w;
        coeffB *= w;
        
        float4 oldCoeffR = lightProbeTextureFinalR.read(ushort3(tid.x, tid.y, 0));
        float4 oldCoeffG = lightProbeTextureFinalG.read(ushort3(tid.x, tid.y, 0));
        float4 oldCoeffB = lightProbeTextureFinalB.read(ushort3(tid.x, tid.y, 0));
        
        lightProbeTextureFinalR.write(lerp(coeffR, oldCoeffR, t), ushort3(tid.x, tid.y, 0));
    //    lightProbeTextureFinalR.write(float4(lerp(newValue2, oldValue2, t), 1), ushort3(tid.x, tid.y, 1));
        
        lightProbeTextureFinalG.write(lerp(coeffG, oldCoeffG, t), ushort3(tid.x, tid.y, 0));
    //    lightProbeTextureFinalG.write(float4(lerp(newValue4, oldValue4, t), 1), ushort3(tid.x, tid.y, 1));
        
        lightProbeTextureFinalB.write(lerp(coeffB, oldCoeffB, t), ushort3(tid.x, tid.y, 0));
    //    lightProbeTextureFinalB.write(float4(lerp(newValue6, oldValue6, t), 1), ushort3(tid.x, tid.y, 1));
    //    lightProbeTextureFinal.write(float4(newValue1, 1), ushort3(tid.x, tid.y, 0));
    //    lightProbeTextureFinal.write(float4(newValue2, 1), ushort3(tid.x, tid.y, 1));
    }
  }
}
