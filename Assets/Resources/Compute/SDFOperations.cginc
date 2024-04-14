float Mix(float valueA, float valueB, float t)
{
    return valueA * (1 - t) + valueB * t;
}

float3 Mix(float3 valueA, float3 valueB, float t)
{
    return valueA * (1 - t) + valueB * t;

}

float4 OperationUnion(float distanceA, float distanceB, float3 colorA, float3 colorB)
{
    float result = min(distanceA, distanceB);
    float3 resultColor = colorA;
    
    if (result == distanceB)
        resultColor = colorB;
    
    return float4(resultColor, result);
}

float4 OperationSubtraction(float distanceA, float distanceB, float3 colorA, float3 colorB)
{
    float result = max(distanceA, -distanceB);
    float3 resultColor = colorA;
    
    if (result == -distanceB)
    {
        resultColor = colorB;
    }
    
    return float4(resultColor, result);
}

float4 OperationIntersection(float distanceA, float distanceB, float3 colorA, float3 colorB)
{
    float result = max(distanceA, distanceB);
    float3 resultColor = colorA;
    
    if (result == distanceB)
    {
        resultColor = colorB;
    }
    
    return float4(resultColor, result);
}

float4 OperationSmoothUnion(float distanceA, float distanceB, float3 colorA, float3 colorB, float k)
{
    float h = clamp(0.5 + 0.5 * (distanceB - distanceA) / k, 0.0, 1.0);
    return float4(Mix(colorB, colorA, h) - k * h * (1 - h), Mix(distanceB, distanceA, h) - k * h * (1 - h));
}

float4 OperationSmoothSubtraction(float distanceA, float distanceB, float3 colorA, float3 colorB, float k)
{
    float h = clamp(0.5 - 0.5 * (distanceB + distanceA) / k, 0.0, 1.0);
    return float4(Mix(colorB, colorA, h) + k * h * (1 - h), Mix(distanceB, -distanceA, h) + k * h * (1 - h));
}