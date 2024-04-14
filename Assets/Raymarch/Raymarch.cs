using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class Raymarch
{
    private static Shader _shader;

    public static Shader Shader
    {
        get => _shader;
        set
        {
            _shader = value;

            if (!_shader)
            {
#if UNITY_EDITOR
                if (Application.isPlaying)
                {
                    Object.Destroy(Material);
                }
                else
                {
                    Object.DestroyImmediate(Material);
                }
#else
                Object.Destroy(Material);
#endif

                Material = null;
            }
            else
            {
                Material = new Material(_shader)
                {
                    hideFlags = HideFlags.HideAndDontSave
                };
            }
        }
    }

    public static Material Material { get; private set; }

    public static void ResetData()
    {
        Shader = null;
    }

    public static bool ShouldRender()
    {
        return Material != null;
    }
}