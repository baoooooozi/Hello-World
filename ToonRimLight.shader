Shader "Custom/Test3"
{
    Properties {
        _OffsetMul("_RimWidth", Range(0, 0.1)) = 0.012
        _Threshold("_Threshold", Range(0, 1)) = 0.09
        _FresnelMask("_FresnelMask", Range(0, 1)) = 0.09
    }
    SubShader {
        Tags{"RenderPipeline"="UniversalRenderPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _OffsetMul;
        float _Threshold;
        float _FresnelMask;
        CBUFFER_END

        ENDHLSL

        Pass {
            Tags{ "LightMode" = "SRPDefaultUnlit" }
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            struct Attributes{
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };
            struct Varyings {
                float4 pos : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionVS : TEXCOORD1;
                float4 positionNDC : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
            };

            Varyings vert (Attributes v) {
                Varyings o;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.pos = positionInputs.positionCS;
                o.positionVS = positionInputs.positionVS;
                o.positionNDC = positionInputs.positionNDC;
                o.positionWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs =  GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInputs.normalWS;

                return o;
            }

            float4 TransformHClipToViewPortPos(float4 positionCS){
                float4 o = positionCS * 0.5f;
                o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                o.zw = positionCS.zw;
                return o / o.w;
            }

            half4 frag (Varyings i) : SV_TARGET {
                float3 positionVS = i.positionVS;
                float3 normalWS = i.normalWS;
                float3 normalVS = TransformWorldToViewDir(normalWS, true);
                float3 samplePositionVS = float3(positionVS.xy + normalVS.xy * _OffsetMul, positionVS.z); // 保持z不变（CS.w = -VS.z）
                float4 samplePositionCS = TransformWViewToHClip(samplePositionVS); // input.positionCS不是真正的CS 而是SV_Position屏幕坐标
                float4 samplePositionVP = TransformHClipToViewPortPos(samplePositionCS);

                float depth = i.positionNDC.z / i.positionNDC.w;
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams); // 离相机越近越小
                float offsetDepth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, samplePositionVP).r; // _CameraDepthTexture.r = input.positionNDC.z / input.positionNDC.w
                float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);
                float depthDiff = linearEyeOffsetDepth - linearEyeDepth;

                float rimIntensity = step(_Threshold, depthDiff);
                float3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - i.positionWS);
                float rimRatio = 1 - saturate(dot(viewDirectionWS, normalWS));
                rimRatio = pow(rimRatio, exp2(lerp(4.0, 0.0, _FresnelMask)));

                rimIntensity = lerp(0, rimIntensity, rimRatio);
                return lerp(float4(0, 0, 0, 1), float4(1, 1, 1, 1), rimIntensity);;
            }
            ENDHLSL
        }
        Pass {
            Tags{"LightMode" = "DepthOnly"}
        }
    }
}
