using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public abstract class BaseShape : MonoBehaviour
{
    public abstract ShapeType ShapeType { get; }

    public OperationType operationType;

    [Range(0, 1)]
    public float blendStrength;

    [SerializeField, ColorUsage(false)]
    private Color color;

    public Vector3 Scale
    {
        get
        {
            Vector3 scale = Vector3.one;
            if (transform.parent)
            {
                BaseShape shape = transform.parent.GetComponent<BaseShape>();
                if (shape) scale = shape.Scale;
            }
            return Vector3.Scale(scale, transform.localScale);
        }
    }

    public Vector3 Color
    {
        get
        {
            return new Vector3(color.r, color.g, color.b);
        }
    }

    public virtual Vector4 CreateExtraData()
    {
        return Vector4.zero;
    }
}

public enum ShapeType
{
    Sphere,
    Cube,
    Plane,
    RoundBox,
    BoxFrame,
    Torus,
    Capsule,
    Mandelbulb
}

public enum OperationType
{
    Union,
    Subtraction,
    Intersection,
    SmoothUnion,
    SmoothSubtraction
}
