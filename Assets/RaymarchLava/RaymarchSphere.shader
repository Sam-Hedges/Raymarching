Shader "Unlit/RaymarchSphere"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { 
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color", Color) = (1,1,1,1)
        _SpherePosition("Sphere Position", Vector) = (0, 0, 0, 0)
        _SphereSize("Sphere Size", Float) = 1
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM

            #pragma vertex Vertex
            #pragma fragment Fragment

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            

			#define MAX_STEPS 100
            #define MAX_DISTANCE 100.0
            #define SURFACE_DISTANCE 1e-3
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float4 _SpherePosition;
            float _SphereSize;
            
            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
            	float3 positionOS : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
            };

            struct Ray {
				float3 origin;
				float3 direction;
			};

            struct rOut {								
				float3 hitPosition;	// the point of contact with the surface
			};

            Ray GenerateRay(const float3 cameraPos, const float3 objectPosition) {
				Ray ray;
				ray.origin = mul(unity_WorldToObject, float4(cameraPos ,1)).xyz;
				ray.direction = normalize(objectPosition - ray.origin);
				return ray;
			}
            
            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings Vertex (Attributes input)
            {   
                Varyings output;
                output.positionCS = mul(UNITY_MATRIX_VP, mul(unity_ObjectToWorld, float4(input.positionOS.xyz, 1.0)));
                output.positionWS = mul(unity_ObjectToWorld, input.positionOS).xyz;
            	output.positionOS = input.positionOS.xyz;
                output.screenPos   = ComputeScreenPos(output.positionCS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            float SignedDistanceSphere(float3 position, float3 center, float radius)
            {
                return length(center - position) - radius;
            }
            
            float GetDistance(float3 position)
            {
                const float sphere = SignedDistanceSphere(position, _SpherePosition.xyz, _SphereSize);
                return sphere;  
            }

			float3 GetNormal(float3 p) {
				float2 e = float2(1e-2, 0);

				const float3 normal = GetDistance(p) - float3(
					GetDistance(p-e.xyy),
					GetDistance(p-e.yxy),
					GetDistance(p-e.yyx)
				);

				return normalize(normal);
			}
            
            bool MarchRay(const Ray InRay, out rOut outS)
			{													
            	float distance = 0.0;

                for (int i = 0; i < MAX_STEPS; i++) {
	                const float3 position = InRay.origin + InRay.direction * distance;
	                const float sceneDistance = GetDistance(position);
        			distance += sceneDistance;
        			outS.hitPosition = position;
        			if (sceneDistance < SURFACE_DISTANCE) return true; // surface hit
        			if (distance > MAX_DISTANCE) break; // exit if marched too far
				}
                
                return false;
			}
            
            // The fragment shader definition.            
            float4 Fragment (Varyings input) : SV_Target
            {
	            Ray ray = GenerateRay(_WorldSpaceCameraPos, input.positionOS);
                rOut outS;

				float4 colour = 0;
            	
            	if(MarchRay(ray, outS))
            	{
                    colour.rgb = GetNormal(outS.hitPosition);
            		return colour;
            	}

            	discard;
            	return colour;
            }
            
            ENDHLSL
        }
    }
}