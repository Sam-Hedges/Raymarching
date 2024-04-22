float4 ScaleObject(float3 p, float3 scale)
{
    float3 newScale = p / scale;
    
    float minAxis = min(min(scale.x, scale.y), scale.z);
    
    return float4(newScale, minAxis);
}

float2x2 Rotate(float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    return float2x2(c, -s, s, c);
}

float3 RotateObject(float3 p, float3 rotation)
{
    p.yz = mul(Rotate(radians(rotation.x)), p.yz);
    p.xz = mul(Rotate(radians(rotation.y)), p.xz);
    p.xy = mul(Rotate(radians(rotation.z)), p.xy);

    return p;
}

float SDFSphere(float3 eye, float3 p, float radius, float3 rotation, float3 scale)
{
    float3 origin = eye - p;
    
    origin = RotateObject(origin, rotation);
    
    float4 scaled = ScaleObject(origin, scale);
    origin = scaled.xyz;
    
    return (length(origin) - radius) * scaled.w;

}

float SDFCube(float3 eye, float3 p, float3 scale, float3 rotation)
{
    float3 origin = eye - p;
    
    origin = RotateObject(origin, rotation);
    
    float3 o = abs(origin) - scale;
    float ud = length(max(o, 0));
    float n = max(max(min(o.x, 0), min(o.y, 0)), min(o.z, 0));
    
    return ud+n;
}

float SDFPlane(float3 eye, float3 axis, float height)
{
    return dot(eye, normalize(axis)) + height;
}

float SDFRoundBox(float3 eye, float3 p, float3 scale, float r, float3 rotation)
{
    float3 origin = eye - p;
    
    origin = RotateObject(origin, rotation);
    
    float3 q = abs(origin) - scale;
    return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0) - r;
}

float SDFBoxFrame(float3 eye, float3 p, float3 scale, float e, float3 rotation)
{
    float3 origin = eye - p;
    origin = RotateObject(origin, rotation);
    
    origin = abs(origin) - scale;
    float3 q = abs(origin + (e * scale * 0.5)) - (e * scale * 0.5);
    return min(min(
      length(max(float3(origin.x, q.y, q.z), 0.0)) + min(max(origin.x, max(q.y, q.z)), 0.0),
      length(max(float3(q.x, origin.y, q.z), 0.0)) + min(max(q.x, max(origin.y, q.z)), 0.0)),
      length(max(float3(q.x, q.y, origin.z), 0.0)) + min(max(q.x, max(q.y, origin.z)), 0.0));
}

float SDFTorus(float3 eye, float3 p, float2 t, float3 rotation, float3 scale)
{
    float3 origin = eye - p;
    origin = RotateObject(origin, rotation);
    
    float4 scaled = ScaleObject(origin, scale);
    origin = scaled.xyz;
    
    float2 q = float2(length(origin.xz) - t.x, origin.y);
    return (length(q) - t.y) * scaled.w;
}

float SDFCapsule(float3 eye, float3 p, float h, float r, float3 scale, float3 rotation)
{
    float3 origin = eye - p;
    origin = RotateObject(origin, rotation);
    
    float4 scaled = ScaleObject(origin, scale);
    origin = scaled.xyz;
    
    origin.y -= clamp(origin.y, -h/2, h/2);
    return length(origin) - r;
}

// https://iquilezles.org/articles/mandelbulb
float SDFMandelbulb(float3 eye, float3 position, float3 rotation, float3 scale, out float4 resColor)
{
    float3 transformedPosition = (eye - position);
    transformedPosition = RotateObject(transformedPosition, rotation);
    float4 scaled = ScaleObject(transformedPosition, scale);
    transformedPosition = scaled.xyz;

    float3 w = transformedPosition;
    float m = dot(w,w);

    float4 trap = float4(abs(w),m);
    float dz = 1.0;
    
    for(int i = 0; i < 4; i++)
    {
        // trigonometric version (MUCH faster than polynomial)
        // dz = 8*z^7*dz
        dz = 8.0*pow(m,3.5)*dz + 1.0;
      
        // z = z^8+c
        float r = length(w);
        float b = 8.0 * acos(w.y / r);
        float a = 8.0 * atan2(w.x, w.z);
        w = eye + pow(r,8.0) * float3(sin(b) * sin(a), cos(b), sin(b) * cos(a));
        
        trap = min(trap, float4(abs(w), m));

        m = dot(w, w);
        if(m > 256.0)
            break;
    }

    resColor = float4(m,trap.yzw);

    // distance estimation (through the Hubbard-Douady potential)
    return 0.25 * log(m) * sqrt(m) / dz;
}