Shader "Custom/WavingFlag"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.85, 0.15, 0.25, 1)
        _ShadowColor ("Shadow Color", Color) = (0.15, 0.05, 0.10, 1)
        _Amplitude ("Wave Amplitude", Range(0, 1)) = 0.25
        _Frequency ("Wave Frequency", Range(0.1, 10)) = 2.5
        _Speed ("Wave Speed", Range(0, 5)) = 1.5
        _MaskPower ("Edge Mask (anchor side)", Range(0, 4)) = 1.5
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }
        Cull Off // Render both sides of the flag

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ShadowColor;
                float _Amplitude;
                float _Frequency;
                float _Speed;
                float _MaskPower;
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
                float3 normalWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            // Height function that sums 3 sin waves with different directions
            // The mask reduces the amplitude close to the edge of the flag, where it's stuck to the pole
            float WaveHeight(float2 uv, float t, float mask) 
            {
                float w1 = sin(uv.x * _Frequency * 2.0 + t * _Speed);
                float w2 = sin(uv.x * _Frequency * 1.3 + uv.y * 1.7 + t * _Speed * 1.1) * 0.6;
                float w3 = sin(uv.y * _Frequency * 0.8 + t * _Speed * 0.7) * 0.3;
                return (w1 + w2 + w3) * _Amplitude * mask;
            }

            float2 WaveGradient(float2 uv, float t, float mask)
            {
                float dHdx =
                    cos(uv.x * _Frequency * 2.0 + t * _Speed) * _Frequency * 2.0 +
                    cos(uv.x * _Frequency * 1.3 + uv.y * 1.7 + t * _Speed * 1.1) * _Frequency * 1.3 * 0.6;
                float dHdy =
                    cos(uv.x * _Frequency * 1.3 + uv.y * 1.7 + t * _Speed * 1.1) * 1.7 * 0.6 +
                    cos(uv.y * _Frequency * 0.8 + t * _Speed * 0.7) * _Frequency * 0.8 * 0.3;
                return float2(dHdx, dHdy) * _Amplitude * mask;
            }
                        
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // Mask: 0 if the border is on the left, 1 if its on the right
                float mask = pow(saturate(IN.uv.x), _MaskPower);
                float t = _Time.y;

                // Displaces along the Z axis in object space
                float h = WaveHeight(IN.uv, t, mask);
                float3 displacedOS = IN.positionOS.xyz + float3(0, 0, h);

                // Recalculated normal, using the gradient of the height function with respect to the UV plane
                float2 grad = WaveGradient(IN.uv, t, mask);
                float3 newNormalOS = normalize(float3(-grad.x, -grad.y, 1.0));

                OUT.positionHCS = TransformObjectToHClip(displacedOS);
                OUT.normalWS = TransformObjectToWorldNormal(newNormalOS);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalize(IN.normalWS), mainLight.direction));
                NdotL = NdotL * 0.5 + 0.5;
                NdotL *= NdotL;

                half3 col = lerp(_ShadowColor.rgb, _BaseColor.rgb, NdotL);
                col *= mainLight.color;
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
