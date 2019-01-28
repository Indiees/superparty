Shader /*ase_name*/ "Hidden/Templates/HDSRPPBR" /*end*/
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
        
		Cull Back
		Blend One Zero
		ZTest LEqual
		ZWrite On

		HLSLINCLUDE
		#pragma target 4.5
		#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch
		

		struct GlobalSurfaceDescription
		{
			//Standard
			float3 Albedo;
			float3 Normal;
			float3 Specular;
			float Metallic;
			float3 Emission;
			float Smoothness;
			float Occlusion;
			float Alpha;
			float AlphaClipThreshold;
			float CoatMask;
			//SSS
			uint DiffusionProfile;
			float SubsurfaceMask;
			//Transmission
			float Thickness;
			// Anisotropic
			float3 TangentWS;
			float Anisotropy; 
			//Iridescence
			float IridescenceThickness;
			float IridescenceMask;
			// Transparency
			float IndexOfRefraction;
			float3 TransmittanceColor;
			float TransmittanceAbsorptionDistance;
			float TransmittanceMask;
		};

		struct AlphaSurfaceDescription
		{
			float Alpha;
			float AlphaClipThreshold;
		};

		ENDHLSL
		/*ase_pass*/
        Pass
        {
			/*ase_main_pass*/
            Name "GBuffer"
            Tags { "LightMode" = "GBuffer" }    
			Stencil
			{
				WriteMask 7
				Ref  2
				Comp Always
				Pass Replace
			}
     
            HLSLPROGRAM
        	
			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/
		
            #define UNITY_MATERIAL_LIT
        
            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
            #define SHADERPASS SHADERPASS_GBUFFER
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define ATTRIBUTES_NEED_TEXCOORD1
            #define ATTRIBUTES_NEED_TEXCOORD2
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TANGENT_TO_WORLD
            #define VARYINGS_NEED_TEXCOORD1
            #define VARYINGS_NEED_TEXCOORD2
        
            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/MaterialUtilities.hlsl"
		
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            float3x3 BuildWorldToTangent(float4 tangentWS, float3 normalWS)
            {
        	    float3 unnormalizedNormalWS = normalWS;
                float renormFactor = 1.0 / length(unnormalizedNormalWS);
                float3x3 worldToTangent = CreateWorldToTangent(unnormalizedNormalWS, tangentWS.xyz, tangentWS.w > 0.0 ? 1.0 : -1.0);
                worldToTangent[0] = worldToTangent[0] * renormFactor;
                worldToTangent[1] = worldToTangent[1] * renormFactor;
                worldToTangent[2] = worldToTangent[2] * renormFactor;
                return worldToTangent;
            }

            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
				/*ase_vdata:p=p;n=n;t=t;uv1=tc1;uv2=tc2*/
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
                float3 interp00 : TEXCOORD0;
                float3 interp01 : TEXCOORD1;
                float4 interp02 : TEXCOORD2;
                float4 interp03 : TEXCOORD3;
				/*ase_interp(4,):sp=sp.xyzw;rwp=tc0;wn=tc1;wt=tc2*/
            };
        
			void BuildSurfaceData ( FragInputs fragInputs, GlobalSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData )
			{
				ZERO_INITIALIZE ( SurfaceData, surfaceData );

				float3 normalTS = float3( 0.0f, 0.0f, 1.0f );
				normalTS = surfaceDescription.Normal;
				GetNormalWS ( fragInputs, V, normalTS, surfaceData.normalWS );

				surfaceData.ambientOcclusion = 1.0f;

				surfaceData.baseColor = surfaceDescription.Albedo;
				surfaceData.perceptualSmoothness = surfaceDescription.Smoothness;
				surfaceData.ambientOcclusion = surfaceDescription.Occlusion;

				surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;

#ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
				surfaceData.specularColor = surfaceDescription.Specular;
#else
				surfaceData.metallic = surfaceDescription.Metallic;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceData.diffusionProfile = surfaceDescription.DiffusionProfile;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
				surfaceData.subsurfaceMask = surfaceDescription.SubsurfaceMask;
#else
				surfaceData.subsurfaceMask = 1.0f;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
				surfaceData.thickness = surfaceDescription.Thickness;
#endif

				surfaceData.tangentWS = normalize ( fragInputs.worldToTangent[ 0 ].xyz );
				surfaceData.tangentWS = Orthonormalize ( surfaceData.tangentWS, surfaceData.normalWS );

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
				surfaceData.anisotropy = surfaceDescription.Anisotropy;

#else
				surfaceData.anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
				surfaceData.coatMask = surfaceDescription.CoatMask;
#else
				surfaceData.coatMask = 0.0f;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
				surfaceData.iridescenceThickness = surfaceDescription.IridescenceThickness;
				surfaceData.iridescenceMask = surfaceDescription.IridescenceMask;
#else
				surfaceData.iridescenceThickness = 0.0;
				surfaceData.iridescenceMask = 1.0;
#endif

				//ASE CUSTOM TAG
#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceData.ior = surfaceDescription.IndexOfRefraction;
				surfaceData.transmittanceColor = surfaceDescription.TransmittanceColor;
				surfaceData.atDistance = surfaceDescription.TransmittanceAbsorptionDistance;
				surfaceData.transmittanceMask = surfaceDescription.TransmittanceMask;
#else
				surfaceData.ior = 1.0;
				surfaceData.transmittanceColor = float3( 1.0, 1.0, 1.0 );
				surfaceData.atDistance = 1000000.0;
				surfaceData.transmittanceMask = 0.0;
#endif

				surfaceData.specularOcclusion = 1.0;

#if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO ( V, bentNormalWS, surfaceData );
#elif defined(_MASKMAP)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion ( NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness ( surfaceData.perceptualSmoothness ) );
#endif
			}

            void GetSurfaceAndBuiltinData( GlobalSurfaceDescription surfaceDescription , FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
        
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
				BuildSurfaceData( fragInputs, surfaceDescription, V, surfaceData );
        
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS =                   surfaceData.normalWS;
        
                builtinData.opacity =                   surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting =       SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);    // see GetBuiltinData()
        
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
				builtinData.emissiveColor = surfaceDescription.Emission;
                builtinData.velocity = float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion =                float2(0.0, 0.0);
                builtinData.distortionBlur =            0.0;             
                builtinData.depthOffset =               0.0;             
            }
        
			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;9;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;10;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float3 normalWS = TransformObjectToWorldNormal ( inputMesh.normalOS );
				float4 tangentWS = float4( TransformObjectToWorldDir ( inputMesh.tangentOS.xyz ), inputMesh.tangentOS.w );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				outputPackedVaryingsMeshToPS.interp00.xyz = positionRWS;
				outputPackedVaryingsMeshToPS.interp01.xyz = normalWS;
				outputPackedVaryingsMeshToPS.interp02.xyzw = tangentWS;
				outputPackedVaryingsMeshToPS.interp03.xy = inputMesh.uv1;
				outputPackedVaryingsMeshToPS.interp03.zw = inputMesh.uv2;
			
				return outputPackedVaryingsMeshToPS;
			}

			void Frag ( PackedVaryingsMeshToPS packedInput, OUTPUT_GBUFFER ( outGBuffer ) OUTPUT_GBUFFER_SHADOWMASK ( outShadowMaskBuffer ) /*ase_frag_input*/ )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				
				/*ase_local_var:rwp*/float3 positionRWS = packedInput.interp00.xyz;
				/*ase_local_var:wn*/float3 normalWS = packedInput.interp01.xyz;
				/*ase_local_var:wt*/float4 tangentWS = packedInput.interp02.xyzw;
				float2 uv1 = packedInput.interp03.xy;
				float2 uv2 = packedInput.interp03.zw;

				input.positionSS = packedInput.positionCS;
				input.positionRWS = positionRWS;
				input.worldToTangent = BuildWorldToTangent ( tangentWS, normalWS );
				input.texCoord1 = uv1;
				input.texCoord2 = uv2;

				// input.positionSS is SV_Position
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );

				/*ase_local_var:wvd*/float3 normalizedWorldViewDir = GetWorldSpaceNormalizeViewDir ( input.positionRWS );

				SurfaceData surfaceData;
				BuiltinData builtinData;

				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Albedo = /*ase_frag_out:Albedo;Float3;0;-1;_Albedo*/float3( 0.5, 0.5, 0.5 )/*end*/;
				surfaceDescription.Normal = /*ase_frag_out:Normal;Float3;1;-1;_Normal*/float3( 0, 0, 1 )/*end*/;
				surfaceDescription.Emission = /*ase_frag_out:Emission;Float3;2;-1;_Emission*/0/*end*/;
				surfaceDescription.Specular = /*ase_frag_out:Specular;Float3;3;-1;_Specular*/0/*end*/;
				surfaceDescription.Metallic = /*ase_frag_out:Metallic;Float;4;-1;_Metallic*/0/*end*/;
				surfaceDescription.Smoothness = /*ase_frag_out:Smoothness;Float;5;-1;_Smoothness*/0.5/*end*/;
				surfaceDescription.Occlusion = /*ase_frag_out:Occlusion;Float;6;-1;_Occlusion*/1/*end*/;
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;7;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;8;-1;_AlphaClip*/0/*end*/;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = /*ase_frag_out:Coat Mask;Float;11;-1;_CoatMask*/0/*end*/;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = /*ase_frag_out:Diffusion Profile;Int;12;-1;_DiffusionProfile*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = /*ase_frag_out:Subsurface Mask;Float;13;-1;_SubsurfaceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = /*ase_frag_out:Thickness;Float;14;-1;_Thickness*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = /*ase_frag_out:Anisotropy;Float;15;-1;_Anisotropy*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = /*ase_frag_out:Iridescence Thickness;Float;16;-1;_IridescenceThickness*/0/*end*/;
				surfaceDescription.IridescenceMask = /*ase_frag_out:Iridescence Mask;Float;17;-1;_IridescenceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = /*ase_frag_out:IndexOfRefraction;Float;18;-1;_IndexOfRefraction*/1/*end*/;
				surfaceDescription.TransmittanceColor = /*ase_frag_out:Transmittance Color;Float3;19;-1;_TransmittanceColor*/float3( 1, 1, 1 )/*end*/;
				surfaceDescription.TransmittanceAbsorptionDistance = /*ase_frag_out:Transmittance Absorption Distance;Float;20;-1;_TransmittanceAbsorptionDistance*/1000000/*end*/;
				surfaceDescription.TransmittanceMask = /*ase_frag_out:TransmittanceMask;Float;21;-1;_TransmittanceMask*/0/*end*/;
