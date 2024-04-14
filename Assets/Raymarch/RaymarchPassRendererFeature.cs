using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class RaymarchPassRendererFeature : ScriptableRendererFeature
{
    [Header("Render Feature Settings")]
    [SerializeField, Tooltip("Controls at what point in the pipeline the render pass executes.")] 
    private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;

    [Space]
    [Header("Render Feature Settings")]
    [Space]
    [SerializeField, Tooltip("The compute shader used for raymarching.")] 
    private RaymarchSettings raymarchSettings;

    private RaymarchRenderPass _raymarchPass;

    /// <inheritdoc/>
    public override void Create()
    {
        _raymarchPass = new RaymarchRenderPass(renderPassEvent, raymarchSettings);
        _raymarchPass.SetCurrentSceneObjects(new List<BaseShape>(FindObjectsOfType<BaseShape>()));
    }

    /// <inheritdoc/>
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Set the render pass list of shapes to all current shapes in the scene
        _raymarchPass.SetCurrentSceneObjects(new List<BaseShape>(FindObjectsOfType<BaseShape>()));
        
        renderer?.EnqueuePass(_raymarchPass);
    }

    /// <inheritdoc/>
    protected override void Dispose(bool disposing)
    {
        _raymarchPass?.Dispose();
    }

}
