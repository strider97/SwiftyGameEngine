//
//  brdfFitShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 07/03/21.
//

#include <metal_stdlib>
using namespace metal;

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

vertex VertexOut brdfFitVertexShader (const SimpleVertex vIn [[ stage_in ]]) {
    VertexOut vOut;
    vOut.pos = (float2(vIn.position.x, vIn.position.y)+1.0)/2.0;
    vOut.position = float4(vIn.position, 1);
    vOut.color = vIn.color.xy;
    return vOut;
}

fragment float4 brdfFitFragmentShader (VertexOut vOut [[ stage_in ]]) {
    return float4(1);
}

