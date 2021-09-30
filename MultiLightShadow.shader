Shader "URP/multi_Light_And_Shadow" {
  Properties {
   _MainTex("MainTex", 2D) = "white" {}
   _BaseColor("BaseColor", Color) = (1,1,1,1)
   _ShadowColor("ShadowColor", Color) = (1,1,1,1)
   [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight", float) = 1
   [KeywordEnum(ON,OFF)]_CUT("Cut", float) = 1
   _Cutoff("Cutoff", Range(0,1)) = 0.5
  }
  SubShader {
   Tags{"RenderPipeline"="UniversalRenderPipeline"}

   HLSLINCLUDE
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
   #pragma  shader_feature_local _CUT_ON  
   #pragma  shader_feature_local _ADD_LIGHT_ON  

   CBUFFER_START(UnityPerMaterial)
   float4 _MainTex_ST;
   half4 _BaseColor;
   half4 _ShadowColor;
   float _Cutoff;
   CBUFFER_END

   TEXTURE2D(_MainTex);
   SAMPLER(sampler_MainTex);

   struct a2v {
    float4 positionOS : POSITION;
    float4 normalOS : NORMAL;
    float2 texcoord : TEXCOORD;
   };

   struct v2f {
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 viewDirWS : TEXCOORD2;
    float3 positionWS : TEXCOORD3;
   };
   ENDHLSL

   Pass {
    Tags {"LightMode"="UniversalForward" "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
    
    Cull off
    HLSLPROGRAM
    
    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
    #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
    #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
    #pragma multi_compile _ _SHADOWS_SOFT

    v2f vert (a2v i) {
      v2f o;
      o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
      o.uv = TRANSFORM_TEX(i.texcoord, _MainTex);
      o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
      o.viewDirWS = normalize(_WorldSpaceCameraPos - o.positionWS);
      o.normalWS = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
      return o;
    }

    half4 frag (v2f i) : SV_Target {
      half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;

      #ifdef _CUT_ON
      clip(tex.a - _Cutoff);
      #endif

      float3 normalWS = i.normalWS;
      float3 positionWS = i.positionWS;
      float3 viewDirWS = i.viewDirWS;

      #ifdef _MAIN_LIGHT_SHADOWS
      half4 shadowcoord=TransformWorldToShadowCoord(i.positionWS);
      Light mylight = GetMainLight(shadowcoord);
      #else
      Light mylight=GetMainLight();
      #endif

      half4 maincolor = (dot(normalWS,mylight.direction)*0.5+0.5)*real4(mylight.color,1)*tex*(mylight.distanceAttenuation*lerp(_ShadowColor, _BaseColor, mylight.shadowAttenuation));
      real4 addcolor = real4(0,0,0,1);

      #if _ADD_LIGHT_ON
      int addLightCount = GetAdditionalLightsCount();
      for(int i = 0; i<addLightCount; i++){
       Light addlight = GetAdditionalLight(i,positionWS,half4(1,1,1,1));
       float3 addLightDirWS = normalize(addlight.direction);
       addcolor+=(dot(normalWS,addLightDirWS)*0.5+0.5)*real4(addlight.color,1)*tex*addlight.distanceAttenuation*lerp(_ShadowColor, _BaseColor, addlight.shadowAttenuation);
      }
      #endif

      return tex*(maincolor + addcolor);
    }
    ENDHLSL
   }
   
   Pass {
    Tags{"LightMode"="ShadowCaster"}
    HLSLPROGRAM

    #pragma vertex vertshadow
    #pragma fragment fragshadow

    float3 _LightDirection;
    v2f vertshadow(a2v i) {
      v2f o;
      o.uv=TRANSFORM_TEX(i.texcoord,_MainTex);
      float3 positionWS = TransformObjectToWorld(i.positionOS.xyz);
      float3 normalWS = TransformObjectToWorldNormal(i.normalOS.xyz);
      o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

      #if UNITY_REVERSED_Z
      o.positionCS.z=min(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
      #else
      o.positionCS.z=max(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
      #endif

      return o;
    }

    half4 fragshadow(v2f i) : SV_Target {

      #ifdef _CUT_ON
      float alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a*_BaseColor;
      clip(alpha - _Cutoff);
      #endif

      return 0;
    } 
    ENDHLSL
   }
  }
}
