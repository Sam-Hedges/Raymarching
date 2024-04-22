using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraRotate : MonoBehaviour
{
    void FixedUpdate()
    {
        transform.Rotate(Vector3.up, 0.5f);
    }
}
