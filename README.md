# Final Assignment: Miniature Shader Showcase

This is a Unity 6 project that demonstrates six different shaders. The project covers the full shader pipeline — from vertex displacement and fragment-only effects to custom post-processing and a creative final scene.

## Features

- Six standalone shaders
- All shaders written by hand in HLSL (no ShaderGraph)
- Custom URP ScriptableRendererFeature for post-processing
- Procedural effects with no external textures required
- Depth-based foam and fresnel for stylized water
- Distance-basde highlight that activates only near the camera
- Procedural sunset, grid and glitch generated entirely in UV space

## Stack

- Unity 6 with Universal Render Pipeline (URP)
- HLSL for all shaders
- C# (ScriptableRendererFeature using the new RenderGraph API)

## Shaders

The project includes six shaders, all on the same scene:

- **WavingFlag** -> Vertex shader. Cloth ondulation using a sum of three sines, with normals reconstructed analytically from the height function gradient so lighting matches the deformation.
- **StainedGlass** -> Fragment shader. Procedural Voronoi pattern using F1/F2 distances to draw the dark borders, with cell colors generated from a hash of the cell ID.
- **RetroScreen** -> Post-processing. Custom URP Renderer Feature that applies scanlines, Bayer 4x4 dithering with color quantization and chromatic aberration on top of the standard URP Volume.
- **ItemHighlight** -> Item shader. Fresnel rim highlight that only activates when the camera is within a configurable range, with a temporal pulse to draw attention.
- **CartoonWater** -> Environment shader. Stylized cartoon water with two scrolling noise layers, depth-based foam at object intersections, fresnel-based depth coloring and cartoon highlight stripes.
- **VaporwaveScreen** -> Creative showcase. CRT TV screen rendered procedurally in UV space, featuring sunset gradient, banded sun, fake-perspective Outrun grid, scanlines, vignette and a glitch effect with RGB split and per-band horizontal jitter.

## How to use the Project

1. Open the project in Unity 6 with URP.
2. Make sure the URP Asset has Depth Texture enabled (required by the Cartoon Water and the post-process).
3. Open the URP Renderer Data and make sure the Retro Screen Feature is added under Renderer Features.

## Setup

Download as ZIP, extract and add the project to UnityHub and open it with Unity 6000.3.8f1.

## Author

Made by PG29 Vinicius, @VFS 2025-2026 All rights reserved.