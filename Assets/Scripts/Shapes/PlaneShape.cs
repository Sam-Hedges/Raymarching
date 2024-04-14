using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlaneShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.Plane;

    [SerializeField]
    private Vector3 axis = Vector3.up;

    [SerializeField]
    private float height;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(axis.x, axis.y, axis.z, -height);
    }
}
