using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class RaymarchRenderPass : ScriptableRenderPass
{
    private const string ProfilerTag = "Raymarch Pass";
    private RaymarchSettings _settings;
    private readonly ComputeShader _raymarchComputeShader;
    private int KernelIndex => _raymarchComputeShader.FindKernel("CSMain"); 
    private List<ComputeBuffer> _computeBuffers;
    private CameraData _cameraData;


    public RaymarchRenderPass(RenderPassEvent renderPassEvent, RaymarchSettings settings)
    {
        this.renderPassEvent = renderPassEvent;
        _settings = settings;
        _raymarchComputeShader = (ComputeShader)Resources.Load("Compute/Raymarching");
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        _settings.light = RenderSettings.sun;
        _cameraData = renderingData.cameraData;
    }

    public void SetCurrentSceneObjects(List<BaseShape> shapes)
    {
        if (_settings == null) return;
        _settings.shapes = shapes;
    }

    public void Dispose()
    {
        // Moving buffer disposal fixed buffers being destroyed before they'd been used
        foreach (var buffer in _computeBuffers)
        {
            buffer?.Dispose();
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // Return if not a scene view cam or game cam
        _cameraData = renderingData.cameraData;
        if (_cameraData.cameraType != CameraType.SceneView && _cameraData.cameraType != CameraType.Game) return;

        if (_settings.shapes.Count <= 0) return;
        
        RTHandle colorTarget = _cameraData.renderer.cameraColorTargetHandle;
        RTHandle depthTarget = _cameraData.renderer.cameraDepthTargetHandle;
        CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);

        // Get temporary copy of the scene texture
        RenderTexture tempColorTarget = RenderTexture.GetTemporary(_cameraData.cameraTargetDescriptor);
        tempColorTarget.format = RenderTextureFormat.ARGBFloat; // Colour formatting was wrong without this
        tempColorTarget.enableRandomWrite = true;
        tempColorTarget.antiAliasing = 1;
        tempColorTarget.depth = 0;
        cmd.Blit(colorTarget, tempColorTarget);

        // Setup compute params
        SetupComputeParams(cmd);
        cmd.SetComputeTextureParam(_raymarchComputeShader, KernelIndex, "_CameraDepthTexture", depthTarget.rt);
        cmd.SetComputeTextureParam(_raymarchComputeShader, KernelIndex, "Source", colorTarget.rt);
        cmd.SetComputeTextureParam(_raymarchComputeShader, KernelIndex, "Destination", tempColorTarget);

        // Dispatch according to thread count in shader
        _raymarchComputeShader.GetKernelThreadGroupSizes(KernelIndex, out uint groupSizeX, out uint groupSizeY, out _);
        int threadGroupsX = Mathf.CeilToInt(tempColorTarget.width / (float)groupSizeX);
        int threadGroupsY = Mathf.CeilToInt(tempColorTarget.height / (float)groupSizeY);
        cmd.DispatchCompute(_raymarchComputeShader, KernelIndex, threadGroupsX, threadGroupsY, 1);

        // Sync compute with frame
        AsyncGPUReadback.Request(tempColorTarget).WaitForCompletion();

        // Copy temporary texture into colour buffer
        cmd.Blit(tempColorTarget, colorTarget);
        context.ExecuteCommandBuffer(cmd);

        // Clean up
        cmd.Clear();
        RenderTexture.ReleaseTemporary(tempColorTarget);
        CommandBufferPool.Release(cmd);

    }
    
    private void SetupComputeParams(CommandBuffer cmd)
    {
        _computeBuffers = new List<ComputeBuffer>();

        LoadShapes(cmd);
        
        cmd.SetComputeMatrixParam(_raymarchComputeShader, "cameraToWorld", _cameraData.camera.cameraToWorldMatrix);
        cmd.SetComputeMatrixParam(_raymarchComputeShader, "cameraInverseProjection", _cameraData.camera.projectionMatrix.inverse);

        cmd.SetComputeFloatParam(_raymarchComputeShader, "maxDistance", _settings.maxDistance);
        cmd.SetComputeIntParam(_raymarchComputeShader, "maxIterations", _settings.maxIterations);

        cmd.SetComputeFloatParam(_raymarchComputeShader, "shadowIntensity", _settings.shadowIntensity);
        cmd.SetComputeFloatParam(_raymarchComputeShader, "shadowPenumbra", _settings.shadowPenumbra);
        cmd.SetComputeIntParam(_raymarchComputeShader, "softShadows", _settings.useSoftShadows ? 1 : 0);
        cmd.SetComputeVectorParam(_raymarchComputeShader, "shadowDistance", _settings.shadowDistance);

        cmd.SetComputeFloatParam(_raymarchComputeShader, "aoStepSize", _settings.aoStepSize);
        cmd.SetComputeFloatParam(_raymarchComputeShader, "aoIntensity", _settings.aoIntensity);
        cmd.SetComputeIntParam(_raymarchComputeShader, "aoIterations", _settings.aoIterations);
        cmd.SetComputeIntParam(_raymarchComputeShader, "aoEnabled", _settings.aoEnabled ? 1 : 0);
        
        LoadLight(cmd);
    }
    private void LoadShapes(CommandBuffer cmd) {
        // get all shapes in the scene
        List<BaseShape> tempShapesList = _settings.shapes;

        // pass the number of shapes in the scene to the shader
        cmd.SetComputeIntParam(_raymarchComputeShader, "shapesCount", tempShapesList.Count);

        // sort the shapes by operation type
        tempShapesList.Sort((a, b) => a.operationType.CompareTo(b.operationType));

        // create a buffer to store the shape data
        ShapeData[] shapeData = new ShapeData[tempShapesList.Count];

        // iterate through the shapes and add their data to the buffer
        for (int i = 0; i < tempShapesList.Count; i++) {
            var shape = tempShapesList[i];
            var transform = shape.transform;
            
            shapeData[i] = new ShapeData {
                position = transform.position,
                scale = shape.Scale,
                rotation = transform.eulerAngles,
                blendStrength = shape.blendStrength,
                color = shape.Color,
                data = shape.CreateExtraData(),
                operationType = (int)shape.operationType,
                shapeType = (int)shape.ShapeType
            };
        }

        // create a compute buffer to store the shape data
        ComputeBuffer buffer = new ComputeBuffer(shapeData.Length, ShapeData.GetStride());
        buffer.SetData(shapeData);

        // pass the buffer to the shader
        cmd.SetComputeBufferParam(_raymarchComputeShader, KernelIndex, "shapes", buffer);

        // add the buffer to the list of buffers to dispose of after rendering
        _computeBuffers.Add(buffer);
    }

    /// <summary>
    /// Set the light parameters for the raymarching shader to the values of the sun light in the scene
    /// </summary>
    private void LoadLight(CommandBuffer cmd) {
        Vector3 direction = Vector3.down;
        Color color = Color.white;
        float intensity = 1;

        if (_settings.light) {
            direction = _settings.light.transform.forward;
            color = _settings.light.color;
            intensity = _settings.light.intensity;
        }

        cmd.SetComputeVectorParam(_raymarchComputeShader, "lightDirection", direction);
        cmd.SetComputeVectorParam(_raymarchComputeShader, "lightColor", new Vector3(color.r, color.g, color.b));
        cmd.SetComputeFloatParam(_raymarchComputeShader, "lightIntensity", intensity);
    }

    /// <summary>
    /// Contains data for a shape
    /// </summary>
    private struct ShapeData {
        public Vector3 position;
        public Vector3 scale;
        public Vector3 rotation;
        public Vector3 color;
        public Vector4 data;
        public int shapeType;
        public int operationType;
        public float blendStrength;

        /// <summary>
        /// Return the size of the struct in bytes
        /// </summary>
        /// <returns>
        /// Stride is the size of one element in the buffer, in bytes. Must be a multiple of 4 and less than 2048,
        /// and match the size of the buffer type in the shader. 
        /// </returns>
        public static int GetStride() {
            return sizeof(float) * 17 + sizeof(int) * 2;
        }
    }
}