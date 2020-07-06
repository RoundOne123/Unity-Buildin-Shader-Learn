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
    // ********** 与光照相关的工具函数和内置光源 **********
    CBUFFER_START(UnityLighting)

    #ifdef USING_DIRECTIONAL_LIGHT
        // x、y、z存储的有向平行光的方向向量
        half4 _WorldSpaceLightPos0;
    #else
        // x、y、z存储光源在世界空间中的位置坐标
        float4 _WorldSpaceLightPos0;
    #endif

    float4 _LightPositionRange; // xyz = pos, w = 1/range      // 光源位置 + 范围的倒数
    float4 _LightProjectionParams; // for point light projection: x = zfar / (znear - zfar), y = (znear * zfar) / (znear - zfar), z=shadow bias, w=shadow scale bias

    // 四个仅用在前向渲染途径的base pass中的非重要点光源的位置
    float4 unity_4LightPosX0;
    float4 unity_4LightPosY0;
    float4 unity_4LightPosZ0;
    // 与之对应的衰减
    half4 unity_4LightAtten0;

    // 8个光源的颜色、位置、衰减、照射方向
    half4 unity_LightColor[8];
    // 在观察空间点光源的位置（position, 1）或者有向平行光的（负）方向（-direction, 0）
    float4 unity_LightPosition[8]; // view-space vertex light positions (position,1), or (-direction,0) for directional lights.
    // x = cos(spotAngle/2) or -1 for non-spot      
    // y = 1/cos(spotAngle/4) or 1 for non-spot     // 原注释是错误的 正确的是：聚光灯1/4张角的余弦值减去其1/2张角的余弦值，如果该值不为0，则y为该差值的倒数，否则为1SHADOWS_SHADOWMASK
    // z = quadratic attenuation                    // 衰减公式的2次项系数
    // w = range*range                  
    // 光源的衰减信息
    half4 unity_LightAtten[8];
    // 观察空间的光源正前照射方向 如果不是聚光 -> (0,0,1,0)
    float4 unity_SpotDirection[8]; // view-space spot light directions, or (0,0,1,0) for non-spot

    // SH lighting environment
    // 球谐函数使用到的参数
    half4 unity_SHAr;       // 前三个分量对应于
    half4 unity_SHAg;
    half4 unity_SHAb;
    half4 unity_SHBr;
    half4 unity_SHBg;
    half4 unity_SHBb;
    half4 unity_SHC;

    // part of Light because it can be used outside of shadow distance
    // 光照探针相关的参数
    fixed4 unity_OcclusionMaskSelector;
    fixed4 unity_ProbesOcclusion;
    CBUFFER_END

    // 从4.0版本已经弃用，之所以保留是为了兼容使用了他们的着色器
    CBUFFER_START(UnityLightingOld)
    half3 unity_LightColor0, unity_LightColor1, unity_LightColor2, unity_LightColor3; // keeping those only for any existing shaders; remove in 4.0
    CBUFFER_END

    // ********** END **********
    // ----------------------------------------------------------------------------
    // ********** 与阴影相关的着色器常量缓冲区 **********

    CBUFFER_START(UnityShadows)
    // 用于构建层叠式阴影贴图时子视截体用到的包围球
    // 该数组中的4个元素存储了当前视截体分割成4个子视截体后，这些视截体的包围球
    // x、y、z、w分别存储了包围球的球心半径和坐标
    float4 unity_ShadowSplitSpheres[4];     
    // unity_ShadowSplitSpheres中四个包围球半径的平方
    float4 unity_ShadowSplitSqRadii;        
    // x分量表示产生阴影的光源的光源偏移值乘以的系数，这个光源偏移值对应于Light面板中的Bias属性。
    // 如果是聚光灯光源，所乘系数为1，如果是平行光，所乘系数为投影矩阵的第三行第三列的值的相反数。
    // y分量，如果是聚光灯光源时，为0，有向平行光时，为1。
    // z分量为解决阴影渗漏问题是，沿着物体表面法线移动的偏移量。
    // w分量为0。
    float4 unity_LightShadowBias;    
    // 对应于 Project Setting/Quality/Shadows面板中的cascade split属性里面，
    // 当把视截体分割成最多4个子视截体时，每个子视截体的近截平面的z值。       
    float4 _LightSplitsNear;
    // 分割成4个子视截体时，每个子视截体的远截平面的z值。
    float4 _LightSplitsFar;
    // 把某个坐标点从世界空间变换到阴影贴图空间的变换矩阵，
    // 如果使用层叠式阴影贴图数组，各元素就对应于层叠式贴图中每一个子视截体对应的阴影贴图，
    // 存储了从世界坐标变换到阴影贴图空间中的变换坐标（变换矩阵吧？）。
    // 阴影贴图空间 -> 层叠式阴影技术中，每一个子视截体所对应的阴影贴图所构建的空间。
    // 可以近似理解为一个由纹理映射坐标做成的坐标空间，坐标取值范围时[0, 1]。
    // 世界坐标 -> * 观察矩阵 * 投影矩阵 -> 裁剪空间坐标（[-1, 1]） * 贴图变换矩阵 -> 阴影贴图空间（[0, 1]）
    float4x4 unity_WorldToShadow[4];
    // x分量表示阴影强度，1表示全黑，0表示完全透明不黑
    // y分量暂未使用
    // 当z分量为1除以要渲染的阴影时，表示阴影离当前摄像机的最远距离值
    // w分量表示阴影离摄像机的最近距离值
    half4 _LightShadowData;
    // 阴影的中心和阴影的类型
    float4 unity_ShadowFadeCenterAndType;
    CBUFFER_END

    // ********** END **********
    // ----------------------------------------------------------------------------

    // 与逐帧绘制调用相关的着色器常量缓冲区
    CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;       // 把顶点从模型空间变换到世界空间
    float4x4 unity_WorldToObject;       // 把顶点从世界空间变换到模型空间
    float4 unity_LODFade; // x is the fade value ranging within [0,1]. y is x quantized into 16 levels
    // 该变量的w分量通常为1，当缩放变量为负数时，常被引擎赋值为-1
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

    // 与雾效果相关的常量缓冲区
    CBUFFER_START(UnityFog)
    fixed4 unity_FogColor;      // 雾的颜色
    // x = density / sqrt(ln(2)), useful for Exp2 mode      // 用于雾化因子指数平方衰减
    // y = density / ln(2), useful for Exp mode             // 用于雾化因子指数衰减
    // z = -1/(end-start), useful for Linear mode           // 用于雾化因子线性衰减
    // w = end/(end-start), useful for Linear mode          // 用于雾化因子线性衰减
    // 雾化的衰减因子相关信息
    float4 unity_FogParams;
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // Lightmaps

    // Main lightmap
    // 声明了主光照贴图，记录了直接照明下的光照信息
    UNITY_DECLARE_TEX2D_HALF(unity_Lightmap);
    // Directional lightmap (always used with unity_Lightmap, so can share sampler)
    // 声明了间接照明所产生的光照信息，因为unity_LightmapInd和unity_Lightmap搭配使用，所以不用另外专门声明采样器
    UNITY_DECLARE_TEX2D_NOSAMPLER_HALF(unity_LightmapInd);
    // Shadowmasks
    // 定义一个unity_ShadowMask纹理贴图
    UNITY_DECLARE_TEX2D(unity_ShadowMask);

    // Dynamic GI lightmap
    // 和全局光照贴图相关的变量
    UNITY_DECLARE_TEX2D(unity_DynamicLightmap);
    UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicDirectionality);
    UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicNormal);

    CBUFFER_START(UnityLightmaps)
    float4 unity_LightmapST;            // 用于静态光照贴图 tiling 和 offset
    float4 unity_DynamicLightmapST;     // 用于动态光照贴图 tiling 和 offset
    CBUFFER_END


    // ----------------------------------------------------------------------------
    // Reflection Probes  和反射探针相关的着色器变量
    
    UNITY_DECLARE_TEXCUBE(unity_SpecCube0);                 // 声明一个立方体贴图（在Direct3D 11或XBoxOne还会声明一个采样器变量）
    UNITY_DECLARE_TEXCUBE_NOSAMPLER(unity_SpecCube1);       // 声明立方体贴图纹理，但是不声明采样器变量

    CBUFFER_START(UnityReflectionProbes)
    // 反射探针的作用区域立方体试一个和世界坐标系坐标轴轴对齐的包围盒

    // x、y、z分量存储了该包围盒在x、y、z轴方向上的最大边界值
    float4 unity_SpecCube0_BoxMax;
    // ...最小边界值
    float4 unity_SpecCube0_BoxMin;
    // ReflectionProbe组件中的光照探针位置，由transform组件的Position属性和BoxOffset属性计算而来
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
