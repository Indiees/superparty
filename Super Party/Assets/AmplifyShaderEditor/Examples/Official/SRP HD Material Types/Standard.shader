// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "ASESampleShaders/SRP HD Material Types/Standard"
{
    Properties
    {
		_BaseColor("Base Color", 2D) = "white" {}
		_MixAlbedo("Mix Albedo", 2D) = "white" {}
		_Normal("Normal", 2D) = "bump" {}
		_Metallic("Metallic", 2D) = "white" {}
		_Sand_roughness("Sand_roughness", 2D) = "white" {}
		_RoughnessScale("Roughness Scale", Float) = 0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline"="HDRenderPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        
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
		
        Pass
        {
			
            Name "GBuffer"
            Tags { "LightMode"="GBuffer" }    
			Stencil
			{
				Ref 2
				WriteMask 7
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Keep
			}

     
            HLSLPROGRAM
        	
			#pragma vertex Vert
			#pragma fragment Frag

			#define _NORMALMAP 1

		
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
		
			uniform sampler2D _BaseColor;
			uniform float4 _BaseColor_ST;
			uniform sampler2D _MixAlbedo;
			uniform sampler2D _Normal;
			uniform sampler2D _Metallic;
			uniform float _RoughnessScale;
			uniform sampler2D _Sand_roughness;

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
				float4 ase_texcoord : TEXCOORD0;
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
                float3 interp00 : TEXCOORD0;
                float3 interp01 : TEXCOORD1;
                float4 interp02 : TEXCOORD2;
                float4 interp03 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
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
        
			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				outputPackedVaryingsMeshToPS.ase_texcoord4.xy = inputMesh.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				outputPackedVaryingsMeshToPS.ase_texcoord4.zw = 0;
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

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

			void Frag ( PackedVaryingsMeshToPS packedInput, OUTPUT_GBUFFER ( outGBuffer ) OUTPUT_GBUFFER_SHADOWMASK ( outShadowMaskBuffer )  )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				
				float3 positionRWS = packedInput.interp00.xyz;
				float3 normalWS = packedInput.interp01.xyz;
				float4 tangentWS = packedInput.interp02.xyzw;
				float2 uv1 = packedInput.interp03.xy;
				float2 uv2 = packedInput.interp03.zw;

				input.positionSS = packedInput.positionCS;
				input.positionRWS = positionRWS;
				input.worldToTangent = BuildWorldToTangent ( tangentWS, normalWS );
				input.texCoord1 = uv1;
				input.texCoord2 = uv2;

				// input.positionSS is SV_Position
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );

				float3 normalizedWorldViewDir = GetWorldSpaceNormalizeViewDir ( input.positionRWS );

				SurfaceData surfaceData;
				BuiltinData builtinData;

				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				float2 uv_BaseColor = packedInput.ase_texcoord4.xy * _BaseColor_ST.xy + _BaseColor_ST.zw;
				float2 uv16 = packedInput.ase_texcoord4.xy * float2( 2,2 ) + float2( 0,0 );
				
				surfaceDescription.Albedo = ( tex2D( _BaseColor, uv_BaseColor ) * tex2D( _MixAlbedo, uv16 ) ).rgb;
				surfaceDescription.Normal = UnpackNormalmapRGorAG( tex2D( _Normal, uv16 ), 1.0f );
				surfaceDescription.Emission = 0;
				surfaceDescription.Specular = 0;
				surfaceDescription.Metallic = tex2D( _Metallic, uv16 ).r;
				surfaceDescription.Smoothness = ( 1.0 - ( _RoughnessScale * tex2D( _Sand_roughness, uv16 ).r ) );
				surfaceDescription.Occlusion = 1;
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = 0;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = 0;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = 0;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = 0;
				surfaceDescription.IridescenceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = 1;
				surfaceDescription.TransmittanceColor = float3( 1, 1, 1 );
				surfaceDescription.TransmittanceAbsorptionDistance = 1000000;
				surfaceDescription.TransmittanceMask = 0;
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
        
		
        Pass
        {
			
            Name "GBufferWithPrepass"
            Tags { "LightMode"="GBufferWithPrepass" }
			Stencil
			{
				Ref 2
				WriteMask 7
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Keep
			}

     
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			#define _NORMALMAP 1

		
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
		
			uniform sampler2D _BaseColor;
			uniform float4 _BaseColor_ST;
			uniform sampler2D _MixAlbedo;
			uniform sampler2D _Normal;
			uniform sampler2D _Metallic;
			uniform float _RoughnessScale;
			uniform sampler2D _Sand_roughness;
	        struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 ase_texcoord : TEXCOORD0;
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				float4 ase_texcoord : TEXCOORD0;
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
        
			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				outputPackedVaryingsMeshToPS.ase_texcoord.xy = inputMesh.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				outputPackedVaryingsMeshToPS.ase_texcoord.zw = 0;
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
				float4 positionCS = TransformWorldToHClip ( positionRWS );

				outputPackedVaryingsMeshToPS.positionCS = positionCS;
				return outputPackedVaryingsMeshToPS;
			}

			void Frag ( PackedVaryingsMeshToPS packedInput, OUTPUT_GBUFFER ( outGBuffer ) OUTPUT_GBUFFER_SHADOWMASK ( outShadowMaskBuffer )  )
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
				float2 uv_BaseColor = packedInput.ase_texcoord.xy * _BaseColor_ST.xy + _BaseColor_ST.zw;
				float2 uv16 = packedInput.ase_texcoord.xy * float2( 2,2 ) + float2( 0,0 );
				
				surfaceDescription.Albedo = ( tex2D( _BaseColor, uv_BaseColor ) * tex2D( _MixAlbedo, uv16 ) ).rgb;
				surfaceDescription.Normal = UnpackNormalmapRGorAG( tex2D( _Normal, uv16 ), 1.0f );
				surfaceDescription.Emission = 0;
				surfaceDescription.Specular = 0;
				surfaceDescription.Metallic = tex2D( _Metallic, uv16 ).r;
				surfaceDescription.Smoothness = ( 1.0 - ( _RoughnessScale * tex2D( _Sand_roughness, uv16 ).r ) );
				surfaceDescription.Occlusion = 1;
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = 0;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = 0;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = 0;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = 0;
				surfaceDescription.IridescenceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = 1;
				surfaceDescription.TransmittanceColor = float3( 1, 1, 1 );
				surfaceDescription.TransmittanceAbsorptionDistance = 1000000;
				surfaceDescription.TransmittanceMask = 0;
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

		
        Pass
        {
			
            Name "META"
            Tags { "LightMode"="Meta" }
            Cull Off
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			#define _NORMALMAP 1


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
        
			uniform sampler2D _BaseColor;
			uniform float4 _BaseColor_ST;
			uniform sampler2D _MixAlbedo;
			uniform sampler2D _Normal;
			uniform sampler2D _Metallic;
			uniform float _RoughnessScale;
			uniform sampler2D _Sand_roughness;

            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float4 color : COLOR;
				
            };

            struct PackedVaryingsMeshToPS
			{
                float4 positionCS : SV_Position;
				float4 ase_texcoord : TEXCOORD0;
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

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				outputPackedVaryingsMeshToPS.ase_texcoord.xy = inputMesh.uv0;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				outputPackedVaryingsMeshToPS.ase_texcoord.zw = 0;
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

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

			float4 Frag ( PackedVaryingsMeshToPS packedInput  ) : SV_Target
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
				float2 uv_BaseColor = packedInput.ase_texcoord.xy * _BaseColor_ST.xy + _BaseColor_ST.zw;
				float2 uv16 = packedInput.ase_texcoord.xy * float2( 2,2 ) + float2( 0,0 );
				
				surfaceDescription.Albedo = ( tex2D( _BaseColor, uv_BaseColor ) * tex2D( _MixAlbedo, uv16 ) ).rgb;
				surfaceDescription.Normal = UnpackNormalmapRGorAG( tex2D( _Normal, uv16 ), 1.0f );
				surfaceDescription.Emission = 0;
				surfaceDescription.Specular = 0;
				surfaceDescription.Metallic = tex2D( _Metallic, uv16 ).r;
				surfaceDescription.Smoothness = ( 1.0 - ( _RoughnessScale * tex2D( _Sand_roughness, uv16 ).r ) );
				surfaceDescription.Occlusion = 1;
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = 0;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = 0;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = 0;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = 0;
				surfaceDescription.IridescenceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = 1;
				surfaceDescription.TransmittanceColor = float3( 1, 1, 1 );
				surfaceDescription.TransmittanceAbsorptionDistance = 1000000;
				surfaceDescription.TransmittanceMask = 0;
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

		
        Pass
        {
			
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ColorMask 0
        
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			

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
        
			
            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				
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

			PackedVaryingsMeshToPS Vert( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

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
			 )
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
				
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

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
		
		
        Pass
        {
			
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ColorMask 0
        
            HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

			

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

			
            struct AttributesMesh 
			{
                float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
            };

            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
				
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

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

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
			 )
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
				
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

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

				
        Pass
        {
			
            Name "Motion Vectors"
            Tags { "LightMode"="MotionVectors" }
			Stencil
			{
				Ref 128
				WriteMask 128
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Keep
			}

        
            HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag

			

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
			#define VARYINGS_NEED_PASS

            #include "ShaderGraphLibrary/Functions.hlsl"
            #include "HDRP/ShaderVariables.hlsl"
            #include "HDRP/Material/Material.hlsl"
            #include "HDRP/Material/MaterialUtilities.hlsl"

			
            struct AttributesMesh 
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				
            };

            struct VaryingsMeshToPS
			{
                float4 positionCS : SV_Position;
                float3 positionRWS;
            };

			struct AttributesPass
			{
				float3 previousPositionOS : TEXCOORD3;
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
				float4 positionCS : SV_Position;
				float3 interp00 : TEXCOORD0;
				float3 interpolators0 : TEXCOORD1;
				float3 interpolators1 : TEXCOORD2;
				
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
                surfaceData.tangentWS = normalize(fragInputs.worldToTangent[0].xyz);    // The tangent is not normalize in worldToTangent for mikkt. TODO: Check if it expected that we normalize with Morten. Tag: SURFACE_GRADIENT
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
                float3 bentNormalWS =                   surfaceData.normalWS;
        
                builtinData.opacity =                   surfaceDescription.Alpha;
                builtinData.bakeDiffuseLighting =       SampleBakedGI(fragInputs.positionRWS, bentNormalWS, fragInputs.texCoord1, fragInputs.texCoord2);    // see GetBuiltinData()
        
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
        
			float3 TransformPreviousObjectToWorldNormal ( float3 normalOS )
			{
#ifdef UNITY_ASSUME_UNIFORM_SCALING
				return normalize ( mul ( ( float3x3 )unity_MatrixPreviousM, normalOS ) );
#else

				return normalize ( mul ( normalOS, ( float3x3 )unity_MatrixPreviousMI ) );
#endif
			}

			float3 TransformPreviousObjectToWorld ( float3 positionOS )
			{
				float4x4 previousModelMatrix = ApplyCameraTranslationToMatrix ( unity_MatrixPreviousM );
				return mul ( previousModelMatrix, float4( positionOS, 1.0 ) ).xyz;
			}

			PackedVaryingsToPS Vert ( AttributesMesh inputMesh, AttributesPass inputPass  )
			{
				VaryingsToPS varyingsType;
				VaryingsMeshToPS outputVaryingsMeshToPS;
				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsToPS );
				PackedVaryingsToPS outputPackedVaryingsToPS;

				
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

				float3 positionRWS = TransformObjectToWorld ( inputMesh.positionOS.xyz );
		
				outputVaryingsMeshToPS.positionRWS = positionRWS;
				outputVaryingsMeshToPS.positionCS = TransformWorldToHClip ( positionRWS );
				varyingsType.vmesh = outputVaryingsMeshToPS;

#if defined(UNITY_REVERSED_Z)
				varyingsType.vmesh.positionCS.z -= unity_MotionVectorsParams.z * varyingsType.vmesh.positionCS.w;
#else
				varyingsType.vmesh.positionCS.z += unity_MotionVectorsParams.z * varyingsType.vmesh.positionCS.w;
#endif
				varyingsType.vpass.positionCS = mul ( _NonJitteredViewProjMatrix, float4( varyingsType.vmesh.positionRWS, 1.0 ) );

				
				bool forceNoMotion = unity_MotionVectorsParams.y == 0.0;
				if ( forceNoMotion )
				{
					varyingsType.vpass.previousPositionCS = float4( 0.0, 0.0, 0.0, 1.0 );
				}
				else
				{
					bool hasDeformation = unity_MotionVectorsParams.x > 0.0; // Skin or morph target
					float3 previousPositionRWS = TransformPreviousObjectToWorld ( hasDeformation ? inputPass.previousPositionOS : inputMesh.positionOS.xyz );
					float3 normalWS = float3( 0.0, 0.0, 0.0 );
					varyingsType.vpass.previousPositionCS = mul ( _PrevViewProjMatrix, float4( previousPositionRWS, 1.0 ) );
				}

				outputPackedVaryingsToPS.positionCS = varyingsType.vmesh.positionCS;
				outputPackedVaryingsToPS.interp00.xyz = varyingsType.vmesh.positionRWS;

				outputPackedVaryingsToPS.interpolators0 = float3( varyingsType.vpass.positionCS.xyw );
				outputPackedVaryingsToPS.interpolators1 = float3( varyingsType.vpass.previousPositionCS.xyw );
			
				return outputPackedVaryingsToPS;
			}

			void Frag ( PackedVaryingsToPS packedInput, out float4 outColor : SV_Target0  )
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				input.positionSS = packedInput.positionCS;
				input.positionRWS = packedInput.interp00.xyz;

				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS );
				float3 V = GetWorldSpaceNormalizeViewDir ( input.positionRWS );

				SurfaceData surfaceData;
				BuiltinData builtinData;
				AlphaSurfaceDescription surfaceDescription = ( AlphaSurfaceDescription ) 0;
				
				
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;

				GetSurfaceAndBuiltinData ( surfaceDescription, input, V, posInput, surfaceData, builtinData );

				float4 positionCS = float4( packedInput.interpolators0.xy, 0.0, packedInput.interpolators0.z );
				float4 previousPositionCS = float4( packedInput.interpolators1.xy, 0.0, packedInput.interpolators1.z );

				float2 velocity = CalculateVelocity ( positionCS, previousPositionCS );
				EncodeVelocity ( velocity * 0.5, outColor );
				bool forceNoMotion = unity_MotionVectorsParams.y == 0.0;
				if ( forceNoMotion )
					outColor = float4( 0.0, 0.0, 0.0, 0.0 );

			}

            ENDHLSL
        }

		
        Pass
        {
			
			Name "Forward"
			Tags { "LightMode"="Forward" }
			Stencil
			{
				Ref 2
				WriteMask 7
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Keep
			}

        
            HLSLPROGRAM

			#pragma vertex Vert
			#pragma fragment Frag

			#define _NORMALMAP 1


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
        
			uniform sampler2D _BaseColor;
			uniform float4 _BaseColor_ST;
			uniform sampler2D _MixAlbedo;
			uniform sampler2D _Normal;
			uniform sampler2D _Metallic;
			uniform float _RoughnessScale;
			uniform sampler2D _Sand_roughness;

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
				float4 ase_texcoord : TEXCOORD0;
            };
            
            struct PackedVaryingsMeshToPS 
			{
                float4 positionCS : SV_Position;
                float3 interp00 : TEXCOORD0;
                float4 interp01 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
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

			PackedVaryingsMeshToPS Vert ( AttributesMesh inputMesh  )
			{
				PackedVaryingsMeshToPS outputPackedVaryingsMeshToPS;

				UNITY_SETUP_INSTANCE_ID ( inputMesh );
				UNITY_TRANSFER_INSTANCE_ID ( inputMesh, outputPackedVaryingsMeshToPS );

				outputPackedVaryingsMeshToPS.ase_texcoord2.xy = inputMesh.ase_texcoord.xy;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				outputPackedVaryingsMeshToPS.ase_texcoord2.zw = 0;
				inputMesh.positionOS.xyz +=  float3( 0, 0, 0 ) ;
				inputMesh.normalOS =  inputMesh.normalOS ;

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
				
			)
			{
				FragInputs input;
				ZERO_INITIALIZE ( FragInputs, input );
				input.worldToTangent = k_identity3x3;
				float3 normalWS = packedInput.interp00.xyz;
				float4 tangentWS = packedInput.interp01.xyzw;
				input.positionSS = packedInput.positionCS;
				input.worldToTangent = BuildWorldToTangent ( tangentWS, normalWS );
				

				// input.positionSS is SV_Position
				PositionInputs posInput = GetPositionInput ( input.positionSS.xy, _ScreenSize.zw, input.positionSS.z, input.positionSS.w, input.positionRWS.xyz, uint2( input.positionSS.xy ) / GetTileSize () );

				float3 V = 0; 

				SurfaceData surfaceData;
				BuiltinData builtinData;
				GlobalSurfaceDescription surfaceDescription = ( GlobalSurfaceDescription ) 0;
				
				float2 uv_BaseColor = packedInput.ase_texcoord2.xy * _BaseColor_ST.xy + _BaseColor_ST.zw;
				float2 uv16 = packedInput.ase_texcoord2.xy * float2( 2,2 ) + float2( 0,0 );
				
				surfaceDescription.Albedo = ( tex2D( _BaseColor, uv_BaseColor ) * tex2D( _MixAlbedo, uv16 ) ).rgb;
				surfaceDescription.Normal = UnpackNormalmapRGorAG( tex2D( _Normal, uv16 ), 1.0f );
				surfaceDescription.Emission = 0;
				surfaceDescription.Specular = 0;
				surfaceDescription.Metallic = tex2D( _Metallic, uv16 ).r;
				surfaceDescription.Smoothness = ( 1.0 - ( _RoughnessScale * tex2D( _Sand_roughness, uv16 ).r ) );
				surfaceDescription.Occlusion = 1;
				surfaceDescription.Alpha = 1;
				surfaceDescription.AlphaClipThreshold = 0;
				
#ifdef _MATERIAL_FEATURE_CLEAR_COAT
				surfaceDescription.CoatMask = 0;
#endif

#if defined(_MATERIAL_FEATURE_SUBSURFACE_SCATTERING) || defined(_MATERIAL_FEATURE_TRANSMISSION)
				surfaceDescription.DiffusionProfile = 0;
#endif

#ifdef _MATERIAL_FEATURE_SUBSURFACE_SCATTERING
				surfaceDescription.SubsurfaceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSMISSION
				surfaceDescription.Thickness = 0;
#endif

#ifdef _MATERIAL_FEATURE_ANISOTROPY
				surfaceDescription.Anisotropy = 0;
#endif

#ifdef _MATERIAL_FEATURE_IRIDESCENCE
				surfaceDescription.IridescenceThickness = 0;
				surfaceDescription.IridescenceMask = 1;
#endif

#ifdef _MATERIAL_FEATURE_TRANSPARENCY
				surfaceDescription.IndexOfRefraction = 1;
				surfaceDescription.TransmittanceColor = float3( 1, 1, 1 );
				surfaceDescription.TransmittanceAbsorptionDistance = 1000000;
				surfaceDescription.TransmittanceMask = 0;
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
/*ASEBEGIN
Version=15410
439;100;936;689;451.4565;486.2435;1;False;False
Node;AmplifyShaderEditor.SamplerNode;12;-272,96;Float;True;Property;_Normal;Normal;2;0;Create;True;0;0;False;0;24e31ecbf813d9e49bf7a1e0d4034916;f53512d44b91e954dae7bf028209df1a;True;0;True;bump;Auto;True;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;13;-272,304;Float;True;Property;_Metallic;Metallic;3;0;Create;True;0;0;False;0;84d76c914224da14a8210ba4ba8a2992;2665c395410e391469e722b3071ed218;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.OneMinusNode;17;98.20857,-126.9763;Float;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;18;-284.9,-227.3969;Float;False;Property;_RoughnessScale;Roughness Scale;5;0;Create;True;0;0;False;0;0;0.64;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;19;-32,-144;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;15;-356.9759,-122.488;Float;True;Property;_Sand_roughness;Sand_roughness;4;0;Create;True;0;0;False;0;ae457e1c85fba234483dfbd144088f0f;ae457e1c85fba234483dfbd144088f0f;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;11;-331.2002,-499.2003;Float;True;Property;_MixAlbedo;Mix Albedo;1;0;Create;True;0;0;False;0;4112a019314dad94f9ffc2f8481f31bc;662d72b6ec210cf4cbeec2b4d3cb8b2a;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;14;2.82058,-627.6844;Float;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;16;-691.6021,-72.23596;Float;False;0;-1;2;3;2;SAMPLER2D;;False;0;FLOAT2;2,2;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;10;-340.1796,-717.6842;Float;True;Property;_BaseColor;Base Color;0;0;Create;True;0;0;False;0;e70a4cc9a27a530468623a76c6c025fe;e70a4cc9a27a530468623a76c6c025fe;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;5;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;2;META;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;True;2;False;-1;False;False;False;False;False;True;1;LightMode=Meta;False;0;;0;0;Standard;22;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;11;FLOAT;0;False;12;INT;0;False;13;FLOAT;0;False;14;FLOAT;0;False;15;FLOAT;0;False;16;FLOAT;0;False;17;FLOAT;0;False;18;FLOAT;0;False;19;FLOAT3;0,0,0;False;20;FLOAT;0;False;21;FLOAT;0;False;9;FLOAT3;0,0,0;False;10;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;7;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;4;DepthOnly;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;True;False;False;False;False;0;False;-1;False;False;False;False;True;1;LightMode=DepthOnly;False;0;;0;0;Standard;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;4;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;1;GBufferWithPrepass;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;False;True;True;2;False;-1;255;False;-1;7;False;-1;7;False;-1;3;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;False;False;False;True;1;LightMode=GBufferWithPrepass;False;0;;0;0;Standard;22;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;11;FLOAT;0;False;12;INT;0;False;13;FLOAT;0;False;14;FLOAT;0;False;15;FLOAT;0;False;16;FLOAT;0;False;17;FLOAT;0;False;18;FLOAT;0;False;19;FLOAT3;0,0,0;False;20;FLOAT;0;False;21;FLOAT;0;False;9;FLOAT3;0,0,0;False;10;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;9;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;6;Forward;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;False;True;True;2;False;-1;255;False;-1;7;False;-1;7;False;-1;3;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;False;False;False;True;1;LightMode=Forward;False;0;;0;0;Standard;22;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;11;FLOAT;0;False;12;INT;0;False;13;FLOAT;0;False;14;FLOAT;0;False;15;FLOAT;0;False;16;FLOAT;0;False;17;FLOAT;0;False;18;FLOAT;0;False;19;FLOAT3;0,0,0;False;20;FLOAT;0;False;21;FLOAT;0;False;9;FLOAT3;0,0,0;False;10;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;3;356.574,-137.8995;Float;False;True;2;Float;ASEMaterialInspector;0;4;ASESampleShaders/SRP HD Material Types/Standard;bb308bce79762c34e823049efce65141;0;0;GBuffer;22;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;False;True;True;2;False;-1;255;False;-1;7;False;-1;7;False;-1;3;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;False;False;False;True;1;LightMode=GBuffer;False;0;;0;0;Standard;22;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;4;FLOAT;0;False;5;FLOAT;0;False;6;FLOAT;0;False;7;FLOAT;0;False;8;FLOAT;0;False;11;FLOAT;0;False;12;INT;0;False;13;FLOAT;0;False;14;FLOAT;0;False;15;FLOAT;0;False;16;FLOAT;0;False;17;FLOAT;0;False;18;FLOAT;0;False;19;FLOAT3;0,0,0;False;20;FLOAT;0;False;21;FLOAT;0;False;9;FLOAT3;0,0,0;False;10;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;6;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;3;ShadowCaster;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;True;False;False;False;False;0;False;-1;False;False;False;False;True;1;LightMode=ShadowCaster;False;0;;0;0;Standard;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;8;0,0;Float;False;False;2;Float;ASEMaterialInspector;0;4;ASETemplateShaders/HDSRPPBR;bb308bce79762c34e823049efce65141;0;5;Motion Vectors;0;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;True;0;False;-1;False;False;True;1;False;-1;True;3;False;-1;False;True;3;RenderPipeline=HDRenderPipeline;RenderType=Opaque;Queue=Geometry;True;5;0;False;False;False;False;True;True;128;False;-1;255;False;-1;128;False;-1;7;False;-1;3;False;-1;1;False;-1;1;False;-1;7;False;-1;1;False;-1;1;False;-1;1;False;-1;False;False;False;True;1;LightMode=MotionVectors;False;0;;0;0;Standard;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT3;0,0,0;False;3;FLOAT3;0,0,0;False;0
WireConnection;12;1;16;0
WireConnection;13;1;16;0
WireConnection;17;0;19;0
WireConnection;19;0;18;0
WireConnection;19;1;15;1
WireConnection;15;1;16;0
WireConnection;11;1;16;0
WireConnection;14;0;10;0
WireConnection;14;1;11;0
WireConnection;3;0;14;0
WireConnection;3;1;12;0
WireConnection;3;4;13;1
WireConnection;3;5;17;0
ASEEND*/
//CHKSM=4F1E71F44CB95553E3EAD967C8AC237E22B92910