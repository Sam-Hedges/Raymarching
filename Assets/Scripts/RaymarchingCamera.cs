using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
[RequireComponent(typeof(Camera))]
public class RaymarchingCamera : MonoBehaviour
{
    [SerializeField]
    private ComputeShader raymarchingShader;

    [SerializeField]
    private Light sunLight;

    [SerializeField]
    private float maxDistance = 500;

    [SerializeField]
    private int maxIterations = 512;

    [Header("Shadows")]

    [SerializeField]
    private bool useSoftShadows = true;

    [SerializeField]
    [Range(1, 128)]
    private float shadowPenumbra;

    [SerializeField]
    [Range(0, 4)]
    private float shadowIntensity;

    [SerializeField]
    private Vector2 shadowDistance = new Vector2(0.1f, 20);

    [Header("Ambient Occlusion")]

    [SerializeField]
    private bool aoEnabled = true;

    [SerializeField]
    [Range(0.01f, 10f)]
    private float aoStepSize;

    [SerializeField]
    [Range(1, 5)]
    private int aoIterations;

    [SerializeField]
    [Range(0,1)]
    private float aoIntensity;

    private Camera m_cam;
    public Camera Camera
    {
        get
        {
            if (!m_cam)
                m_cam = GetComponent<Camera>();
            return m_cam;
        }
    }

    private RenderTexture target;

    private List<ComputeBuffer> buffers;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!raymarchingShader)
        {
            Graphics.Blit(source, destination);
            return;
        }

        buffers = new List<ComputeBuffer>();

        CreateTexture();
        LoadShapes();
        SetParameters();
        LoadLight();

        raymarchingShader.SetTexture(0, "_CameraDepthTexture", Shader.GetGlobalTexture("_CameraDepthTexture"));
        raymarchingShader.SetTexture(0, "Source", source);
        raymarchingShader.SetTexture(0, "Destination", target);

        int numThreadsX = Mathf.CeilToInt(Camera.pixelWidth / 8f);
        int numThreadsY = Mathf.CeilToInt(Camera.pixelHeight / 8f);

        raymarchingShader.Dispatch(0, numThreadsX, numThreadsY, 1);

        Graphics.Blit(target, destination);

        foreach (var buffer in buffers)
        {
            buffer.Dispose();
        }
    }

    private void CreateTexture()
    {
        if (target == null || target.width != Camera.pixelWidth || target.height != Camera.pixelHeight)
        {
            if (target)
                target.Release();
            target = new RenderTexture(Camera.pixelWidth, Camera.pixelHeight, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            target.enableRandomWrite = true;
            target.Create();
        }
    }

    private void SetParameters()
    {
        raymarchingShader.SetMatrix("cameraToWorld", Camera.cameraToWorldMatrix);
        raymarchingShader.SetMatrix("cameraInverseProjection", Camera.projectionMatrix.inverse);

        raymarchingShader.SetFloat("maxDistance", maxDistance);
        raymarchingShader.SetInt("maxIterations", maxIterations);

        raymarchingShader.SetFloat("shadowIntensity", shadowIntensity);
        raymarchingShader.SetFloat("shadowPenumbra", shadowPenumbra);
        raymarchingShader.SetBool("softShadows", useSoftShadows);
        raymarchingShader.SetVector("shadowDistance", shadowDistance);

        raymarchingShader.SetFloat("aoStepSize", aoStepSize);
        raymarchingShader.SetFloat("aoIntensity", aoIntensity);
        raymarchingShader.SetInt("aoIterations", aoIterations);
        raymarchingShader.SetBool("aoEnabled", aoEnabled);
    }

    private void LoadShapes()
    {
        List<BaseShape> shapes = new List<BaseShape>(FindObjectsOfType<BaseShape>());

        raymarchingShader.SetInt("shapesCount", shapes.Count);

        if (shapes.Count == 0) return;

        shapes.Sort((a, b) => a.operationType.CompareTo(b.operationType));

        ShapeData[] shapeData = new ShapeData[shapes.Count];
        for (int i = 0; i < shapes.Count; i++)
        {
            var shape = shapes[i];
            shapeData[i] = new ShapeData()
            {
                position = shape.transform.position,
                scale = shape.Scale,
                rotation = shape.transform.eulerAngles,
                blendStrength = shape.blendStrength,
                color = shape.Color,
                data = shape.CreateExtraData(),
                operationType = (int)shape.operationType,
                shapeType = (int)shape.ShapeType
            };
        }

        ComputeBuffer buffer = new ComputeBuffer(shapes.Count, ShapeData.GetStride());
        buffer.SetData(shapeData);
        raymarchingShader.SetBuffer(0, "shapes", buffer);

        buffers.Add(buffer);
    }

    private void LoadLight()
    {
        Vector3 direction = Vector3.down;
        Color color = Color.white;
        float intensity = 1;

        if (sunLight)
        {
            direction = sunLight.transform.forward;
            color = sunLight.color;
            intensity = sunLight.intensity;
        }

        raymarchingShader.SetVector("lightDirection", direction);
        raymarchingShader.SetVector("lightColor", new Vector3(color.r, color.g, color.b));
        raymarchingShader.SetFloat("lightIntensity", intensity);
    }

    private struct ShapeData
    {
        public Vector3 position;
        public Vector3 scale;
        public Vector3 rotation;
        public Vector3 color;
        public Vector4 data;
        public int shapeType;
        public int operationType;
        public float blendStrength;

        public static int GetStride()
        {
            return sizeof(float) * 17 + sizeof(int) * 2;
        }
    }
}
