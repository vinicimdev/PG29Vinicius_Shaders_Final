Shader "Custom/ItemHighlight"
{
    Properties
    {
        [Header(Base)]
        _BaseColor ("Base Color", Color) = (0.4, 0.5, 0.6, 1)
        _BaseMap ("Base Map", 2D) = "white" {}

        [Header(Highlight)]
        _RimColor ("Rim Color", Color) = (0.6, 1.0, 1.5, 1)
        _RimPower ("Rim Power", Range(0.5, 12)) = 3.0
        _RimIntensity ("Rim Intensity", Range(0, 5)) = 2.0

        [Header(Proximity)]
        _NearDistance ("Near Distance (full)", Range(0.1, 20)) = 2.5
        _FarDistance ("Far Distance (off)", Range(0.5, 30)) = 6.0

        [Header(Pulse)]
        _PulseSpeed ("Pulse Speed", Range(0, 10)) = 3.0
        _PulseAmount ("Pulse Amount", Range(0, 1)) = 0.4
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _RimColor;
                float _RimPower;
                float _RimIntensity;
                float _NearDistance;
                float _FarDistance;
                float _PulseSpeed;
                float _PulseAmount;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vp = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = vp.positionCS;
                OUT.positionWS = vp.positionWS;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // Simple base Lighting (Lambert)
                float3 N = normalize(IN.normalWS);
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(N, mainLight.direction)) * 0.7 + 0.3; // half-lambert

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 lit = albedo.rgb * NdotL * mainLight.color;

                // Proximity highlight
                float3 V = _WorldSpaceCameraPos - IN.positionWS;
                float distToCam = length(V);
                V = V / max(distToCam, 0.0001);

                // fresnel effect
                float fresnel = pow(1.0 - saturate(dot(N, V)), _RimPower);

                // Proximity mask: 1 when distance <= near, 0 when dist >= far, smooth in between.
                float proximity = 1.0 - smoothstep(_NearDistance, _FarDistance, distToCam);

                // Pulse oscilating between (1 - amount) and 1.0
                float pulse = 1.0 - _PulseAmount * (0.5 + 0.5 * sin(_Time.y * _PulseSpeed));

                float rimStrength = fresnel * _RimIntensity * proximity * pulse;
                half3 rim = _RimColor.rgb * rimStrength;

                return half4(lit + rim, albedo.a);
            }
            ENDHLSL
        }
    }
}
