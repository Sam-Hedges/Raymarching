using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SphereShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.Sphere;

    [SerializeField]
    private float radius;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(radius, 0);
    }
}
