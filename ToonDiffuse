Shader "Custom/Toon" {
    Properties {
        _MainTex("MainTex", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1,1,1,1)
        _DarkColor("DarkColor", Color) = (0,0,0,0)
        _RampThreshold("RampThreshold", float) = 0.5
        _RampSmooth("RampSmooth", float) = 0.5
    }

    SubShader {
        Tags{"RenderPipeline"="UniversalRenderPipeline"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half _RampThreshold;
        half _RampSmooth;
        half4  _DarkColor;
        CBUFFER_END

        ENDHLSL

        Pass {
            Tags{ "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 texcoord : TEXCOORD0;
            };
            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            half3 CalucateRamp(half ndlWrapped, Light mainLight) {
                half rampThreshold = _RampThreshold;
                half3 ramp = smoothstep(rampThreshold - _RampSmooth, rampThreshold + _RampSmooth, ndlWrapped).xxx;
                half atten = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                ramp *= (atten * mainLight.color * _BaseColor);
                ramp = lerp(_DarkColor, _BaseColor, ramp);
                half3 ambient = _GlossyEnvironmentColor;
                return ramp + ambient;
            }

            Varyings vert (Attributes v) {
                Varyings o;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInputs.normalWS;
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            half4 frag (Varyings i) : SV_TARGET {
                half4 shadowcoord=TransformWorldToShadowCoord(i.positionWS);
                Light mylight = GetMainLight(shadowcoord);
                float3 normalWS = i.normalWS;
                float3 lightDir = mylight.direction;

                half ndl = dot(normalWS, mylight.direction);
                half ndlWrapped = ndl * 0.5 + 0.5;
                ndl = saturate(ndl);

                half3 albedo = CalucateRamp(ndlWrapped, mylight);

                return half4(albedo,0);
            }
            ENDHLSL
        }
    }
}
