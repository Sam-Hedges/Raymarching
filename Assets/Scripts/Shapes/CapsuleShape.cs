using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CapsuleShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.Capsule;

    [SerializeField]
    private float height = 1;

    [SerializeField]
    private float radius = 0.5f;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(height, radius, 0, 0);
    }
}
