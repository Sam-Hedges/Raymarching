using UnityEngine;
using System.Collections.Generic;

[System.Serializable]
public class RaymarchSettings
{
    [Header("General")] 
    public List<BaseShape> shapes;
    public Light light;
    public float maxDistance = 500;
    public int maxIterations = 512;

    [Header("Shadows")] 
    public bool useSoftShadows = true;
    [Range(1, 128)] public float shadowPenumbra;
    [Range(0, 4)] public float shadowIntensity;
    public Vector2 shadowDistance = new Vector2(0.1f, 20);

    [Header("Ambient Occlusion")] 
    public bool aoEnabled = true;
    [Range(0.01f, 10f)] public float aoStepSize;
    [Range(1, 5)] public int aoIterations;
    [Range(0, 1)] public float aoIntensity;
 
}