#endif
				GetSurfaceAndBuiltinData ( surfaceDescription, input, normalizedWorldViewDir, posInput, surfaceData, builtinData );


				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( input.positionSS.xy, surfaceData );

				PreLightData preLightData = GetPreLightData ( normalizedWorldViewDir, posInput, bsdfData );

				float3 bakeDiffuseLighting = GetBakedDiffuseLighting ( surfaceData, builtinData, bsdfData, preLightData );

				ENCODE_INTO_GBUFFER ( surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer );
				ENCODE_SHADOWMASK_INTO_GBUFFER ( float4( builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3 ), outShadowMaskBuffer );

			}

            ENDHLSL
        }
        
		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass:SyncP*/
            Name "GBufferWithPrepass"
            Tags { "LightMode" = "GBufferWithPrepass" }
			Stencil
			{
				WriteMask 7
				Ref  2
				Comp Always
				Pass Replace
			}
     
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/
		
            #define UNITY_MATERIAL_LIT
        
            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
            #define SHADERPASS SHADERPASS_GBUFFER
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
			#define SHADERPASS_GBUFFER_BYPASS_ALPHA_TEST
        
            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/MaterialUtilities.hlsl"
		
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

	        struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				/*ase_interp(0,):sp=sp.xyzw*/
            };

        
			void BuildSurfaceData ( FragInputs fragInputs, GlobalSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData )
			{
				ZERO_INITIALIZE ( SurfaceData, surfaceData );

				float3 normalTS = float3( 0.0f, 0.0f, 1.0f );
				normalTS = surfaceDescription.Normal;
				GetNormalWS ( fragInputs, V, normalTS, surfaceData.normalWS );

				surfaceData.ambientOcclusion = 1.0f;

				surfaceData.baseColor = surfaceDescription.Albedo;
				surfaceData.perceptualSmoothness = surfaceDescription.Smoothness;
				surfaceData.ambientOcclusion = surfaceDescription.Occlusion;

				surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;

#ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
				surfaceData.specularColor = surfaceDescription.Specular;
#else
				surfaceData.metallic = surfaceDescription.Metallic;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceData.diffusionProfile = surfaceDescription.DiffusionProfile;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
				surfaceData.subsurfaceMask = surfaceDescription.SubsurfaceMask;
#else
				surfaceData.subsurfaceMask = 1.0f;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
				surfaceData.thickness = surfaceDescription.Thickness;
#endif

				surfaceData.tangentWS = normalize ( fragInputs.worldToTangent[ 0 ].xyz );
				surfaceData.tangentWS = Orthonormalize ( surfaceData.tangentWS, surfaceData.normalWS );

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
				surfaceData.anisotropy = surfaceDescription.Anisotropy;

#else
				surfaceData.anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
				surfaceData.coatMask = surfaceDescription.CoatMask;
#else
				surfaceData.coatMask = 0.0f;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
				surfaceData.iridescenceThickness = surfaceDescription.IridescenceThickness;
				surfaceData.iridescenceMask = surfaceDescription.IridescenceMask;
#else
				surfaceData.iridescenceThickness = 0.0;
				surfaceData.iridescenceMask = 1.0;
#endif

				//ASE CUSTOM TAG
#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceData.ior = surfaceDescription.IndexOfRefraction;
				surfaceData.transmittanceColor = surfaceDescription.TransmittanceColor;
				surfaceData.atDistance = surfaceDescription.TransmittanceAbsorptionDistance;
				surfaceData.transmittanceMask = surfaceDescription.TransmittanceMask;
#else
				surfaceData.ior = 1.0;
				surfaceData.transmittanceColor = float3( 1.0, 1.0, 1.0 );
				surfaceData.atDistance = 1000000.0;
				surfaceData.transmittanceMask = 0.0;
#endif

				surfaceData.specularOcclusion = 1.0;

#if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO ( V, bentNormalWS, surfaceData );
#elif defined(_MASKMAP)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion ( NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness ( surfaceData.perceptualSmoothness ) );
#endif
			}

            void GetSurfaceAndBuiltinData( GlobalSurfaceDescription surfaceDescription , FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
        
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
				BuildSurfaceData(fragInputs, surfaceDescription, V, surfaceData);
        
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS =                   surfaceData.normalWS;
        
                builtinData.opacity =                   surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting =       SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
				builtinData.emissiveColor = surfaceDescription.Emission;
                builtinData.velocity = float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion =                float2(0.0, 0.0); 
                builtinData.distortionBlur =            0.0;              
                builtinData.depthOffset =               0.0;              
            }
        
			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;9;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;10;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				return outputPackedVaryingsMeshToPS;
			}

			void Frag ( PackedVaryingsMeshToPS packedInput, OUTPUT_GBUFFER ( outGBuffer ) OUTPUT_GBUFFER_SHADOWMASK ( outShadowMaskBuffer ) /*ase_frag_input*/ )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;


				// input.positionSS is SV_Position
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );

				float3 normalizedWorldViewDir = 0;

				SurfaceData surfaceData;
				BuiltinData builtinData;

				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Albedo = /*ase_frag_out:Albedo;Float3;0;-1;_Albedo*/float3( 0.5, 0.5, 0.5 )/*end*/;
				surfaceDescription.Normal = /*ase_frag_out:Normal;Float3;1;-1;_Normal*/float3( 0, 0, 1 )/*end*/;
				surfaceDescription.Emission = /*ase_frag_out:Emission;Float3;2;-1;_Emission*/0/*end*/;
				surfaceDescription.Specular = /*ase_frag_out:Specular;Float3;3;-1;_Specular*/0/*end*/;
				surfaceDescription.Metallic = /*ase_frag_out:Metallic;Float;4;-1;_Metallic*/0/*end*/;
				surfaceDescription.Smoothness = /*ase_frag_out:Smoothness;Float;5;-1;_Smoothness*/0.5/*end*/;
				surfaceDescription.Occlusion = /*ase_frag_out:Occlusion;Float;6;-1;_Occlusion*/1/*end*/;
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;7;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;8;-1;_AlphaClip*/0/*end*/;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = /*ase_frag_out:Coat Mask;Float;11;-1;_CoatMask*/0/*end*/;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = /*ase_frag_out:Diffusion Profile;Int;12;-1;_DiffusionProfile*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = /*ase_frag_out:Subsurface Mask;Float;13;-1;_SubsurfaceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = /*ase_frag_out:Thickness;Float;14;-1;_Thickness*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = /*ase_frag_out:Anisotropy;Float;15;-1;_Anisotropy*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = /*ase_frag_out:Iridescence Thickness;Float;16;-1;_IridescenceThickness*/0/*end*/;
				surfaceDescription.IridescenceMask = /*ase_frag_out:Iridescence Mask;Float;17;-1;_IridescenceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = /*ase_frag_out:IndexOfRefraction;Float;18;-1;_IndexOfRefraction*/1/*end*/;
				surfaceDescription.TransmittanceColor = /*ase_frag_out:Transmittance Color;Float3;19;-1;_TransmittanceColor*/float3( 1, 1, 1 )/*end*/;
				surfaceDescription.TransmittanceAbsorptionDistance = /*ase_frag_out:Transmittance Absorption Distance;Float;20;-1;_TransmittanceAbsorptionDistance*/1000000/*end*/;
				surfaceDescription.TransmittanceMask = /*ase_frag_out:TransmittanceMask;Float;21;-1;_TransmittanceMask*/0/*end*/;
