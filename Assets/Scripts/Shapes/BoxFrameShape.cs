using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BoxFrameShape : BaseShape
{
    public override ShapeType ShapeType => ShapeType.BoxFrame;

    [SerializeField]
    [Range(0,1)]
    private float e;

    public override Vector4 CreateExtraData()
    {
        return new Vector4(e, 0);
    }
}
