using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RoundBoxShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.RoundBox;

    [SerializeField]
    private float radius;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(radius, 0);
    }
}