#endif

				GetSurfaceAndBuiltinData ( surfaceDescription, input, normalizedWorldViewDir, posInput, surfaceData, builtinData );

				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( input.positionSS.xy, surfaceData );

				PreLightData preLightData = GetPreLightData ( normalizedWorldViewDir, posInput, bsdfData );

				float3 bakeDiffuseLighting = GetBakedDiffuseLighting ( surfaceData, builtinData, bsdfData, preLightData );

				ENCODE_INTO_GBUFFER ( surfaceData, bakeDiffuseLighting, posInput.positionSS, outGBuffer );
				ENCODE_SHADOWMASK_INTO_GBUFFER ( float4( builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3 ), outShadowMaskBuffer );

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

            #define UNITY_MATERIAL_LIT      // Need to be define before including Material.hlsl
        
            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
        
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
        
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
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
            
			void BuildSurfaceData ( FragInputs fragInputs, GlobalSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData )
			{
				ZERO_INITIALIZE ( SurfaceData, surfaceData );

				float3 normalTS = float3( 0.0f, 0.0f, 1.0f );
				normalTS = surfaceDescription.Normal;
				GetNormalWS ( fragInputs, V, normalTS, surfaceData.normalWS );

				surfaceData.ambientOcclusion = 1.0f;

				surfaceData.baseColor = surfaceDescription.Albedo;
				surfaceData.perceptualSmoothness = surfaceDescription.Smoothness;
				surfaceData.ambientOcclusion = surfaceDescription.Occlusion;

				surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;

#ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
				surfaceData.specularColor = surfaceDescription.Specular;
#else
				surfaceData.metallic = surfaceDescription.Metallic;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceData.diffusionProfile = surfaceDescription.DiffusionProfile;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
				surfaceData.subsurfaceMask = surfaceDescription.SubsurfaceMask;

#else
				surfaceData.subsurfaceMask = 1.0f;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
				surfaceData.thickness = surfaceDescription.Thickness;
#endif

				surfaceData.tangentWS = normalize ( fragInputs.worldToTangent[ 0 ].xyz );
				surfaceData.tangentWS = Orthonormalize ( surfaceData.tangentWS, surfaceData.normalWS );

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
				surfaceData.anisotropy = surfaceDescription.Anisotropy;

#else
				surfaceData.anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
				surfaceData.coatMask = surfaceDescription.CoatMask;
#else
				surfaceData.coatMask = 0.0f;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
				surfaceData.iridescenceThickness = surfaceDescription.IridescenceThickness;
				surfaceData.iridescenceMask = surfaceDescription.IridescenceMask;
#else
				surfaceData.iridescenceThickness = 0.0;
				surfaceData.iridescenceMask = 1.0;
#endif

				//ASE CUSTOM TAG
#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceData.ior = surfaceDescription.IndexOfRefraction;
				surfaceData.transmittanceColor = surfaceDescription.TransmittanceColor;
				surfaceData.atDistance = surfaceDescription.TransmittanceAbsorptionDistance;
				surfaceData.transmittanceMask = surfaceDescription.TransmittanceMask;
#else
				surfaceData.ior = 1.0;
				surfaceData.transmittanceColor = float3( 1.0, 1.0, 1.0 );
				surfaceData.atDistance = 1000000.0;
				surfaceData.transmittanceMask = 0.0;
#endif

				surfaceData.specularOcclusion = 1.0;

#if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO ( V, bentNormalWS, surfaceData );
#elif defined(_MASKMAP)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion ( NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness ( surfaceData.perceptualSmoothness ) );
#endif
			}

            void GetSurfaceAndBuiltinData( GlobalSurfaceDescription surfaceDescription, FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
				BuildSurfaceData (fragInputs, surfaceDescription, V, surfaceData);
        
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS = surfaceData.normalWS; 
        
                builtinData.opacity = surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting = SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);
        
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
                builtinData.emissiveColor = surfaceDescription.Emission;
                builtinData.velocity = float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion =                float2(0.0, 0.0);
                builtinData.distortionBlur =            0.0;
                builtinData.depthOffset =               0.0;
            }
        
           
			CBUFFER_START ( UnityMetaPass )
				bool4 unity_MetaVertexControl;
				bool4 unity_MetaFragmentControl;
			CBUFFER_END


			float unity_OneOverOutputBoost;
			float unity_MaxOutputValue;

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;9;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;10;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float2 uv;

				if ( unity_MetaVertexControl.x )
				{
					uv = inputMesh.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
				}
				else if ( unity_MetaVertexControl.y )
				{
					uv = inputMesh.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				}

				outputPackedVaryingsMeshToPS.positionCS = float4( uv * 2.0 - 1.0, inputMesh.positionOS.z > 0 ? 1.0e-4 : 0.0, 1.0 );

				return outputPackedVaryingsMeshToPS;
			}

			float4 Frag ( PackedVaryingsMeshToPS packedInput /*ase_frag_input*/ ) : SV_Target
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;

				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );

				float3 V = 0;

				SurfaceData surfaceData;
				BuiltinData builtinData;

				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Albedo = /*ase_frag_out:Albedo;Float3;0;-1;_Albedo*/float3( 0.5, 0.5, 0.5 )/*end*/;
				surfaceDescription.Normal = /*ase_frag_out:Normal;Float3;1;-1;_Normal*/float3( 0, 0, 1 )/*end*/;
				surfaceDescription.Emission = /*ase_frag_out:Emission;Float3;2;-1;_Emission*/0/*end*/;
				surfaceDescription.Specular = /*ase_frag_out:Specular;Float3;3;-1;_Specular*/0/*end*/;
				surfaceDescription.Metallic = /*ase_frag_out:Metallic;Float;4;-1;_Metallic*/0/*end*/;
				surfaceDescription.Smoothness = /*ase_frag_out:Smoothness;Float;5;-1;_Smoothness*/0.5/*end*/;
				surfaceDescription.Occlusion = /*ase_frag_out:Occlusion;Float;6;-1;_Occlusion*/1/*end*/;
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;7;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;8;-1;_AlphaClip*/0/*end*/;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = /*ase_frag_out:Coat Mask;Float;11;-1;_CoatMask*/0/*end*/;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = /*ase_frag_out:Diffusion Profile;Int;12;-1;_DiffusionProfile*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = /*ase_frag_out:Subsurface Mask;Float;13;-1;_SubsurfaceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = /*ase_frag_out:Thickness;Float;14;-1;_Thickness*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = /*ase_frag_out:Anisotropy;Float;15;-1;_Anisotropy*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = /*ase_frag_out:Iridescence Thickness;Float;16;-1;_IridescenceThickness*/0/*end*/;
				surfaceDescription.IridescenceMask = /*ase_frag_out:Iridescence Mask;Float;17;-1;_IridescenceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = /*ase_frag_out:IndexOfRefraction;Float;18;-1;_IndexOfRefraction*/1/*end*/;
				surfaceDescription.TransmittanceColor = /*ase_frag_out:Transmittance Color;Float3;19;-1;_TransmittanceColor*/float3( 1, 1, 1 )/*end*/;
				surfaceDescription.TransmittanceAbsorptionDistance = /*ase_frag_out:Transmittance Absorption Distance;Float;20;-1;_TransmittanceAbsorptionDistance*/1000000/*end*/;
				surfaceDescription.TransmittanceMask = /*ase_frag_out:TransmittanceMask;Float;21;-1;_TransmittanceMask*/0/*end*/;
