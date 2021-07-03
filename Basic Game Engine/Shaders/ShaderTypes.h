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

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct Camera_ {
  vector_float3 position;
  vector_float3 right;
  vector_float3 up;
  vector_float3 forward;
};

struct AreaLight {
  vector_float3 position;
  vector_float3 forward;
  vector_float3 right;
  vector_float3 up;
  vector_float3 color;
};

struct LightProbeData_ {
    vector_float3 gridEdge;
    vector_float3 gridOrigin;
    int probeGridWidth;
    int probeGridHeight;
    vector_int3 probeCount;
};

struct IrradianceField_ {
    unsigned int probeCount;
    unsigned int width;
    unsigned int height;
    unsigned int depth;
    vector_float3 origin;
    vector_float3 gridEdges;
};

struct Uniforms_
{
    unsigned int width;
    unsigned int height;
    unsigned int blocksWide;
    unsigned int frameIndex;
    struct Camera_ camera;
    struct AreaLight light;
    vector_float3 sunDirection;
    int probeWidth;
    int probeHeight;
    int probeGridWidth;
    int probeGridHeight;
    struct LightProbeData_ probeData;
};

struct LightProbe {
    vector_float3 location;
    float shCoeff[9];
};

#endif /* ShaderTypes_h */

