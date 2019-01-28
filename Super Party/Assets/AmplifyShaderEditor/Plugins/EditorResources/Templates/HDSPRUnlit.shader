Shader /*ase_name*/ "Hidden/Templates/HDSRPUnlit" /*end*/
{
    Properties
    {
		/*ase_props*/
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="HDRenderPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

		Blend One Zero
		Cull Back
		ZTest LEqual
		ZWrite On
		Offset 0,0

		HLSLINCLUDE
		#pragma target 4.5
		#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch
		ENDHLSL

		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass*/
			Name "Depth prepass"
			Tags{ "LightMode" = "DepthForwardOnly" }

			ColorMask 0
			/*ase_stencil*/
            HLSLPROGRAM
        
            #pragma vertex Vert
            #pragma fragment Frag
        
			/*ase_pragma*/

            #define UNITY_MATERIAL_UNLIT
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
			#define SHADERPASS SHADERPASS_DEPTH_ONLY
            
		    #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
        		
			#include "HDRP/Material/Material.hlsl"
           
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            struct AttributesMesh
			{
                float4 positionOS : POSITION;
				float4 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
            };
           
			struct PackedVaryingsToPS
			{
				float4 positionCS : SV_Position;
				/*ase_interp(0,):sp=sp.xyzw*/
			};

			struct SurfaceDescription
            {
                float Alpha;
                float AlphaClipThreshold;
            };
            

			PackedVaryingsToPS Vert( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsToPS outputPackedVaryingsToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputVaryingsMeshToPS );
				
				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsToPS=PackedVaryingsToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;2;-1;_Vertex*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;3;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;
				
				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );
				outputPackedVaryingsToPS.positionCS = positionCS;
				return outputPackedVaryingsToPS;
			}

			void Frag ( PackedVaryingsToPS packedInput , out float4 outColor : SV_Target /*ase_frag_input*/)
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;
				
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );
				SurfaceData surfaceData;
				
				SurfaceDescription surfaceDescription = ( SurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsToPS*/
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold =  /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/0/*end*/;

			#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
			#endif
				ZERO_INITIALIZE ( SurfaceData, surfaceData );
				
				BuiltinData builtinData;
				ZERO_INITIALIZE ( BuiltinData, builtinData );
				builtinData.opacity = surfaceDescription.Alpha;
				builtinData.bakeDiffuseLighting = float3( 0.0, 0.0, 0.0 );
				builtinData.velocity = float2( 0.0, 0.0 );
				builtinData.shadowMask0 = 0.0;
				builtinData.shadowMask1 = 0.0;
				builtinData.shadowMask2 = 0.0;
				builtinData.shadowMask3 = 0.0;
				builtinData.distortion = float2( 0.0, 0.0 );
				builtinData.distortionBlur = 0.0;
				builtinData.depthOffset = 0.0;

				outColor = float4( 0.0, 0.0, 0.0, 0.0 );
			}
        
            ENDHLSL
        }
		/*ase_pass*/
        Pass
        {
			/*ase_main_pass*/
            Name "Forward Unlit"
            Tags { "LightMode" = "ForwardOnly" }
        
			ColorMask RGBA

			/*ase_stencil*/
            HLSLPROGRAM
        
            #pragma vertex Vert
            #pragma fragment Frag
        
			/*ase_pragma*/

            #define UNITY_MATERIAL_UNLIT
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
            #define SHADERPASS SHADERPASS_FORWARD_UNLIT
            
		    #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
        		
			#include "HDRP/Material/Material.hlsl"
           
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            struct AttributesMesh
			{
                float4 positionOS : POSITION;
				float4 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
            };
           
			struct PackedVaryingsToPS
			{
				float4 positionCS : SV_Position;
				/*ase_interp(0,):sp=sp.xyzw*/
			};

			struct SurfaceDescription
            {
                float3 Color;
                float Alpha;
                float AlphaClipThreshold;
            };
            
			PackedVaryingsToPS Vert( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsToPS outputPackedVaryingsToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputVaryingsMeshToPS );
				
				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsToPS=PackedVaryingsToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;3;-1;_Vertex*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;4;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );
				outputPackedVaryingsToPS.positionCS = positionCS;
				return outputPackedVaryingsToPS;
			}

			float4 Frag ( PackedVaryingsToPS packedInput /*ase_frag_input*/) : SV_Target
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;
				
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );
				SurfaceData surfaceData;
				
				SurfaceDescription surfaceDescription = ( SurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsToPS*/
				surfaceDescription.Color =  /*ase_frag_out:Color;Float3;0*/float3( 1, 1, 1 )/*end*/;
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;1;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold =  /*ase_frag_out:Alpha Clip Threshold;Float;2;-1;_AlphaClip*/0/*end*/;

			#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
			#endif
				ZERO_INITIALIZE ( SurfaceData, surfaceData );
				surfaceData.color = surfaceDescription.Color;
				
				BuiltinData builtinData;
				ZERO_INITIALIZE ( BuiltinData, builtinData );
				builtinData.opacity = surfaceDescription.Alpha;
				builtinData.bakeDiffuseLighting = float3( 0.0, 0.0, 0.0 );
				builtinData.velocity = float2( 0.0, 0.0 );
				builtinData.shadowMask0 = 0.0;
				builtinData.shadowMask1 = 0.0;
				builtinData.shadowMask2 = 0.0;
				builtinData.shadowMask3 = 0.0;
				builtinData.distortion = float2( 0.0, 0.0 );
				builtinData.distortionBlur = 0.0;
				builtinData.depthOffset = 0.0;

				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( input.positionSS.xy, surfaceData );
				float4 outColor = ApplyBlendMode ( bsdfData.color + builtinData.emissiveColor, builtinData.opacity );
				outColor = EvaluateAtmosphericScattering ( posInput, outColor );
				return outColor;
			}
        
            ENDHLSL
        }

		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass*/
            Name "META"
            Tags { "LightMode" = "Meta" }
            Cull Off
            
            HLSLPROGRAM
				
				#pragma vertex Vert
				#pragma fragment Frag
				
				/*ase_pragma*/
				
				#define UNITY_MATERIAL_UNLIT
        
				#include "CoreRP/ShaderLibrary/Common.hlsl"
				#include "CoreRP/ShaderLibrary/Wind.hlsl"
        
				#include "ShaderGraphLibrary/Functions.hlsl"
        
				#include "HDRP/ShaderPass/FragInputs.hlsl"
				#include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
                #define SHADERPASS SHADERPASS_LIGHT_TRANSPORT
        
                #define ATTRIBUTES_NEED_NORMAL
                #define ATTRIBUTES_NEED_TANGENT
                #define ATTRIBUTES_NEED_TEXCOORD0
                #define ATTRIBUTES_NEED_TEXCOORD1
                #define ATTRIBUTES_NEED_TEXCOORD2
                #define ATTRIBUTES_NEED_COLOR
        
        
				#include "ShaderGraphLibrary/Functions.hlsl"
				#include "HDRP/ShaderVariables.hlsl"
        
                #include "HDRP/Material/Material.hlsl"
				#include "HDRP/Material/MaterialUtilities.hlsl"
        
        
                struct AttributesMesh 
				{
                    float3 positionOS : POSITION;
                    float3 normalOS : NORMAL; 
                    float4 tangentOS : TANGENT;
                    float2 uv0 : TEXCOORD0;
                    float2 uv1 : TEXCOORD1;
                    float2 uv2 : TEXCOORD2;
                    float4 color : COLOR;
					/*ase_vdata:p=p;n=n;t=t;uv0=tc0;uv1=tc1;uv2=tc2;c=c*/
                };
                
                struct PackedVaryingsMeshToPS 
				{
                    float4 positionCS : SV_Position;
					/*ase_interp(0,):sp=sp.xyzw*/
                };

				struct SurfaceDescription
                {
                    float3 Color;
                    float Alpha;
                    float AlphaClipThreshold;
                };
                    
				CBUFFER_START(UnityPerMaterial)
				/*ase_globals*/
				CBUFFER_END
				/*ase_funcs*/

        
				void BuildSurfaceData(FragInputs fragInputs, SurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData)
				{
					ZERO_INITIALIZE(SurfaceData, surfaceData);
					surfaceData.color = surfaceDescription.Color;
				}
        
				void GetSurfaceAndBuiltinData(SurfaceDescription surfaceDescription,FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
				{
				#if _ALPHATEST_ON
					DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
				#endif

					BuildSurfaceData(fragInputs, surfaceDescription, V, surfaceData);
					ZERO_INITIALIZE(BuiltinData, builtinData);
        
					builtinData.opacity = surfaceDescription.Alpha;
					builtinData.bakeDiffuseLighting = float3(0.0, 0.0, 0.0);
        
					builtinData.velocity = float2(0.0, 0.0);
					builtinData.shadowMask0 = 0.0;
					builtinData.shadowMask1 = 0.0;
					builtinData.shadowMask2 = 0.0;
					builtinData.shadowMask3 = 0.0;
        
					builtinData.distortion = float2(0.0, 0.0);
					builtinData.distortionBlur = 0.0;
					builtinData.depthOffset = 0.0;
				}
        
				CBUFFER_START(UnityMetaPass)
				bool4 unity_MetaVertexControl;
				bool4 unity_MetaFragmentControl;
				CBUFFER_END
				
				float unity_OneOverOutputBoost;
				float unity_MaxOutputValue;

				PackedVaryingsMeshToPS Vert(AttributesMesh inputMesh /*ase_vert_input*/  )
				{
					PackedVaryingsMeshToPS outputPackedVaryingsToPS;
					
					UNITY_SETUP_INSTANCE_ID(inputMesh);
					UNITY_TRANSFER_INSTANCE_ID(inputMesh, outputPackedVaryingsToPS);

					/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsToPS=PackedVaryingsMeshToPS*/
					inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;3;-1;_Vertex*/ float3( 0, 0, 0 ) /*end*/;
					inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;4;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

					float2 uv;

					if (unity_MetaVertexControl.x)
					{
						uv = inputMesh.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
					}
					else if (unity_MetaVertexControl.y)
					{
						uv = inputMesh.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
					}

					outputPackedVaryingsToPS.positionCS = float4(uv * 2.0 - 1.0, inputMesh.positionOS.z > 0 ? 1.0e-4 : 0.0, 1.0);

                    return outputPackedVaryingsToPS;
				}

				float4 Frag(PackedVaryingsMeshToPS packedInput) : SV_Target
				{
					FragInputs input;
                    ZERO_INITIALIZE(FragInputs, input);
                    input.worldToTangent = k_identity3x3;
                    input.positionSS = packedInput.positionCS;
                 
					PositionInputs posInput = GetPositionInput(input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS);

					float3 V = 0;
				
					SurfaceData surfaceData;
					BuiltinData builtinData;
					SurfaceDescription surfaceDescription = ( SurfaceDescription ) 0;
					/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
					surfaceDescription.Color =  /*ase_frag_out:Color;Float3;0*/float3( 1, 1, 1 )/*end*/;
					surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;1;-1;_Alpha*/1/*end*/;
					surfaceDescription.AlphaClipThreshold =  /*ase_frag_out:Alpha Clip Threshold;Float;2;-1;_AlphaClip*/0/*end*/;

					GetSurfaceAndBuiltinData(surfaceDescription,input, V, posInput, surfaceData, builtinData);

					BSDFData bsdfData = ConvertSurfaceDataToBSDFData(input.positionSS.xy, surfaceData);
					LightTransportData lightTransportData = GetLightTransportData(surfaceData, builtinData, bsdfData);

					float4 res = float4(0.0, 0.0, 0.0, 1.0);

					if (unity_MetaFragmentControl.x)
					{
						res.rgb = clamp(pow(abs(lightTransportData.diffuseColor), saturate(unity_OneOverOutputBoost)), 0, unity_MaxOutputValue);
					}

					if (unity_MetaFragmentControl.y)
					{
						res.rgb = lightTransportData.emissiveColor;
					}

					return res;
				}

            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
	CustomEditor "ASEMaterialInspector"
}