#endif

				GetSurfaceAndBuiltinData ( surfaceDescription, input, V, posInput, surfaceData, builtinData );

				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( input.positionSS.xy, surfaceData );

				LightTransportData lightTransportData = GetLightTransportData ( surfaceData, builtinData, bsdfData );

				float4 res = float4( 0.0, 0.0, 0.0, 1.0 );
				if ( unity_MetaFragmentControl.x )
				{
					res.rgb = clamp ( pow ( abs ( lightTransportData.diffuseColor ), saturate ( unity_OneOverOutputBoost ) ), 0, unity_MaxOutputValue );
				}

				if ( unity_MetaFragmentControl.y )
				{
					res.rgb = lightTransportData.emissiveColor;
				}

				return res;
			}
       
            ENDHLSL
        }

		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass*/
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ColorMask 0
			ZClip [_ZClip]

            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/

            #define UNITY_MATERIAL_LIT
        
            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
            #define SHADERPASS SHADERPASS_SHADOWS
            #define USE_LEGACY_UNITY_MATRIX_VARIABLES
        
            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/MaterialUtilities.hlsl"
        
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				/*ase_interp(0,):sp=sp.xyzw*/
            };
        
            void BuildSurfaceData(FragInputs fragInputs, AlphaSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData)
            {
                ZERO_INITIALIZE(SurfaceData, surfaceData);
                surfaceData.ambientOcclusion =      1.0f;
                surfaceData.subsurfaceMask =        1.0f;
        
                surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;
        #ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
        #endif
        #ifdef _MATERIAL_FEATURE_TRANSMISSION
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
        #endif
        #ifdef _MATERIAL_FEATURE_ANISOTROPY
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
        #endif
        #ifdef _MATERIAL_FEATURE_CLEAR_COAT
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
        #endif
        #ifdef _MATERIAL_FEATURE_IRIDESCENCE
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
        #endif
        #ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
        #endif
        
                float3 normalTS = float3(0.0f, 0.0f, 1.0f);
                GetNormalWS(fragInputs, V, normalTS, surfaceData.normalWS);
                surfaceData.tangentWS = normalize(fragInputs.worldToTangent[0].xyz);
                surfaceData.tangentWS = Orthonormalize(surfaceData.tangentWS, surfaceData.normalWS);
                surfaceData.anisotropy = 0;
                surfaceData.coatMask = 0.0f;
                surfaceData.iridescenceThickness = 0.0;
                surfaceData.iridescenceMask = 1.0;
                surfaceData.ior = 1.0;
                surfaceData.transmittanceColor = float3(1.0, 1.0, 1.0);
                surfaceData.atDistance = 1000000.0;
                surfaceData.transmittanceMask = 0.0;
                surfaceData.specularOcclusion = 1.0;
        #if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
                surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO(V, bentNormalWS, surfaceData);
        #elif defined(_MASKMAP)
                surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion(NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness(surfaceData.perceptualSmoothness));
        #endif
            }
        
            void GetSurfaceAndBuiltinData( AlphaSurfaceDescription surfaceDescription, FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
                BuildSurfaceData(fragInputs, surfaceDescription, V, surfaceData);
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS = surfaceData.normalWS;
        
                builtinData.opacity = surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting = SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);
        
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
                builtinData.velocity = float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion = float2(0.0, 0.0);
                builtinData.distortionBlur = 0.0;             
                builtinData.depthOffset = 0.0;             
            }

			PackedVaryingsMeshToPS Vert( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;2;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;3;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				return outputPackedVaryingsMeshToPS;
			}

			void Frag( PackedVaryingsMeshToPS packedInput, 
#ifdef WRITE_NORMAL_BUFFER
				OUTPUT_NORMALBUFFER ( outNormalBuffer )
#else
				out float4 outColor : SV_Target 
#endif 
			/*ase_frag_input*/ )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );
				float3 V = 0; // Avoid the division by 0
				
				SurfaceData surfaceData;
				BuiltinData builtinData;

				AlphaSurfaceDescription surfaceDescription = ( AlphaSurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/0/*end*/;

				GetSurfaceAndBuiltinData ( surfaceDescription, input, V, posInput, surfaceData, builtinData );

#ifdef WRITE_NORMAL_BUFFER
				ENCODE_INTO_NORMALBUFFER ( surfaceData, posInput.positionSS, outNormalBuffer );
#elif defined(SCENESELECTIONPASS)
				outColor = float4( _ObjectId, _PassValue, 1.0, 1.0 );
#else
				outColor = float4( 0.0, 0.0, 0.0, 0.0 );
#endif
			}
            ENDHLSL
        }
		
		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass*/
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ColorMask 0
        
            HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/

            #define UNITY_MATERIAL_LIT
            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
        
			#define SHADERPASS SHADERPASS_DEPTH_ONLY

            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/MaterialUtilities.hlsl"

			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				/*ase_interp(0,):sp=sp.xyzw*/
            };

            void BuildSurfaceData(FragInputs fragInputs, AlphaSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData)
            {
                ZERO_INITIALIZE(SurfaceData, surfaceData);
                surfaceData.ambientOcclusion =      1.0f;
                surfaceData.subsurfaceMask =        1.0f;

                surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;
        #ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
        #endif
        #ifdef _MATERIAL_FEATURE_TRANSMISSION
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
        #endif
        #ifdef _MATERIAL_FEATURE_ANISOTROPY
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
        #endif
        #ifdef _MATERIAL_FEATURE_CLEAR_COAT
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
        #endif
        #ifdef _MATERIAL_FEATURE_IRIDESCENCE
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
        #endif
        #ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
                surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
        #endif
        
                float3 normalTS = float3(0.0f, 0.0f, 1.0f);
                GetNormalWS(fragInputs, V, normalTS, surfaceData.normalWS);
        
                surfaceData.tangentWS = normalize(fragInputs.worldToTangent[0].xyz);
                surfaceData.tangentWS = Orthonormalize(surfaceData.tangentWS, surfaceData.normalWS);
                surfaceData.anisotropy = 0;
                surfaceData.coatMask = 0.0f;
                surfaceData.iridescenceThickness = 0.0;
                surfaceData.iridescenceMask = 1.0;
                surfaceData.ior = 1.0;
                surfaceData.transmittanceColor = float3(1.0, 1.0, 1.0);
                surfaceData.atDistance = 1000000.0;
                surfaceData.transmittanceMask = 0.0;
                surfaceData.specularOcclusion = 1.0;
        #if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
                surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO(V, bentNormalWS, surfaceData);
        #elif defined(_MASKMAP)
                surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion(NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness(surfaceData.perceptualSmoothness));
        #endif
            }
        
            void GetSurfaceAndBuiltinData( AlphaSurfaceDescription surfaceDescription, FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {              
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
                BuildSurfaceData(fragInputs, surfaceDescription, V, surfaceData);
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS = surfaceData.normalWS;
        
                builtinData.opacity = surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting = SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
                builtinData.velocity =                  float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion = float2(0.0, 0.0);
                builtinData.distortionBlur = 0.0;
                builtinData.depthOffset = 0.0;
            }

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;2;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;3;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				return outputPackedVaryingsMeshToPS;
			}

			void Frag ( PackedVaryingsMeshToPS packedInput,
#ifdef WRITE_NORMAL_BUFFER
				OUTPUT_NORMALBUFFER ( outNormalBuffer )
#else
				out float4 outColor : SV_Target
#endif 
			/*ase_frag_input*/ )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );
				float3 V = 0; 

				SurfaceData surfaceData;
				BuiltinData builtinData;

				AlphaSurfaceDescription surfaceDescription = ( AlphaSurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/0/*end*/;

				GetSurfaceAndBuiltinData ( surfaceDescription, input, V, posInput, surfaceData, builtinData );

#ifdef WRITE_NORMAL_BUFFER
				ENCODE_INTO_NORMALBUFFER ( surfaceData, posInput.positionSS, outNormalBuffer );
#elif defined(SCENESELECTIONPASS)
				outColor = float4( _ObjectId, _PassValue, 1.0, 1.0 );
#else
				outColor = float4( 0.0, 0.0, 0.0, 0.0 );
#endif
			}
       
            ENDHLSL
        }

		/*ase_pass*/
		Pass
		{
			/*ase_hide_pass*/
			Name "Motion Vectors"
			Tags{ "LightMode" = "MotionVectors" }

			Stencil
			{
				WriteMask 128
				Ref 128
				Comp Always
				Pass Replace
			}

			HLSLPROGRAM

			#pragma target 4.5
			#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/

			#define UNITY_MATERIAL_LIT

			#if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
			#define OUTPUT_SPLIT_LIGHTING
			#endif

			#include "CoreRP/ShaderLibrary/Common.hlsl"
			#include "CoreRP/ShaderLibrary/Wind.hlsl"

			#include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"

			#include "ShaderGraphLibrary/Functions.hlsl"


			#include "HDRP/ShaderPass/FragInputs.hlsl"
			#include "HDRP/ShaderPass/ShaderPass.cs.hlsl"

			#define SHADERPASS SHADERPASS_VELOCITY

			#define VARYINGS_NEED_POSITION_WS

			#include "ShaderGraphLibrary/Functions.hlsl"
			#include "HDRP/ShaderVariables.hlsl"

			#include "HDRP/Material/Material.hlsl"

			#include "HDRP/Material/MaterialUtilities.hlsl"

			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

			struct AttributesMesh
			{
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
				/*ase_vdata:p=p;n=n*/
			};

			struct VaryingsMeshToPS
			{
				float4 positionCS : SV_Position;
				float3 positionRWS; // optional
			};

			struct PackedVaryingsMeshToPS
			{
				float3 interp00 : TEXCOORD0; // auto-packed
				float4 positionCS : SV_Position; // unpacked
			};

			struct SurfaceDescriptionInputs
			{
				float3 TangentSpaceNormal; // optional
			};

			struct SurfaceDescription
			{
				float Alpha;
				float AlphaClipThreshold;
			};

			void BuildSurfaceData ( FragInputs fragInputs, SurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData )
			{
				ZERO_INITIALIZE ( SurfaceData, surfaceData );
				surfaceData.ambientOcclusion = 1.0f;
				surfaceData.subsurfaceMask = 1.0f;

				surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;
	#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
	#endif
	#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
	#endif
	#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
	#endif
	#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
	#endif
	#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
	#endif
	#ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
	#endif

				float3 normalTS = float3( 0.0f, 0.0f, 1.0f );

				GetNormalWS ( fragInputs, V, normalTS, surfaceData.normalWS );

				surfaceData.tangentWS = normalize ( fragInputs.worldToTangent[ 0 ].xyz );
				surfaceData.tangentWS = Orthonormalize ( surfaceData.tangentWS, surfaceData.normalWS );

				surfaceData.anisotropy = 0;
				surfaceData.coatMask = 0.0f;
				surfaceData.iridescenceThickness = 0.0;
				surfaceData.iridescenceMask = 1.0;
				surfaceData.ior = 1.0;
				surfaceData.transmittanceColor = float3( 1.0, 1.0, 1.0 );
				surfaceData.atDistance = 1000000.0;
				surfaceData.transmittanceMask = 0.0;
				surfaceData.specularOcclusion = 1.0;
	#if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO ( V, bentNormalWS, surfaceData );
	#elif defined(_MASKMAP)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion ( NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness ( surfaceData.perceptualSmoothness ) );
	#endif
			}

			void GetSurfaceAndBuiltinData ( SurfaceDescription surfaceDescription, FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData )
			{

				BuildSurfaceData ( fragInputs, surfaceDescription, V, surfaceData );
				ZERO_INITIALIZE ( BuiltinData, builtinData );
				float3 bentNormalWS = surfaceData.normalWS;

				builtinData.opacity = surfaceDescription.Alpha;
				builtinData.bakeDiffuseLighting = SampleBakedGI ( fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2 );

				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( posInput.positionSS.xy, surfaceData );
				if ( HasFlag ( bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION ) )
				{
					builtinData.bakeDiffuseLighting += SampleBakedGI ( fragInputs.positionRWS, -fragInputs.worldToTangent[ 2 ], fragInputs.texCoord1, fragInputs.texCoord2 ) * bsdfData.transmittance;
				}

				builtinData.velocity = float2( 0.0, 0.0 );
	#ifdef SHADOWS_SHADOWMASK
				float4 shadowMask = SampleShadowMask ( fragInputs.positionRWS, fragInputs.texCoord1 );
				builtinData.shadowMask0 = shadowMask.x;
				builtinData.shadowMask1 = shadowMask.y;
				builtinData.shadowMask2 = shadowMask.z;
				builtinData.shadowMask3 = shadowMask.w;
	#else
				builtinData.shadowMask0 = 0.0;
				builtinData.shadowMask1 = 0.0;
				builtinData.shadowMask2 = 0.0;
				builtinData.shadowMask3 = 0.0;
	#endif
				builtinData.distortion = float2( 0.0, 0.0 );
				builtinData.distortionBlur = 0.0;
				builtinData.depthOffset = 0.0;
			}

			struct AttributesPass
			{
				float3 previousPositionOS : TEXCOORD4; // Contain previous transform position (in case of skinning for example)
			};

			struct VaryingsPassToPS
			{
				float4 positionCS;
				float4 previousPositionCS;
			};

			struct VaryingsToPS
			{
				VaryingsMeshToPS vmesh;
				VaryingsPassToPS vpass;
			};

			struct PackedVaryingsToPS
			{
				float4 vmeshPositionCS : SV_Position; // unpacked
				float3 vmeshInterp00 : TEXCOORD0; // auto-packed
				float3 vpassInterpolators0 : TEXCOORD1;
				float3 vpassInterpolators1 : TEXCOORD2;
				/*ase_interp(3,):sp=sp.xyzw*/
			};

			// Transforms local position to camera relative world space
			float3 TransformPreviousObjectToWorld ( float3 positionOS )
			{
				float4x4 previousModelMatrix = ApplyCameraTranslationToMatrix ( unity_MatrixPreviousM );
				return mul ( previousModelMatrix, float4( positionOS, 1.0 ) ).xyz;
			}

			void VelocityPositionZBias ( VaryingsToPS input )
			{
	#if defined(UNITY_REVERSED_Z)
				input.vmesh.positionCS.z -= unity_MotionVectorsParams.z * input.vmesh.positionCS.w;
	#else
				input.vmesh.positionCS.z += unity_MotionVectorsParams.z * input.vmesh.positionCS.w;
	#endif
			}

			PackedVaryingsToPS Vert ( AttributesMesh inputMesh, AttributesPass inputPass /*ase_vert_input*/ )
			{
				VaryingsToPS varyingsType;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, varyingsType.vmesh );

				PackedVaryingsToPS outputPackedVaryingsToPS;
				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsToPS=PackedVaryingsToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;2;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;3;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;
				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS );

				varyingsType.vmesh.positionRWS = positionRWS;
				varyingsType.vmesh.positionCS = TransformWorldToHClip ( positionRWS );

				VelocityPositionZBias ( varyingsType );

				varyingsType.vpass.positionCS = mul ( _NonJitteredViewProjMatrix, float4( varyingsType.vmesh.positionRWS, 1.0 ) );

				bool forceNoMotion = unity_MotionVectorsParams.y == 0.0;
				if ( forceNoMotion )
				{
					varyingsType.vpass.previousPositionCS = float4( 0.0, 0.0, 0.0, 1.0 );
				}
				else
				{
					bool hasDeformation = unity_MotionVectorsParams.x > 0.0; // Skin or morph target
					float3 previousPositionRWS = TransformPreviousObjectToWorld ( hasDeformation ? inputPass.previousPositionOS : inputMesh.positionOS );
					varyingsType.vpass.previousPositionCS = mul ( _PrevViewProjMatrix, float4( previousPositionRWS, 1.0 ) );
				}


				outputPackedVaryingsToPS.vmeshPositionCS = varyingsType.vmesh.positionCS;
				outputPackedVaryingsToPS.vmeshInterp00.xyz = varyingsType.vmesh.positionRWS;

				outputPackedVaryingsToPS.vpassInterpolators0 = float3( varyingsType.vpass.positionCS.xyw );
				outputPackedVaryingsToPS.vpassInterpolators1 = float3( varyingsType.vpass.previousPositionCS.xyw );

				return outputPackedVaryingsToPS;
			}

			void Frag ( PackedVaryingsToPS packedInput, out float4 outVelocity : SV_Target0 /*ase_frag_input*/ )
			{

				VaryingsMeshToPS unpacked;
				unpacked.positionCS = packedInput.vmeshPositionCS;
				unpacked.positionRWS = packedInput.vmeshInterp00.xyz;

				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );

				input.worldToTangent = k_identity3x3;
				input.positionSS = unpacked.positionCS;
				input.positionRWS = unpacked.positionRWS;

				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );

				float3 V = GetWorldSpaceNormalizeViewDir ( input.positionRWS );

				SurfaceDescription surfaceDescription = ( SurfaceDescription ) 0;
				/*ase_frag_code:packedInput=PackedVaryingsToPS*/
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;0;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;1;-1;_AlphaClip*/0/*end*/;

				SurfaceData surfaceData;
				BuiltinData builtinData;
				GetSurfaceAndBuiltinData ( surfaceDescription,input, V, posInput, surfaceData, builtinData );

				VaryingsPassToPS inputPass;
				inputPass.positionCS = float4( packedInput.vpassInterpolators0.xy, 0.0, packedInput.vpassInterpolators0.z );
				inputPass.previousPositionCS = float4( packedInput.vpassInterpolators1.xy, 0.0, packedInput.vpassInterpolators1.z );

				float2 velocity = CalculateVelocity ( inputPass.positionCS, inputPass.previousPositionCS );
				EncodeVelocity ( velocity * 0.5, outVelocity );
				bool forceNoMotion = unity_MotionVectorsParams.y == 0.0;
				if ( forceNoMotion )
					outVelocity = float4( 0.0, 0.0, 0.0, 0.0 );

			}
			ENDHLSL
		}

		/*ase_pass*/
        Pass
        {
			/*ase_hide_pass:SyncP*/
			Name "Forward"
			Tags { "LightMode" = "Forward" }
			Stencil
			{
			   WriteMask 7
			   Ref  2
			   Comp Always
			   Pass Replace
			}
        
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			/*ase_pragma*/

            #define UNITY_MATERIAL_LIT

            #if defined(_MATID_SSS) && !defined(_SURFACE_TYPE_TRANSPARENT)
            #define OUTPUT_SPLIT_LIGHTING
            #endif
        
            #include "CoreRP/ShaderLibrary/Common.hlsl"
            #include "CoreRP/ShaderLibrary/Wind.hlsl"
        
            #include "CoreRP/ShaderLibrary/NormalSurfaceGradient.hlsl"
        
            #include "ShaderGraphLibrary/Functions.hlsl"
        
            #include "HDRP/ShaderPass/FragInputs.hlsl"
            #include "HDRP/ShaderPass/ShaderPass.cs.hlsl"
                   
            #define SHADERPASS SHADERPASS_FORWARD
            #pragma multi_compile _ DEBUG_DISPLAY
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile LIGHTLOOP_SINGLE_PASS LIGHTLOOP_TILE_PASS
            #pragma multi_compile USE_FPTL_LIGHTLIST USE_CLUSTERED_LIGHTLIST
            #define ATTRIBUTES_NEED_NORMAL
            #define ATTRIBUTES_NEED_TANGENT
            #define VARYINGS_NEED_TANGENT_TO_WORLD
                
        
            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            
            #include "HDRP/Lighting/Lighting.hlsl"

            #include "HDRP/Material/MaterialUtilities.hlsl"
        
			CBUFFER_START(UnityPerMaterial)
			/*ase_globals*/
			CBUFFER_END
			/*ase_funcs*/

            float3x3 BuildWorldToTangent(float4 tangentWS, float3 normalWS)
            {
        	    float3 unnormalizedNormalWS = normalWS;
                float renormFactor = 1.0 / length(unnormalizedNormalWS);
                float3x3 worldToTangent = CreateWorldToTangent(unnormalizedNormalWS, tangentWS.xyz, tangentWS.w > 0.0 ? 1.0 : -1.0);
                worldToTangent[0] = worldToTangent[0] * renormFactor;
                worldToTangent[1] = worldToTangent[1] * renormFactor;
                worldToTangent[2] = worldToTangent[2] * renormFactor;
                return worldToTangent;
            }
        
            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
				/*ase_vdata:p=p;n=n;t=t*/
            };
            
            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
                float3 interp00 : TEXCOORD0;
                float4 interp01 : TEXCOORD1;
				/*ase_interp(2,):sp=sp.xyzw;wn=tc0;wt=tc1*/
            };
        
			void BuildSurfaceData ( FragInputs fragInputs, GlobalSurfaceDescription surfaceDescription, float3 V, out SurfaceData surfaceData )
			{
				ZERO_INITIALIZE ( SurfaceData, surfaceData );

				float3 normalTS = float3( 0.0f, 0.0f, 1.0f );
				normalTS = surfaceDescription.Normal;
				GetNormalWS ( fragInputs, V, normalTS, surfaceData.normalWS );

				surfaceData.ambientOcclusion = 1.0f;

				surfaceData.baseColor = surfaceDescription.Albedo;
				surfaceData.perceptualSmoothness = surfaceDescription.Smoothness;
				surfaceData.ambientOcclusion = surfaceDescription.Occlusion;

				surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;

#ifdef _MATERIAL_FEATURE_SPECULAR_COLOR
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SPECULAR_COLOR;
				surfaceData.specularColor = surfaceDescription.Specular;
#else
				surfaceData.metallic = surfaceDescription.Metallic;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceData.diffusionProfile = surfaceDescription.DiffusionProfile;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_SUBSURFACE_SCATTERING;
				surfaceData.subsurfaceMask = surfaceDescription.SubsurfaceMask;
#else
				surfaceData.subsurfaceMask = 1.0f;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_TRANSMISSION;
				surfaceData.thickness = surfaceDescription.Thickness;
#endif

				surfaceData.tangentWS = normalize ( fragInputs.worldToTangent[ 0 ].xyz );
				surfaceData.tangentWS = Orthonormalize ( surfaceData.tangentWS, surfaceData.normalWS );

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_ANISOTROPY;
				surfaceData.anisotropy = surfaceDescription.Anisotropy;

#else
				surfaceData.anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_CLEAR_COAT;
				surfaceData.coatMask = surfaceDescription.CoatMask;
#else
				surfaceData.coatMask = 0.0f;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceData.materialFeatures |= MATERIALFEATUREFLAGS_LIT_IRIDESCENCE;
				surfaceData.iridescenceThickness = surfaceDescription.IridescenceThickness;
				surfaceData.iridescenceMask = surfaceDescription.IridescenceMask;
#else
				surfaceData.iridescenceThickness = 0.0;
				surfaceData.iridescenceMask = 1.0;
#endif

				//ASE CUSTOM TAG
#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceData.ior = surfaceDescription.IndexOfRefraction;
				surfaceData.transmittanceColor = surfaceDescription.TransmittanceColor;
				surfaceData.atDistance = surfaceDescription.TransmittanceAbsorptionDistance;
				surfaceData.transmittanceMask = surfaceDescription.TransmittanceMask;
#else
				surfaceData.ior = 1.0;
				surfaceData.transmittanceColor = float3( 1.0, 1.0, 1.0 );
				surfaceData.atDistance = 1000000.0;
				surfaceData.transmittanceMask = 0.0;
#endif

				surfaceData.specularOcclusion = 1.0;

#if defined(_BENTNORMALMAP) && defined(_ENABLESPECULAROCCLUSION)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromBentAO ( V, bentNormalWS, surfaceData );
#elif defined(_MASKMAP)
				surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion ( NdotV, surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness ( surfaceData.perceptualSmoothness ) );
#endif
			}

            void GetSurfaceAndBuiltinData( GlobalSurfaceDescription surfaceDescription, FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
            {
                
#if _ALPHATEST_ON
				DoAlphaTest ( surfaceDescription.Alpha, surfaceDescription.AlphaClipThreshold );
#endif
				BuildSurfaceData(fragInputs, surfaceDescription, V, surfaceData);
                ZERO_INITIALIZE(BuiltinData, builtinData);
                float3 bentNormalWS = surfaceData.normalWS;
        
                builtinData.opacity =                   surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting =       SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);    // see GetBuiltinData()
        
                BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS.xy, surfaceData);
                if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_TRANSMISSION))
                {
                    builtinData.bakeDiffuseLighting += SampleBakedGI(fragInputs.positionRWS, -fragInputs.worldToTangent[2], fragInputs.texCoord1, fragInputs.texCoord2) * bsdfData.transmittance;
                }
        
                builtinData.emissiveColor = surfaceDescription.Emission;
                builtinData.velocity = float2(0.0, 0.0);
        #ifdef SHADOWS_SHADOWMASK
                float4 shadowMask = SampleShadowMask(fragInputs.positionRWS, fragInputs.texCoord1);
                builtinData.shadowMask0 = shadowMask.x;
                builtinData.shadowMask1 = shadowMask.y;
                builtinData.shadowMask2 = shadowMask.z;
                builtinData.shadowMask3 = shadowMask.w;
        #else
                builtinData.shadowMask0 = 0.0;
                builtinData.shadowMask1 = 0.0;
                builtinData.shadowMask2 = 0.0;
                builtinData.shadowMask3 = 0.0;
        #endif
                builtinData.distortion = float2(0.0, 0.0);
                builtinData.distortionBlur = 0.0;
                builtinData.depthOffset = 0.0;
            }

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh /*ase_vert_input*/ )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				/*ase_vert_code:inputMesh=AttributesMesh;outputPackedVaryingsMeshToPS=PackedVaryingsMeshToPS*/
				inputMesh.positionOS.xyz += /*ase_vert_out:Vertex Offset;Float3;9;-1;_VertexOffset*/ float3( 0, 0, 0 ) /*end*/;
				inputMesh.normalOS = /*ase_vert_out:Vertex Normal;Float3;10;-1;_VertexNormal*/ inputMesh.normalOS /*end*/;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float3 normalWS = TransformObjectToWorldNormal ( inputMesh.normalOS );
				float4 tangentWS = float4( TransformObjectToWorldDir ( inputMesh.tangentOS.xyz ), inputMesh.tangentOS.w );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				outputPackedVaryingsMeshToPS.interp00.xyz = normalWS;
				outputPackedVaryingsMeshToPS.interp01.xyzw = tangentWS;
				
				return outputPackedVaryingsMeshToPS;
			}

			void Frag ( PackedVaryingsMeshToPS packedInput,
#ifdef OUTPUT_SPLIT_LIGHTING
				out float4 outColor : SV_Target0, 
				out float4 outDiffuseLighting : SV_Target1,
				OUTPUT_SSSBUFFER ( outSSSBuffer )
#else
				out float4 outColor : SV_Target0
#endif
				/*ase_frag_input*/
			)
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				/*ase_local_var:wn*/float3 normalWS = packedInput.interp00.xyz;
				/*ase_local_var:wt*/float4 tangentWS = packedInput.interp01.xyzw;
				input.positionSS = packedInput.positionCS;
				input.worldToTangent = BuildWorldToTangent ( tangentWS, normalWS );
				

				// input.positionSS is SV_Position
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS.xyz, uint2( input.positionSS.xy ) / GetTileSize () );

				float3 V = 0; 

				SurfaceData surfaceData;
				BuiltinData builtinData;
				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				
				/*ase_frag_code:packedInput=PackedVaryingsMeshToPS*/
				surfaceDescription.Albedo = /*ase_frag_out:Albedo;Float3;0;-1;_Albedo*/float3( 0.5, 0.5, 0.5 )/*end*/;
				surfaceDescription.Normal = /*ase_frag_out:Normal;Float3;1;-1;_Normal*/float3( 0, 0, 1 )/*end*/;
				surfaceDescription.Emission = /*ase_frag_out:Emission;Float3;2;-1;_Emission*/0/*end*/;
				surfaceDescription.Specular = /*ase_frag_out:Specular;Float3;3;-1;_Specular*/0/*end*/;
				surfaceDescription.Metallic = /*ase_frag_out:Metallic;Float;4;-1;_Metallic*/0/*end*/;
				surfaceDescription.Smoothness = /*ase_frag_out:Smoothness;Float;5;-1;_Smoothness*/0.5/*end*/;
				surfaceDescription.Occlusion = /*ase_frag_out:Occlusion;Float;6;-1;_Occlusion*/1/*end*/;
				surfaceDescription.Alpha = /*ase_frag_out:Alpha;Float;7;-1;_Alpha*/1/*end*/;
				surfaceDescription.AlphaClipThreshold = /*ase_frag_out:Alpha Clip Threshold;Float;8;-1;_AlphaClip*/0/*end*/;
				
