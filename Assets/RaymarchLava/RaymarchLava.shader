Shader "Unlit/RaymarchLava"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { 
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color", Color) = (1,1,1,1)
    	_Smoothness("Smoothness", Float) = 1
        _SphereSize("Sphere Size", Float) = 1
        _PositionOffset("Position", vector) = (0, 0, 0, 0)
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }
		
        // The blend mode determines how the color from this object blends with what's already rendered to the buffer
        Blend SrcAlpha OneMinusSrcAlpha 
        
        Pass
        {
        	Name "LitForward"
    		Tags { "LightMode"="UniversalForward" }
    		
	        HLSLPROGRAM
            
            #pragma vertex Vertex	
            #pragma fragment Fragment

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // My custom SDF functions
            #include "SignedDistanceFunctions.hlsl"

            // Constants for ray marching algorithm
			#define MAX_STEPS 100 // The maximum number of iterations or "steps" the ray marching algorithm will take when attempting to find a surface
            #define MAX_DISTANCE 100.0 // The maximum distance the ray will travel (or "march") from its origin
            #define SURFACE_DISTANCE 5e-5 // Defines the minimum distance to a surface at which the ray is considered to have "hit" the surface. 
            #define TIMESCALE 0.6
	        

	        // Shader properties
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float _Smoothness;
            float _SphereSize;
	        float4 _PositionOffset;
            
            // Define the structure of input vertex attributes
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv     : TEXCOORD0;
            };

	        // Define the structure of the vertex-to-fragment interpolants
            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
            	float3 positionOS : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
            };

	        // Define the ray structure for ray marching
            struct Ray {
				float3 origin;
				float3 direction;
			};

            struct rOut {								
				float3 hitPosition;	// the point of contact with the surface
			};

	        // Generate a ray given the camera and object positions
            Ray GenerateRay(const float3 cameraPos, const float3 objectPosition) {
				Ray ray;
				ray.origin = mul(unity_WorldToObject, float4(cameraPos ,1)).xyz;
				ray.direction = normalize(objectPosition - ray.origin);
				return ray;
			}
            
	        // Processes each vertex and outputs interpolated values for the fragment shader
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

	        // Calculate signed distance from a point to a sphere's surface
            float SignedDistanceSphere(float3 position, float3 center, float radius)
            {
                return length(center - position) - radius;
            }

	        // Get distance value from the point to the nearest surface in the "scene"
            float GetDistance(float3 position)
            {
				float time = _Time.y * TIMESCALE;
            	position -= _PositionOffset.xyz / 10;

				float3 spherePos1 = float3(sin(time * 0.337), abs(sin(time * 0.428)), sin(time * -0.989)) ;
            	float3 spherePos2 = float3(sin(time * -0.214), abs(sin(time * -0.725)), sin(time * 0.56));
            	float3 spherePos3 = float3(sin(time * -0.671), abs(sin(time * 0.272)), sin(time * 0.773));

            	float3 moveScale = float3(0.05, 1.5, 0.05);
            	
                float sphere1 = SignedDistanceSphere(position, spherePos1 * moveScale, _SphereSize / 10 * 0.5);
            	float sphere2 = SignedDistanceSphere(position, spherePos2 * moveScale, _SphereSize / 10 * 0.75);
            	float sphere3 = SignedDistanceSphere(position, spherePos3 * moveScale, _SphereSize / 10);
            	float sphere4 = SignedDistanceSphere(position, 0, 0.45);	

            	float spheres = SmoothCombine(sphere1, sphere2, _Smoothness);
            	spheres = SmoothCombine(spheres, sphere3, _Smoothness);
            	spheres = SmoothCombine(spheres, sphere4, _Smoothness);
            	
                return spheres;  
            }

	        // Calculate the surface normal at a point in the scene
			float3 GetNormal(float3 rayPosition) {
				float2 e = float2(SURFACE_DISTANCE, 0);
            	
				const float3 normal = GetDistance(rayPosition) - float3(
					GetDistance(rayPosition-e.xyy),
					GetDistance(rayPosition-e.yxy),
					GetDistance(rayPosition-e.yyx)
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
                    float3 normal = GetNormal(outS.hitPosition);
            		
            		float height = outS.hitPosition.y;
            		height = 1 - (height - 2) * 0.75;

            		const float rdDotN = dot(ray.direction, normal);
            		const float gradient = rdDotN * height;
					const float2 gradientUV = float2(clamp(-gradient, 0, 1.0), 0);
            		
            		//return float4(gradient, gradient, gradient, 1);
					return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, gradientUV) * _BaseColor;
            	}

				// Colour using the GetNormal function
				// colour.xyz = GetNormal(outS.hitPosition);
            	//discard;
            	return colour;
            }
            
            ENDHLSL
        }

		Pass 
		{
    		Name "ShadowCaster"
    		Tags { "LightMode"="ShadowCaster" }
 		
    		ZWrite On
    		ZTest LEqual
 		
    		HLSLPROGRAM
    		
    		// Required to compile gles 2.0 with standard srp library
    		#pragma prefer_hlslcc gles
    		#pragma exclude_renderers d3d11_9x gles
    		//#pragma target 4.5
 		
    		// Material Keywords
    		#pragma shader_feature _ALPHATEST_ON
    		#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
 		
    		// GPU Instancing
    		#pragma multi_compile_instancing
    		#pragma multi_compile _ DOTS_INSTANCING_ON
    		         
    		#pragma vertex ShadowPassVertex
    		#pragma fragment ShadowPassFragment
    		
			// The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

    		real LerpWhiteTo(real b, real t)
			{
			    real oneMinusT = 1.0 - t;
			    return oneMinusT + b * t;
			}
    		
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            // My custom SDF functions
            #include "SignedDistanceFunctions.hlsl"
    		
			// Constants for ray marching algorithm
			#define MAX_STEPS 100 // The maximum number of iterations or "steps" the ray marching algorithm will take when attempting to find a surface
            #define MAX_DISTANCE 100.0 // The maximum distance the ray will travel (or "march") from its origin
            #define SURFACE_DISTANCE 5e-5 // Defines the minimum distance to a surface at which the ray is considered to have "hit" the surface. 
            #define TIMESCALE 0.6

    		// Shader properties
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST;
            half4 _BaseColor;
            float _Smoothness;
            float _SphereSize;
	        float4 _PositionOffset;
    		half _Cutoff = 0.5;


			// Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
			// For Directional lights, _LightDirection is used when applying shadow Normal Bias.
			// For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
			float3 _LightDirection;
			float3 _LightPosition;

    		// Add these to your properties/definitions:
			float3 _LightPositionWS;
			float _LightRadius;
    		
			// Define the structure of input vertex attributes
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv     : TEXCOORD0;
            };

	        // Define the structure of the vertex-to-fragment interpolants
            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
            	float3 positionOS : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
            };

	        // Define the ray structure for ray marching
            struct Ray {
				float3 origin;
				float3 direction;
			};

            struct rOut {								
				float3 hitPosition;	// the point of contact with the surface
			};

	        // Generate a ray given the camera and object positions
            Ray GenerateRay(const float3 cameraPos, const float3 objectPosition) {
				Ray ray;
				ray.origin = mul(unity_WorldToObject, float4(cameraPos ,1)).xyz;
				ray.direction = normalize(objectPosition - ray.origin);
				return ray;
			}
			
			float4 GetShadowPositionHClip(Attributes input)
			{
			    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
			    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
			
			#if _CASTING_PUNCTUAL_LIGHT_SHADOW
			    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
			#else
			    float3 lightDirectionWS = _LightDirection;
			#endif
			
			    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
			
			#if UNITY_REVERSED_Z
			    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
			#else
			    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
			#endif
			
			    return positionCS;
			}
			
			Varyings ShadowPassVertex(Attributes input)
			{
			    Varyings output;
			    UNITY_SETUP_INSTANCE_ID(input);

            	output.positionCS = GetShadowPositionHClip(input);
                output.positionWS = mul(unity_ObjectToWorld, input.positionOS).xyz;
            	output.positionOS = input.positionOS.xyz;
                output.screenPos   = ComputeScreenPos(output.positionCS);
			    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
			    return output;
			}

			half Alpha(half albedoAlpha, half4 color, half cutoff)
			{
			#if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) && !defined(_GLOSSINESS_FROM_BASE_ALPHA)
			    half alpha = albedoAlpha * color.a;
			#else
			    half alpha = color.a;
			#endif
			
			#if defined(_ALPHATEST_ON)
			    clip(alpha - cutoff);
			#endif
			    return alpha;
			}
			
			half4 SampleAlbedoAlpha(float2 uv, TEXTURE2D_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
			{
			    return half4(SAMPLE_TEXTURE2D(albedoAlphaMap, sampler_albedoAlphaMap, uv));
			}

			// Calculate signed distance from a point to a sphere's surface
            float SignedDistanceSphere(float3 position, float3 center, float radius)
            {
                return length(center - position) - radius;
            }

	        // Get distance value from the point to the nearest surface in the "scene"
            float GetDistance(float3 position)
            {
				float time = _Time.y * TIMESCALE;
            	position -= _PositionOffset.xyz / 100;

				float3 spherePos1 = float3(sin(time * 0.337), sin(time * -0.989), abs(sin(time * 0.428))) ;
            	float3 spherePos2 = float3(sin(time * -0.214), sin(time * 0.56), abs(sin(time * -0.725)));
            	float3 spherePos3 = float3(sin(time * -0.671), sin(time * 0.773), abs(sin(time * 0.272)));

            	float3 moveScale = float3(0.005, 0.005, 0.15);
            	
                float sphere1 = SignedDistanceSphere(position, spherePos1 * moveScale, _SphereSize / 100 * 0.5);
            	float sphere2 = SignedDistanceSphere(position, spherePos2 * moveScale, _SphereSize / 100 * 0.75);
            	float sphere3 = SignedDistanceSphere(position, spherePos3 * moveScale, _SphereSize / 100);
            	float sphere4 = SignedDistanceSphere(position, 0, 0.045);	

            	float spheres = SmoothCombine(sphere1, sphere2, _Smoothness);
            	spheres = SmoothCombine(spheres, sphere3, _Smoothness);
            	spheres = SmoothCombine(spheres, sphere4, _Smoothness);
            	
                return spheres;  
            }

	        // Calculate the surface normal at a point in the scene
			float3 GetNormal(float3 rayPosition) {
				float2 e = float2(SURFACE_DISTANCE, 0);

				const float3 normal = GetDistance(rayPosition) - float3(
					GetDistance(rayPosition-e.xyy),
					GetDistance(rayPosition-e.yxy),
					GetDistance(rayPosition-e.yyx)
				);

				return normalize(normal);
			}
    		
            // Shadow marching function
			bool ShadowRayMarch(const Ray InRay, out rOut outS)
			{
			    float distance = 0.0;
			    for (int i = 0; i < MAX_STEPS; i++)
			    {
			        const float3 position = InRay.origin + distance * InRay.direction;
			        const float sceneDistance = GetDistance(position);
        			distance += sceneDistance;
        			outS.hitPosition = position;
			        if (sceneDistance < SURFACE_DISTANCE) return true; // Ray is obstructed by the scene
			        if (distance > MAX_DISTANCE) return false; // Ray reached light source without obstruction
			    }
			    return false;
			}

			float SoftShadow(float3 ro, float3 lDir, float start, float end, float k)
			{
			    float res = 1.0;
			    float t = start;
			    for (int i = 0; i < MAX_STEPS; i++)
			    {
			        float3 p = ro + t * lDir;
			        float h = GetDistance(p);
			        float r = k * h / t;
			        res = min(res, r);
			        t += clamp(h, 0.02, 0.1);
			        if (h < SURFACE_DISTANCE || t > end)
			            break;
			    }
			    return clamp(res, 0.0, 1.0);
			}
    		
			half4 ShadowPassFragment(Varyings input) : SV_TARGET
			{
			    Ray ray = GenerateRay(_WorldSpaceCameraPos, input.positionOS);
			    rOut outS;
			    float4 colour = 0;
			
			    if(ShadowRayMarch(ray, outS))
    			{
    			    // Shadow calculations
    			    float3 lightDir = normalize(_LightPositionWS - outS.hitPosition);
    			    float distToLight = length(_LightPositionWS - outS.hitPosition);
    			    float shadow = SoftShadow(outS.hitPosition, lightDir, SURFACE_DISTANCE*2.0, distToLight, 16.0);
    			    
    			    return shadow;
    			}

			    return colour;
			}
    		
    		ENDHLSL
		}
    }
}