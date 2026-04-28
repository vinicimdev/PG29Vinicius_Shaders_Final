Shader "Custom/RetroScreen"
{
    Properties { }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "RetroScreen"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float _Intensity;
            float _ScanlineCount;
            float _ScanlineStrength;
            float _ChromaticOffset;
            float _DitherStrength;
            float _QuantizeSteps;

            // Bayer 4x4 matrix for dithering
            static const float bayer4x4[16] = {
                 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
                12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
                 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
                15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
            };

            float4 Frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.texcoord;

                // Chromatic aberration: separates R and B in opposite directions from the center
                float2 center = float2(0.5, 0.5);
                float2 dir = uv - center;
                float aberr = _ChromaticOffset * length(dir);

                float r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv + dir * aberr).r;
                float g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).g;
                float b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv - dir * aberr).b;
                float3 col = float3(r, g, b);

                // Dithering Bayer + quantization
                // position in pixels to index the matrix
                float2 px = uv * _ScreenParams.xy;
                int xi = ((int)px.x) & 3;
                int yi = ((int)px.y) & 3;
                float threshold = bayer4x4[yi * 4 + xi] - 0.5;

                float steps = max(_QuantizeSteps, 2.0);
                float3 dithered = col + threshold * _DitherStrength;
                float3 quantized = floor(dithered * steps) / (steps - 1.0);
                col = lerp(col, quantized, _Intensity);

                // Scanlines: periodic dark horizontal bars
                float scan = sin(uv.y * _ScanlineCount * 3.14159);
                scan = scan * 0.5 + 0.5; // [0,1]
                float scanFactor = lerp(1.0, scan, _ScanlineStrength * _Intensity);
                col *= scanFactor;

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
    Fallback Off
}