#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = /*ase_frag_out:Coat Mask;Float;11;-1;_CoatMask*/0/*end*/;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = /*ase_frag_out:Diffusion Profile;Int;12;-1;_DiffusionProfile*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = /*ase_frag_out:Subsurface Mask;Float;13;-1;_SubsurfaceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = /*ase_frag_out:Thickness;Float;14;-1;_Thickness*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = /*ase_frag_out:Anisotropy;Float;15;-1;_Anisotropy*/0/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = /*ase_frag_out:Iridescence Thickness;Float;16;-1;_IridescenceThickness*/0/*end*/;
				surfaceDescription.IridescenceMask = /*ase_frag_out:Iridescence Mask;Float;17;-1;_IridescenceMask*/1/*end*/;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = /*ase_frag_out:IndexOfRefraction;Float;18;-1;_IndexOfRefraction*/1/*end*/;
				surfaceDescription.TransmittanceColor = /*ase_frag_out:Transmittance Color;Float3;19;-1;_TransmittanceColor*/float3( 1, 1, 1 )/*end*/;
				surfaceDescription.TransmittanceAbsorptionDistance = /*ase_frag_out:Transmittance Absorption Distance;Float;20;-1;_TransmittanceAbsorptionDistance*/1000000/*end*/;
				surfaceDescription.TransmittanceMask = /*ase_frag_out:TransmittanceMask;Float;21;-1;_TransmittanceMask*/0/*end*/;
