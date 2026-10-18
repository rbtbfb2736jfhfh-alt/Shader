AETHER - Cinematic Realism Shaderpack (OptiFine / Iris, GLSL 330 compat)
=======================================================================
Install: put the "shaders" folder inside a folder or zip (Aether.zip) in
<minecraft>/shaderpacks. Needs Iris 1.6+ (recommended) or OptiFine HD U G9+.
For LabPBR 1.3 detail use a LabPBR resource pack (normal.a = height, spec RGBA).

PIPELINE
 shadow             PCSS-ready shadow map, coloured translucent shadows, wind-synced foliage
 gbuffers_*         terrain/entities/hand -> normals, LabPBR spec, albedo; POM, wetness, puddles
 gbuffers_water     true Gerstner waves (up to 8 octaves), glass/ice
 deferred           screen-space ray-traced diffuse GI (cosine rays) + temporal accumulation
 deferred1          Rayleigh/Mie sky, stars, sun/moon, volumetric clouds, PBR lighting, GI denoise
 composite          water absorption/refraction/foam, SSR + sky fallback, underwater fog
 composite1         height fog + volumetric light shafts (shadow-map marched)
 composite2         thin-lens DoF with 7-blade bokeh        (toggle: DOF)
 composite3         camera motion blur                      (toggle: MOTION_BLUR)
 composite4         eye-adaptation exposure (asymmetric adaptation speeds)
 final              bloom (mip chain), lens flare, chromatic aberration, ACES, vignette, grain

HONEST NOTES
 * "PTGI" here is SCREEN-SPACE ray-traced GI with temporal accumulation and bounce
   feedback. Off-screen geometry cannot bounce light. True path tracing needs a
   voxelised world (Iris compute shaders) - not feasible in a plain gbuffers pack.
 * SSR/GI only see what is on screen; rays leaving the screen fall back to the sky.
 * Cloud shadows on the ground are not implemented.
 * Entities/hand use geometric normals (no normal map / POM) for compatibility.
 * All 40 programs compile in glslangValidator (GLSL 330 compat). The pack has NOT
   been run inside Minecraft by the author: expect to tune shadow bias
   (lib/shadow.glsl), exposure compensation (EXPOSURE_BIAS) and GI strength.
 * Heavy settings: CLOUD_STEPS, GI_RAYS/GI_STEPS, SSR_STEPS, DOF. Lower for FPS.

CHANGELOG
 r4: hand is now forward-lit in gbuffers_hand (Iris draws it after deferred); GI/ambient floor
     (no black holes in forests/caves); shadow vertex uses explicit shadowModelView + soft
     shadow-map edge fade; cloud horizon band fixed; underwater light floor; DoF default subtler.
