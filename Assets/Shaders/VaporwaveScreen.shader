Shader "Custom/VaporwaveScreen"
{
     Properties
    {
        [Header(Sunset)]
        _ColorTop ("Color Top", Color) = (0.95, 0.4, 0.7, 1)
        _ColorMid ("Color Mid", Color) = (0.55, 0.2, 0.65, 1)
        _ColorBottom ("Color Bottom", Color) = (0.1, 0.1, 0.4, 1)

        [Header(Sun)]
        _SunColor ("Sun Color", Color) = (1.2, 0.7, 0.3, 1)
        _SunY ("Sun Y", Range(0, 1)) = 0.55
        _SunRadius ("Sun Radius", Range(0.05, 0.5)) = 0.22
        _SunBands ("Sun Bands", Range(0, 20)) = 8

        [Header(Grid)]
        _GridColor ("Grid Color", Color) = (0.4, 1.0, 1.4, 1)
        _GridDensity ("Grid Density", Range(2, 40)) = 14
        _GridScrollSpeed ("Grid Scroll Speed", Range(0, 4)) = 0.8
        _GridLineWidth ("Grid Line Width", Range(0.001, 0.1)) = 0.02
        _Horizon ("Horizon Y", Range(0, 1)) = 0.5

        [Header(CRT)]
        _ScanlineCount ("Scanline Count", Range(50, 600)) = 220
        _ScanlineStrength ("Scanline Strength", Range(0, 1)) = 0.25
        _Vignette ("Vignette", Range(0, 2)) = 0.8

        [Header(Glitch)]
        _GlitchAmount ("Glitch Amount (0-1)", Range(0, 1)) = 0
        _GlitchAuto ("Glitch Auto Pulse (1=on)", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        Pass
        {
            Name "VaporScreen"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _ColorTop;
                half4 _ColorMid;
                half4 _ColorBottom;
                half4 _SunColor;
                float _SunY;
                float _SunRadius;
                float _SunBands;
                half4 _GridColor;
                float _GridDensity;
                float _GridScrollSpeed;
                float _GridLineWidth;
                float _Horizon;
                float _ScanlineCount;
                float _ScanlineStrength;
                float _Vignette;
                float _GlitchAmount;
                float _GlitchAuto;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings   { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            float hash11(float x) { return frac(sin(x * 12.9898) * 43758.5453); }
            float hash21(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

            // Renders the base "scene" in UV space
            // Takes uv and returns a color
            float3 sampleScene(float2 uv)
            {
                // Vertical 3-stop gradient
                float3 grad;
                if (uv.y > 0.5)
                    grad = lerp(_ColorMid.rgb, _ColorTop.rgb, saturate((uv.y - 0.5) * 2.0));
                else
                    grad = lerp(_ColorBottom.rgb, _ColorMid.rgb, saturate(uv.y * 2.0));

                float3 col = grad;

                // Sun with bands
                float2 sunCenter = float2(0.5, _SunY);
                float2 d = uv - sunCenter;
                float distSun = length(d);
                if (distSun < _SunRadius)
                {
                    float sunFactor = 1.0 - smoothstep(_SunRadius * 0.85, _SunRadius, distSun);
                    // Horizontal bands: cut the sun into stripes from the middle downward
                    float bandY = (uv.y - (_SunY - _SunRadius)) / (_SunRadius * 2.0);
                    float bandMask = 1.0;
                    if (uv.y < _SunY)
                    {
                        // More cuts near the base
                        float bandPattern = step(0.5, frac(bandY * _SunBands));
                        // Bands get denser at the bottom (fading out toward the middle)
                        float fade = smoothstep(_SunY - _SunRadius, _SunY, uv.y);
                        bandMask = lerp(bandPattern, 1.0, fade);
                    }
                    col = lerp(col, _SunColor.rgb, sunFactor * bandMask);
                }

                // Fake-perspective grid, only below the horizon line.
                if (uv.y < _Horizon)
                {
                    // Normalized distance from horizon to base (0 at horizon, 1 at base)
                    float depth = (_Horizon - uv.y) / max(_Horizon, 0.0001);
                    // Horizontal lines: spaced tighter near the horizon (perspective)
                    // Using 1/depth makes them dense far away and sparse up close
                    float invDepth = 1.0 / max(depth, 0.02);
                    float scroll = _Time.y * _GridScrollSpeed;
                    float horizLine = abs(frac(invDepth - scroll) - 0.5);
                    float horizMask = 1.0 - smoothstep(0.0, _GridLineWidth * invDepth * 0.5, horizLine);

                    // Vertical lines, diverge horizontally from the center
                    float xCentered = (uv.x - 0.5) / max(depth, 0.02);
                    float vertLine = abs(frac(xCentered * _GridDensity * 0.5) - 0.5);
                    float vertMask = 1.0 - smoothstep(0.0, _GridLineWidth * 4.0, vertLine);

                    float gridMask = saturate(horizMask + vertMask);
                    // Fade the grid right at the horizon so it doesn't become a solid blob
                    gridMask *= smoothstep(0.0, 0.05, depth);

                    col = lerp(col, _GridColor.rgb, gridMask);
                }

                return col;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;

                // GLITCH
                // Combines material input + an auto-pulse (when _GlitchAuto > 0)
                float autoBurst = 0.0;
                if (_GlitchAuto > 0.5)
                {
                    // Sparse bursts: floor of time gives us "discrete frames"
                    float seg = floor(_Time.y * 1.5);
                    float spike = step(0.85, hash11(seg));
                    autoBurst = spike * (0.5 + 0.5 * hash11(seg + 17.0));
                }
                float glitch = saturate(_GlitchAmount + autoBurst * 0.7);

                // Per-band horizontal jitter: each y stripe gets a random offset
                float bandY = floor(uv.y * 60.0);
                float bandShift = (hash21(float2(bandY, floor(_Time.y * 12.0))) - 0.5);
                // Only apply the shift to some bands (not all of them)
                float bandActive = step(0.7, hash21(float2(bandY + 1.3, floor(_Time.y * 12.0))));
                float2 uvR = uv + float2(bandShift * 0.05 * glitch * bandActive, 0);
                float2 uvG = uv;
                float2 uvB = uv - float2(bandShift * 0.05 * glitch * bandActive, 0);

                // Additional RGB split, always proportional to glitch
                float chroma = 0.006 * glitch;
                uvR.x += chroma;
                uvB.x -= chroma;

                float3 col;
                col.r = sampleScene(saturate(uvR)).r;
                col.g = sampleScene(saturate(uvG)).g;
                col.b = sampleScene(saturate(uvB)).b;

                // SCANLINES
                float scan = sin(uv.y * _ScanlineCount * 3.14159);
                scan = scan * 0.5 + 0.5;
                col *= lerp(1.0, scan, _ScanlineStrength);

                // CRT VIGNETTE
                float2 q = uv - 0.5;
                float vig = 1.0 - dot(q, q) * _Vignette;
                col *= saturate(vig);

                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
