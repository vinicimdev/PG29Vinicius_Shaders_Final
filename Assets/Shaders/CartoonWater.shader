Shader "Custom/CartoonWater"
{
    Properties
    {
        [Header(Colors)]
        _ShallowColor ("Shallow Color", Color) = (0.4, 0.85, 0.95, 0.7)
        _DeepColor ("Deep Color", Color) = (0.05, 0.15, 0.45, 0.95)
        _FoamColor ("Foam Color", Color) = (1, 1, 1, 1)
        _HighlightColor ("Highlight Color", Color) = (1, 1, 1, 1)

        [Header(Surface)]
        _NoiseScale ("Noise Scale", Range(0.5, 20)) = 5
        _ScrollSpeed ("Scroll Speed", Range(0, 1)) = 0.15
        _HighlightCutoff ("Highlight Cutoff", Range(0, 1)) = 0.65
        _HighlightWidth ("Highlight Width", Range(0, 0.3)) = 0.05

        [Header(Depth)]
        _DepthFade ("Depth Fade Distance", Range(0.01, 5)) = 1.5
        _FresnelPower ("Fresnel Power", Range(0.1, 8)) = 3
        _FoamDistance ("Foam Distance", Range(0.01, 3)) = 0.4
        _FoamCutoff ("Foam Cutoff", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" }

        Pass
        {
            Name "ForwardWater"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _ShallowColor;
                half4 _DeepColor;
                half4 _FoamColor;
                half4 _HighlightColor;
                float _NoiseScale;
                float _ScrollSpeed;
                float _HighlightCutoff;
                float _HighlightWidth;
                float _DepthFade;
                float _FresnelPower;
                float _FoamDistance;
                float _FoamCutoff;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 screenPos   : TEXCOORD0;
                float3 positionWS  : TEXCOORD1;
                float3 normalWS    : TEXCOORD2;
                float2 uv          : TEXCOORD3;
            };

            // Noise gradient
            float2 hash22(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453);
            }

            float gradNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f); // smoothstep
                return lerp(
                    lerp(dot(hash22(i + float2(0,0)), f - float2(0,0)),
                         dot(hash22(i + float2(1,0)), f - float2(1,0)), u.x),
                    lerp(dot(hash22(i + float2(0,1)), f - float2(0,1)),
                         dot(hash22(i + float2(1,1)), f - float2(1,1)), u.x),
                    u.y);
            }

            // fbm for cartoonish look
            float fbm(float2 p)
            {
                return gradNoise(p) * 0.6 + gradNoise(p * 2.1) * 0.4;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vp = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = vp.positionCS;
                OUT.positionWS = vp.positionWS;
                OUT.screenPos = ComputeScreenPos(vp.positionCS);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float t = _Time.y * _ScrollSpeed;

                // 2 noise layers scrolling in different directions
                float2 uvA = IN.uv * _NoiseScale + float2(t, t * 0.6);
                float2 uvB = IN.uv * _NoiseScale * 1.5 + float2(-t * 0.8, t * 0.3);
                float n = fbm(uvA) * 0.5 + fbm(uvB) * 0.5;
                n = n * 0.5 + 0.5; // remap pra [0,1]

                // Depth-based foam
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                float rawSceneDepth = SampleSceneDepth(screenUV);
                float sceneDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);
                float surfaceDepth = IN.screenPos.w;
                float depthDiff = sceneDepth - surfaceDepth;

                
                float foamMask = 1.0 - saturate(depthDiff / _FoamDistance);
                
                foamMask = step(_FoamCutoff, foamMask + n * 0.3);

                float depthBlend = saturate(depthDiff / _DepthFade);
                half4 waterCol = lerp(_ShallowColor, _DeepColor, depthBlend);

                float3 N = normalize(IN.normalWS);
                float3 V = normalize(_WorldSpaceCameraPos - IN.positionWS);
                float fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);
                waterCol.rgb = lerp(waterCol.rgb, _ShallowColor.rgb, fresnel);

                
                float highlight = step(_HighlightCutoff, n) * step(n, _HighlightCutoff + _HighlightWidth);

                half3 finalCol = waterCol.rgb;
                finalCol = lerp(finalCol, _HighlightColor.rgb, highlight);
                finalCol = lerp(finalCol, _FoamColor.rgb, foamMask);

                float finalAlpha = lerp(waterCol.a, 1.0, max(foamMask, highlight));
                return half4(finalCol, finalAlpha);
            }
            ENDHLSL
        }
    }
}
