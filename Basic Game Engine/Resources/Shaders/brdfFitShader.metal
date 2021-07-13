//
//  brdfFitShader.metal
//  Basic Game Engine
//
//  Created by Ravi Khannawalia on 07/03/21.
//

/*
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

// bind roughness   {label:"Roughness", default:0.25, min:0.01, max:1, step:0.001}
// bind dcolor      {label:"Diffuse Color",  r:1.0, g:1.0, b:1.0}
// bind scolor      {label:"Specular Color", r:1.0, g:1.0, b:1.0}
// bind intensity   {label:"Light Intensity", default:4, min:0, max:10}
// bind width       {label:"Width",  default: 8, min:0.1, max:15, step:0.1}
// bind height      {label:"Height", default: 8, min:0.1, max:15, step:0.1}
// bind roty        {label:"Rotation Y", default: 0, min:0, max:1, step:0.001}
// bind rotz        {label:"Rotation Z", default: 0, min:0, max:1, step:0.001}
// bind twoSided    {label:"Two-sided", default:false}

 float roughness;
 float3  dcolor;
 float3  scolor;

 float intensity;
 float width;
 float height;
 float roty;
 float rotz;

 bool twoSided;

 sampler ltc_mat;
 sampler ltc_mag;

 mat4  view;
 float2  resolution;
 int   sampleCount;

const float LUT_SIZE  = 64.0;
const float LUT_SCALE = (LUT_SIZE - 1.0)/LUT_SIZE;
const float LUT_BIAS  = 0.5/LUT_SIZE;

const float pi = 3.14159265;

// Tracing and intersection
///////////////////////////

struct Ray
{
    float3 origin;
    float3 dir;
};

struct Rect
{
    float3  center;
    float3  dirx;
    float3  diry;
    float halfx;
    float halfy;

    float4  plane;
};

bool RayPlaneIntersect(Ray ray, float4 plane, out float t)
{
    t = -dot(plane, float4(ray.origin, 1.0))/dot(plane.xyz, ray.dir);
    return t > 0.0;
}

bool RayRectIntersect(Ray ray, Rect rect, out float t)
{
    bool intersect = RayPlaneIntersect(ray, rect.plane, t);
    if (intersect)
    {
        float3 pos  = ray.origin + ray.dir*t;
        float3 lpos = pos - rect.center;
        
        float x = dot(lpos, rect.dirx);
        float y = dot(lpos, rect.diry);

        if (abs(x) > rect.halfx || abs(y) > rect.halfy)
            intersect = false;
    }

    return intersect;
}

// Camera functions
///////////////////

Ray GenerateCameraRay(float u1, float u2)
{
    Ray ray;

    // Random jitter within pixel for AA
    float2 xy = 2.0*(gl_FragCoord.xy)/resolution - float2(1.0);

    ray.dir = normalize(float3(xy, 2.0));

    float focalDistance = 2.0;
    float ft = focalDistance/ray.dir.z;
    float3 pFocus = ray.dir*ft;

    ray.origin = float3(0);
    ray.dir    = normalize(pFocus - ray.origin);

    // Apply camera transform
    ray.origin = (view*float4(ray.origin, 1)).xyz;
    ray.dir    = (view*float4(ray.dir,    0)).xyz;

    return ray;
}

float3 mul(mat3 m, float3 v)
{
    return m * v;
}

mat3 mul(mat3 m1, mat3 m2)
{
    return m1 * m2;
}

float3 rotation_y(float3 v, float a)
{
    float3 r;
    r.x =  v.x*cos(a) + v.z*sin(a);
    r.y =  v.y;
    r.z = -v.x*sin(a) + v.z*cos(a);
    return r;
}

float3 rotation_z(float3 v, float a)
{
    float3 r;
    r.x =  v.x*cos(a) - v.y*sin(a);
    r.y =  v.x*sin(a) + v.y*cos(a);
    r.z =  v.z;
    return r;
}

float3 rotation_yz(float3 v, float ay, float az)
{
    return rotation_z(rotation_y(v, ay), az);
}

mat3 transpose(mat3 v)
{
    mat3 tmp;
    tmp[0] = float3(v[0].x, v[1].x, v[2].x);
    tmp[1] = float3(v[0].y, v[1].y, v[2].y);
    tmp[2] = float3(v[0].z, v[1].z, v[2].z);

    return tmp;
}

// Linearly Transformed Cosines
///////////////////////////////

float IntegrateEdge(float3 v1, float3 v2)
{
    float cosTheta = dot(v1, v2);
    float theta = acos(cosTheta);
    float res = cross(v1, v2).z * ((theta > 0.001) ? theta/sin(theta) : 1.0);

    return res;
}

void ClipQuadToHorizon(inout float3 L[5], out int n)
{
    // detect clipping config
    int config = 0;
    if (L[0].z > 0.0) config += 1;
    if (L[1].z > 0.0) config += 2;
    if (L[2].z > 0.0) config += 4;
    if (L[3].z > 0.0) config += 8;

    // clip
    n = 0;

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
}


float3 LTC_Evaluate(
    float3 N, float3 V, float3 P, mat3 Minv, float3 points[4], bool twoSided)
{
    // construct orthonormal basis around N
    float3 T1, T2;
    T1 = normalize(V - N*dot(V, N));
    T2 = cross(N, T1);

    // rotate area light in (T1, T2, N) basis
    Minv = mul(Minv, transpose(mat3(T1, T2, N)));

    // polygon (allocate 5 vertices for clipping)
    float3 L[5];
    L[0] = mul(Minv, points[0] - P);
    L[1] = mul(Minv, points[1] - P);
    L[2] = mul(Minv, points[2] - P);
    L[3] = mul(Minv, points[3] - P);

    int n;
    ClipQuadToHorizon(L, n);
    
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

// Scene helpers
////////////////

void InitRect(out Rect rect)
{
    rect.dirx = rotation_yz(float3(1, 0, 0), roty*2.0*pi, rotz*2.0*pi);
    rect.diry = rotation_yz(float3(0, 1, 0), roty*2.0*pi, rotz*2.0*pi);

    rect.center = float3(0, 6, 32);
    rect.halfx  = 0.5*width;
    rect.halfy  = 0.5*height;

    float3 rectNormal = cross(rect.dirx, rect.diry);
    rect.plane = float4(rectNormal, -dot(rectNormal, rect.center));
}

void InitRectPoints(Rect rect, out float3 points[4])
{
    float3 ex = rect.halfx*rect.dirx;
    float3 ey = rect.halfy*rect.diry;

    points[0] = rect.center - ex - ey;
    points[1] = rect.center + ex - ey;
    points[2] = rect.center + ex + ey;
    points[3] = rect.center - ex + ey;
}

// Misc. helpers
////////////////

float saturate(float v)
{
    return clamp(v, 0.0, 1.0);
}

float3 Powfloat3(float3 v, float p)
{
    return float3(pow(v.x, p), pow(v.y, p), pow(v.z, p));
}

const float gamma = 2.2;

float3 ToLinear(float3 v) { return Powfloat3(v,     gamma); }
float3 ToSRGB(float3 v)   { return Powfloat3(v, 1.0/gamma); }

void main()
{
    Rect rect;
    InitRect(rect);

    float3 points[4];
    InitRectPoints(rect, points);

    float4 floorPlane = float4(0, 1, 0, 0);

    float3 lcol = float3(intensity);
    float3 dcol = ToLinear(dcolor);
    float3 scol = ToLinear(scolor);
    
    float3 col = float3(0);

    Ray ray = GenerateCameraRay(0.0, 0.0);

    float distToFloor;
    bool hitFloor = RayPlaneIntersect(ray, floorPlane, distToFloor);
    if (hitFloor)
    {
        float3 pos = ray.origin + ray.dir*distToFloor;

        float3 N = floorPlane.xyz;
        float3 V = -ray.dir;
        
        float theta = acos(dot(N, V));
        float2 uv = float2(roughness, theta/(0.5*pi));
        uv = uv*LUT_SCALE + LUT_BIAS;
        
        float4 t = texture2D(ltc_mat, uv);
        mat3 Minv = mat3(
            float3(  1,   0, t.y),
            float3(  0, t.z,   0),
            float3(t.w,   0, t.x)
        );
        
        float3 spec = LTC_Evaluate(N, V, pos, Minv, points, twoSided);
        spec *= texture2D(ltc_mag, uv).w;
        
        float3 diff = LTC_Evaluate(N, V, pos, mat3(1), points, twoSided);
        
        col  = lcol*(scol*spec + dcol*diff);
        col /= 2.0*pi;
    }

    float distToRect;
    if (RayRectIntersect(ray, rect, distToRect))
        if ((distToRect < distToFloor) || !hitFloor)
            col = lcol;

    gl_FragColor = float4(col, 1.0);
}
*/
