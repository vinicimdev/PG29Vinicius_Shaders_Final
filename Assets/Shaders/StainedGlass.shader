Shader "Custom/StainedGlass"
{
    Properties
    {
        _Scale ("Cell Scale", Range(1, 30)) = 8
        _EdgeWidth ("Edge Width", Range(0, 0.2)) = 0.05
        _EdgeColor ("Edge Color", Color) = (0.02, 0.02, 0.05, 1)
        _Saturation ("Saturation", Range(0, 1)) = 0.85
        _Brightness ("Brightness", Range(0, 2)) = 1.1
        _AnimSpeed ("Animation Speed", Range(0, 2)) = 0.3
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry"}

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Scale;
                float _EdgeWidth;
                half4 _EdgeColor;
                float _Saturation;
                float _Brightness;
                float _AnimSpeed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Hash2D from shadertoy :D
            float2 hash22(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)),
                           dot(p, float2(269.5, 183.3)));
                return frac(sin(p) * 43758.5453);
            }

            // Hash2D for 1D for color
            float hash21(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
            }

            float3 hsv2rgb(float3 c)
            {
                float3 p = abs(frac(c.xxx + float3(0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
                return c.z * lerp(float3(1,1,1), saturate(p - 1.0), c.y);
            }

            float3 voronoi(float2 uv)
            {
                float2 cell = floor(uv);
                float2 frac_uv = frac(uv);

                float F1 = 8.0;
                float F2 = 8.0;
                float2 closestId = float2(0,0);

                [unroll]
                for (int y = -1; y <= 1; y++)
                {
                    [unroll]
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 point_offset = hash22(cell + neighbor);
                        // Anima o ponto da celula
                        point_offset = 0.5 + 0.5 * sin(_Time.y * _AnimSpeed + 6.2831 * point_offset);

                        float2 diff = neighbor + point_offset - frac_uv;
                        float d = dot(diff, diff); // quadrado da distancia, suficiente pra comparar

                        if (d < F1)
                        {
                            F2 = F1;
                            F1 = d;
                            closestId = cell + neighbor;
                        }
                        else if (d < F2)
                        {
                            F2 = d;
                        }
                    }
                }

                // Borda: diferenca entre F2 e F1 (pequena perto das fronteiras das celulas).
                float edge = sqrt(F2) - sqrt(F1);
                float cellSeed = hash21(closestId);
                return float3(edge, cellSeed, sqrt(F1));
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv * _Scale;
                float3 v = voronoi(uv);
                float edge = v.x;
                float cellSeed = v.y;
                float distF1 = v.z;

                // Cor base da celula
                float3 cellColor = hsv2rgb(float3(cellSeed, _Saturation, _Brightness));

                // Sombra/luz interna da celula: mais escuro perto do centro? Ou ao contrario.
                // Aqui faco gradiente sutil com distF1 pra dar profundidade.
                cellColor *= lerp(0.85, 1.05, 1.0 - saturate(distF1));

                // Mascara da borda: smoothstep pra borda suave
                float edgeMask = 1.0 - smoothstep(0.0, _EdgeWidth, edge);

                float3 finalColor = lerp(cellColor, _EdgeColor.rgb, edgeMask);
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}
