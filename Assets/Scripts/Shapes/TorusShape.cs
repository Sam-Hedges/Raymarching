using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TorusShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.Torus;

    [SerializeField]
    private float radius;

    [SerializeField]
    private float width;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(radius, width, 0);
    }
}
