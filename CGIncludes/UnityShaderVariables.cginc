// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

/* 
本文件中包含大量的工具宏和函数，
如变换操作用的矩阵、与摄像机相关的函数、与光照和阴影相关的函数，以及与雾效果相关的函数等。
*/

#ifndef UNITY_SHADER_VARIABLES_INCLUDED
    #define UNITY_SHADER_VARIABLES_INCLUDED

    #include "HLSLSupport.cginc"

    #if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
        #define USING_DIRECTIONAL_LIGHT
    #endif

    // UNITY_SINGLE_PASS_STEREO：单程立体渲染：一种高效支持VR效果的方式，用于PC或者PlayStation4上的VR应用。这种技术同时把要显示在左右眼的图像打包渲染进一张可渲染纹理中，避免左右眼各渲染一次，提高渲染性能
    // UNITY_STEREO_INSTANCING_ENABLED：立体多例化渲染：在一次渲染管道上提交两份待渲染的几何体数据，减少DrawCall次数，提升渲染性能
    // UNITY_STEREO_MULTIVIEW_ENABLED：多视角立体渲染是否启用
    #if defined(UNITY_SINGLE_PASS_STEREO) || defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        #define USING_STEREO_MATRICES       // 要使用与立体渲染相关的矩阵
    #endif

    // 一系列与立体渲染相关的矩阵（一）
    #if defined(USING_STEREO_MATRICES)
        #define glstate_matrix_projection unity_StereoMatrixP[unity_StereoEyeIndex]
        #define unity_MatrixV unity_StereoMatrixV[unity_StereoEyeIndex]
        #define unity_MatrixInvV unity_StereoMatrixInvV[unity_StereoEyeIndex]
        #define unity_MatrixVP unity_StereoMatrixVP[unity_StereoEyeIndex]

        #define unity_CameraProjection unity_StereoCameraProjection[unity_StereoEyeIndex]
        #define unity_CameraInvProjection unity_StereoCameraInvProjection[unity_StereoEyeIndex]
        #define unity_WorldToCamera unity_StereoWorldToCamera[unity_StereoEyeIndex]
        #define unity_CameraToWorld unity_StereoCameraToWorld[unity_StereoEyeIndex]
        #define _WorldSpaceCameraPos unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex]
    #endif

    // 一系列用来进行变换操作的矩阵（一）
    #define UNITY_MATRIX_P glstate_matrix_projection
    #define UNITY_MATRIX_V unity_MatrixV
    #define UNITY_MATRIX_I_V unity_MatrixInvV
    #define UNITY_MATRIX_VP unity_MatrixVP
    #define UNITY_MATRIX_M unity_ObjectToWorld

    #define UNITY_LIGHTMODEL_AMBIENT (glstate_lightmodel_ambient * 2)

    // ----------------------------------------------------------------------------
    // ********** 和摄像机相关的常量缓冲区 **********

    // 常量缓冲区 UnityPerCamera
    // Unity 3D 内建的，用来传递给每个摄像机的参数组
    // 这些参数由引擎从C#层代码传递给着色器
    CBUFFER_START(UnityPerCamera)
    // Time (t = time since current level load) values from Unity
    // 从载入当前的scene开始算起流逝的时间，单位秒（s）
    float4 _Time; // (t/20, t, t*2, t*3)
    // _Time值得正弦值
    float4 _SinTime; // sin(t/8), sin(t/4), sin(t/2), sin(t)
    // _Time值得余弦值
    float4 _CosTime; // cos(t/8), cos(t/4), cos(t/2), cos(t)
    // 本帧到上一帧过去得时间间隔
    float4 unity_DeltaTime; // dt, 1/dt, smoothdt, 1/smoothdt

    // 如果没有开启立体渲染
    // 就由C#层代码传递一个表征一个当前摄像机在世界空间中得坐标值
    #if !defined(USING_STEREO_MATRICES)
        float3 _WorldSpaceCameraPos;
    #endif

    // x = 1 or -1 (-1 if projection is flipped)
    // y = near plane
    // z = far plane
    // w = 1/far plane
    float4 _ProjectionParams;       // 投影矩阵相关参数

    // x = width
    // y = height
    // z = 1 + 1.0/width
    // w = 1 + 1.0/height
    float4 _ScreenParams;           // 视口相关参数

    // Values used to linearize the Z buffer (http://www.humus.name/temp/Linearize%20depth.txt)
    // x = 1-far/near
    // y = far/near
    // z = x/far
    // w = y/far
    // or in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
    // 深度缓冲区反转（UNITY_REVERSED_Z为1）的情况下
    // x = -1+far/near
    // y = 1
    // z = x/far
    // w = 1/far
    float4 _ZBufferParams;          // Z buffer相关参数

    // x = orthographic camera's width
    // y = orthographic camera's height
    // z = unused
    // w = 1.0 if camera is ortho, 0.0 if perspective
    float4 unity_OrthoParams;       // 摄像机得投影相关得参数
    #if defined(STEREO_CUBEMAP_RENDER_ON)
        //x-component is the half stereo separation value, which a positive for right eye and negative for left eye. The y,z,w components are unused.
        // x分量是 stereo separation值得一半，右眼为正，左眼为负，y、z、w分量未使用。
        float4 unity_HalfStereoSeparation;
    #endif
    CBUFFER_END

    // 常量缓冲区 UnityPerCameraRare
    CBUFFER_START(UnityPerCameraRare)
    // 当前摄像机视截体得6个截平面得屏幕表达式。
    // 这些平面表达式在世界坐标系下描述
    // 每个平面表达式用方程ax+by+cz+d = 0表达，float4中得分量x、y、z、w依次存储了系数a、b、c、d。
    // 6个平面依次是左、右、下、上、近、远裁剪平面。
    float4 unity_CameraWorldClipPlanes[6];

    // 如果没有开启立体渲染，各个矩阵变量就是一个单变量而不是两个变量得数组
    #if !defined(USING_STEREO_MATRICES)
        // Projection matrices of the camera. Note that this might be different from projection matrix
        // that is set right now, e.g. while rendering shadows the matrices below are still the projection
        // of original camera.
        float4x4 unity_CameraProjection;            // 当前摄像机的投影矩阵
        float4x4 unity_CameraInvProjection;         // 当前摄像机的投影矩阵的逆矩阵
        float4x4 unity_WorldToCamera;               // 当前摄像机的观察矩阵？？（世界空间到摄像机观察空间的矩阵）
        float4x4 unity_CameraToWorld;               // 当前摄像机的观察矩阵的逆矩阵？？（世界空间到摄像机观察空间的矩阵的逆矩阵）
    #endif
    CBUFFER_END

    // ********** END **********
    // ----------------------------------------------------------------------------

    CBUFFER_START(UnityLighting)

    #ifdef USING_DIRECTIONAL_LIGHT
        half4 _WorldSpaceLightPos0;
    #else
        float4 _WorldSpaceLightPos0;
    #endif

    float4 _LightPositionRange; // xyz = pos, w = 1/range
    float4 _LightProjectionParams; // for point light projection: x = zfar / (znear - zfar), y = (znear * zfar) / (znear - zfar), z=shadow bias, w=shadow scale bias

    float4 unity_4LightPosX0;
    float4 unity_4LightPosY0;
    float4 unity_4LightPosZ0;
    half4 unity_4LightAtten0;

    half4 unity_LightColor[8];


    float4 unity_LightPosition[8]; // view-space vertex light positions (position,1), or (-direction,0) for directional lights.
    // x = cos(spotAngle/2) or -1 for non-spot
    // y = 1/cos(spotAngle/4) or 1 for non-spot
    // z = quadratic attenuation
    // w = range*range
    half4 unity_LightAtten[8];
    float4 unity_SpotDirection[8]; // view-space spot light directions, or (0,0,1,0) for non-spot

    // SH lighting environment
    half4 unity_SHAr;
    half4 unity_SHAg;
    half4 unity_SHAb;
    half4 unity_SHBr;
    half4 unity_SHBg;
    half4 unity_SHBb;
    half4 unity_SHC;

    // part of Light because it can be used outside of shadow distance
    fixed4 unity_OcclusionMaskSelector;
    fixed4 unity_ProbesOcclusion;
    CBUFFER_END

    CBUFFER_START(UnityLightingOld)
    half3 unity_LightColor0, unity_LightColor1, unity_LightColor2, unity_LightColor3; // keeping those only for any existing shaders; remove in 4.0
    CBUFFER_END


    // ----------------------------------------------------------------------------

    CBUFFER_START(UnityShadows)
    float4 unity_ShadowSplitSpheres[4];
    float4 unity_ShadowSplitSqRadii;
    float4 unity_LightShadowBias;
    float4 _LightSplitsNear;
    float4 _LightSplitsFar;
    float4x4 unity_WorldToShadow[4];
    half4 _LightShadowData;
    float4 unity_ShadowFadeCenterAndType;
    CBUFFER_END

    // ----------------------------------------------------------------------------

    CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;
    float4 unity_LODFade; // x is the fade value ranging within [0,1]. y is x quantized into 16 levels
    float4 unity_WorldTransformParams; // w is usually 1.0, or -1.0 for odd-negative scale transforms
    float4 unity_RenderingLayer;
    CBUFFER_END

    // 一系列与立体渲染相关的矩阵（二）
    #if defined(USING_STEREO_MATRICES)
        GLOBAL_CBUFFER_START(UnityStereoGlobals)    // 常量缓冲区起始声明
        float4x4 unity_StereoMatrixP[2];                // 每个眼睛的投影矩阵
        float4x4 unity_StereoMatrixV[2];                // 左、右眼的观察矩阵
        float4x4 unity_StereoMatrixInvV[2];             // 左、右眼的观察矩阵的逆矩阵
        float4x4 unity_StereoMatrixVP[2];               // 左、右眼的观察矩阵与投影矩阵的乘积

        float4x4 unity_StereoCameraProjection[2];       // 摄像机的投影矩阵
        float4x4 unity_StereoCameraInvProjection[2];    // 摄像机的投影矩阵的逆矩阵
        float4x4 unity_StereoWorldToCamera[2];          // 从世界空间变换到摄像机观察空间的矩阵
        float4x4 unity_StereoCameraToWorld[2];          // 从摄像机观察空间变换到设计空间的矩阵

        float3 unity_StereoWorldSpaceCameraPos[2];      // 摄像机在世界空间中的坐标值
        // 进行单程立体渲染时，和普通渲染不同，并不是直接把渲染效果写入对应屏
        // 幕的颜色缓冲区，而是把渲染结果写入对应于左右眼的两个图像（image）中，
        // 然后把两个图像合并到一张可渲染纹理中再显示。
        // 变量 unity_StereoScaleOffset 维护了把两图像合并进一张纹理中要用到的平铺值（tiling）和偏移值（offset）
        float4 unity_StereoScaleOffset[2];
        GLOBAL_CBUFFER_END                          // 常量缓冲区结束声明
    #endif

    #if defined(USING_STEREO_MATRICES) && defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        GLOBAL_CBUFFER_START(UnityStereoEyeIndices)
        float4 unity_StereoEyeIndices[2];
        GLOBAL_CBUFFER_END
    #endif

    // 如果启用了多视角立体渲染，unity_StereoEyeIndex 的值就是 UNITY_VIEWID
    // 而 UNITY_VIEWID 的值就是 gl_viewID 值（HLSLSupport.cginc 文件中定义）
    #if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_STAGE_VERTEX)
        // 把立体渲染的左右眼索引值变量定义别名为 UNITY_VIEWID
        #define unity_StereoEyeIndex UNITY_VIEWID
        UNITY_DECLARE_MULTIVIEW(2);
        
        // 如果启用了立体多例化渲染或多视角立体渲染
    #elif defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
        // 定义为一个静态的当前使用的眼睛索引
        // 在编译期间明确指定，运行时不可改变
        static uint unity_StereoEyeIndex;

        // 如果启用单程立体渲染
    #elif defined(UNITY_SINGLE_PASS_STEREO)
        // 将当前使用的眼睛索引值定义为int类型，且是在常量缓冲区中的变量
        // 即该变量可以由CPU在运行期传递具体的数值去改变当前使用的眼睛索引
        GLOBAL_CBUFFER_START(UnityStereoEyeIndex)
        int unity_StereoEyeIndex;
        GLOBAL_CBUFFER_END
    #endif

    CBUFFER_START(UnityPerDrawRare)
    float4x4 glstate_matrix_transpose_modelview0;
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // ********** 每一帧由客户端引擎传递进来的逐帧数据 **********
    CBUFFER_START(UnityPerFrame)

    fixed4 glstate_lightmodel_ambient;
    fixed4 unity_AmbientSky;
    fixed4 unity_AmbientEquator;
    fixed4 unity_AmbientGround;
    fixed4 unity_IndirectSpecColor;

    #if !defined(USING_STEREO_MATRICES)
        // 如果没有定义使用立体渲染矩阵，unity_MartixV 等矩阵就是一个float4x4类型的矩阵
        float4x4 glstate_matrix_projection;
        float4x4 unity_MatrixV;                 // 当前摄像机所对应的观察矩阵
        float4x4 unity_MatrixInvV;
        float4x4 unity_MatrixVP;
        int unity_StereoEyeIndex;
    #endif

    fixed4 unity_ShadowColor;
    CBUFFER_END

    // ********** END **********
    // ----------------------------------------------------------------------------

    CBUFFER_START(UnityFog)
    fixed4 unity_FogColor;
    // x = density / sqrt(ln(2)), useful for Exp2 mode
    // y = density / ln(2), useful for Exp mode
    // z = -1/(end-start), useful for Linear mode
    // w = end/(end-start), useful for Linear mode
    float4 unity_FogParams;
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // Lightmaps

    // Main lightmap
    UNITY_DECLARE_TEX2D_HALF(unity_Lightmap);
    // Directional lightmap (always used with unity_Lightmap, so can share sampler)
    UNITY_DECLARE_TEX2D_NOSAMPLER_HALF(unity_LightmapInd);
    // Shadowmasks
    UNITY_DECLARE_TEX2D(unity_ShadowMask);

    // Dynamic GI lightmap
    UNITY_DECLARE_TEX2D(unity_DynamicLightmap);
    UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicDirectionality);
    UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicNormal);

    CBUFFER_START(UnityLightmaps)
    float4 unity_LightmapST;
    float4 unity_DynamicLightmapST;
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // Reflection Probes

    UNITY_DECLARE_TEXCUBE(unity_SpecCube0);
    UNITY_DECLARE_TEXCUBE_NOSAMPLER(unity_SpecCube1);

    CBUFFER_START(UnityReflectionProbes)
    float4 unity_SpecCube0_BoxMax;
    float4 unity_SpecCube0_BoxMin;
    float4 unity_SpecCube0_ProbePosition;
    half4  unity_SpecCube0_HDR;

    float4 unity_SpecCube1_BoxMax;
    float4 unity_SpecCube1_BoxMin;
    float4 unity_SpecCube1_ProbePosition;
    half4  unity_SpecCube1_HDR;
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // Light Probe Proxy Volume

    // UNITY_LIGHT_PROBE_PROXY_VOLUME is used as a shader keyword coming from tier settings and may be also disabled with nolppv pragma.
    // We need to convert it to 0/1 and doing a second check for safety.
    #ifdef UNITY_LIGHT_PROBE_PROXY_VOLUME
        #undef UNITY_LIGHT_PROBE_PROXY_VOLUME
        // Requires quite modern graphics support (3D float textures with filtering)
        // Note: Keep this in synch with the list from LightProbeProxyVolume::HasHardwareSupport && SurfaceCompiler::IsLPPVAvailableForAnyTargetPlatform
        #if !defined(UNITY_NO_LPPV) && (defined (SHADER_API_D3D11) || defined (SHADER_API_D3D12) || defined (SHADER_API_GLCORE) || defined (SHADER_API_XBOXONE) || defined (SHADER_API_PSSL) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_SWITCH))
            #define UNITY_LIGHT_PROBE_PROXY_VOLUME 1
        #else
            #define UNITY_LIGHT_PROBE_PROXY_VOLUME 0
        #endif
    #else
        #define UNITY_LIGHT_PROBE_PROXY_VOLUME 0
    #endif

    #if UNITY_LIGHT_PROBE_PROXY_VOLUME
        UNITY_DECLARE_TEX3D_FLOAT(unity_ProbeVolumeSH);

        CBUFFER_START(UnityProbeVolume)
        // x = Disabled(0)/Enabled(1)
        // y = Computation are done in global space(0) or local space(1)
        // z = Texel size on U texture coordinate
        float4 unity_ProbeVolumeParams;

        float4x4 unity_ProbeVolumeWorldToObject;
        float3 unity_ProbeVolumeSizeInv;
        float3 unity_ProbeVolumeMin;
        CBUFFER_END
    #endif

    static float4x4 unity_MatrixMVP = mul(unity_MatrixVP, unity_ObjectToWorld);
    static float4x4 unity_MatrixMV = mul(unity_MatrixV, unity_ObjectToWorld);
    static float4x4 unity_MatrixTMV = transpose(unity_MatrixMV);
    static float4x4 unity_MatrixITMV = transpose(mul(unity_WorldToObject, unity_MatrixInvV));
    // make them macros so that they can be redefined in UnityInstancing.cginc
    // 一系列用来进行变换操作的矩阵（一）
    #define UNITY_MATRIX_MVP    unity_MatrixMVP
    #define UNITY_MATRIX_MV     unity_MatrixMV
    #define UNITY_MATRIX_T_MV   unity_MatrixTMV
    #define UNITY_MATRIX_IT_MV  unity_MatrixITMV

    // ----------------------------------------------------------------------------
    //  Deprecated

    // There used to be fixed function-like texture matrices, defined as UNITY_MATRIX_TEXTUREn. These are gone now; and are just defined to identity.
    #define UNITY_MATRIX_TEXTURE0 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
    #define UNITY_MATRIX_TEXTURE1 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
    #define UNITY_MATRIX_TEXTURE2 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
    #define UNITY_MATRIX_TEXTURE3 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)

#endif