#endif

				GetSurfaceAndBuiltinData ( surfaceDescription, input, V, posInput, surfaceData, builtinData );

				BSDFData bsdfData = ConvertSurfaceDataToBSDFData ( input.positionSS.xy, surfaceData );

				PreLightData preLightData = GetPreLightData ( V, posInput, bsdfData );

				outColor = float4( 0.0, 0.0, 0.0, 0.0 );

#ifdef _SURFACE_TYPE_TRANSPARENT
				uint featureFlags = LIGHT_FEATURE_MASK_FLAGS_TRANSPARENT;
#else
				uint featureFlags = LIGHT_FEATURE_MASK_FLAGS_OPAQUE;
#endif
				float3 diffuseLighting;
				float3 specularLighting;
				BakeLightingData bakeLightingData;
				bakeLightingData.bakeDiffuseLighting = GetBakedDiffuseLighting ( surfaceData, builtinData, bsdfData, preLightData );
#ifdef SHADOWS_SHADOWMASK
				bakeLightingData.bakeShadowMask = float4( builtinData.shadowMask0, builtinData.shadowMask1, builtinData.shadowMask2, builtinData.shadowMask3 );
#endif
				LightLoop ( V, posInput, preLightData, bsdfData, bakeLightingData, featureFlags, diffuseLighting, specularLighting );

#ifdef OUTPUT_SPLIT_LIGHTING
				if ( _EnableSubsurfaceScattering != 0 && ShouldOutputSplitLighting ( bsdfData ) )
				{
					outColor = float4( specularLighting, 1.0 );
					outDiffuseLighting = float4( TagLightingForSSS ( diffuseLighting ), 1.0 );
				}
				else
				{
					outColor = float4( diffuseLighting + specularLighting, 1.0 );
					outDiffuseLighting = 0;
				}
				ENCODE_INTO_SSSBUFFER ( surfaceData, posInput.positionSS, outSSSBuffer );
#else
				outColor = ApplyBlendMode ( diffuseLighting, specularLighting, builtinData.opacity );
				outColor = EvaluateAtmosphericScattering ( posInput, outColor );
#endif

			}
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
	CustomEditor "ASEMaterialInspector"
}
