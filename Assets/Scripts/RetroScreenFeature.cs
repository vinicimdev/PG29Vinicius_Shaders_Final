using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class RetroScreenFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Range(0f, 1f)] public float intensity = 1f;
        [Range(50f, 800f)] public float scanlineCount = 240f;
        [Range(0f, 1f)] public float scanlineStrength = 0.25f;
        [Range(0f, 0.05f)] public float chromaticOffset = 0.008f;
        [Range(0f, 0.5f)] public float ditherStrength = 0.08f;
        [Range(2f, 32f)] public float quantizeSteps = 16f;
        public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public Settings settings = new Settings();

    private Material _material;
    private RetroScreenPass _pass;

    public override void Create()
    {
        Shader sh = Shader.Find("Custom/RetroScreen");
        if (sh == null) return;
        _material = CoreUtils.CreateEngineMaterial(sh);
        _pass = new RetroScreenPass(_material, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_pass == null || _material == null) return;
        if (renderingData.cameraData.cameraType != CameraType.Game &&
            renderingData.cameraData.cameraType != CameraType.SceneView) return;

        _pass.renderPassEvent = settings.injectionPoint;
        _pass.UpdateSettings(settings);
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(_material);
    }

    private class RetroScreenPass : ScriptableRenderPass
    {
        private static readonly int IntensityId = Shader.PropertyToID("_Intensity");
        private static readonly int ScanlineCountId = Shader.PropertyToID("_ScanlineCount");
        private static readonly int ScanlineStrengthId = Shader.PropertyToID("_ScanlineStrength");
        private static readonly int ChromaticOffsetId = Shader.PropertyToID("_ChromaticOffset");
        private static readonly int DitherStrengthId = Shader.PropertyToID("_DitherStrength");
        private static readonly int QuantizeStepsId = Shader.PropertyToID("_QuantizeSteps");

        private readonly Material _mat;
        private Settings _settings;

        public RetroScreenPass(Material mat, Settings s)
        {
            _mat = mat;
            _settings = s;
            requiresIntermediateTexture = true; 
        }

        public void UpdateSettings(Settings s)
        {
            _settings = s;
            if (_mat == null) return;
            _mat.SetFloat(IntensityId, s.intensity);
            _mat.SetFloat(ScanlineCountId, s.scanlineCount);
            _mat.SetFloat(ScanlineStrengthId, s.scanlineStrength);
            _mat.SetFloat(ChromaticOffsetId, s.chromaticOffset);
            _mat.SetFloat(DitherStrengthId, s.ditherStrength);
            _mat.SetFloat(QuantizeStepsId, s.quantizeSteps);
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (_mat == null) return;

            UniversalResourceData resources = frameData.Get<UniversalResourceData>();
            TextureHandle source = resources.activeColorTexture;

            var srcDesc = renderGraph.GetTextureDesc(source);
            srcDesc.name = "RetroScreen_Tmp";
            srcDesc.clearBuffer = false;
            TextureHandle tmp = renderGraph.CreateTexture(srcDesc);

            RenderGraphUtils.BlitMaterialParameters blitParams =
                new RenderGraphUtils.BlitMaterialParameters(source, tmp, _mat, 0);
            renderGraph.AddBlitPass(blitParams, "RetroScreen Blit");

            resources.cameraColor = tmp;
        }
    }
}

