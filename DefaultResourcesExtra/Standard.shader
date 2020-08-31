// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        // 对应于 Inspector 面板中的 Alpha Cutoff 属性，当片元的 Alpha 值小于本值时，此片元将会被丢弃。
        // 此属性值只有当面板中的 Rendering Mode 属性设置为 Cutoff 时才能在面板上可视。
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        // 当 Inspector 面板中的 Metallic 属性未被赋上纹理贴图时，由滑杆控件所控制的 Smoothness 属性
        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        // 当 Inspector 面板中的 Metallic 属性赋上纹理贴图时，由滑杆控件所控制的 Smoothness 属性
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0

        // 对应于 Inspector 面板中的 Source 属性
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        // 当 Inspector 面板中 Metallic 属性未被赋上纹理贴图时，由滑杆控件所控制的Metallic属性
        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        // 当 Inspector 面板中 Metallic 属性赋上了纹理贴图时，所对应的 Metallic 属性
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        // Inspector 面板中的 Forward Rendering Options 标签下的 Specular Highlights 属性
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        // Inspector 面板中的 Forward Rendering Options 标签下的 Reflections 属性
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        // 当 Inspector 面板中的 Normal Map 属性被赋上了贴图之后，Normal Map 属性后的文本控件所对应的值
        _BumpScale("Scale", Float) = 1.0
        // 法线贴图
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        // 当 Inspector 面板中的 Height Map 属性被赋上了贴图之后，Height Map 属性后的文本控件所对应的值
        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        /*
        对应于 Inspector 面板中的 Height Map 属性，即视差贴图技术所用到的高度图。
        这个贴图在使用法线贴图的基础上，用来表现待渲染物体的高低位置信息。
        法线贴图只能表现光照强弱和明暗效果，而视差贴图可以增加待渲染物体的位置前后的细节。
        */ 
        _ParallaxMap ("Height Map", 2D) = "black" {}

        // 遮蔽贴图赋值后，Occlusion 属性后的文本控件对应的值
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        // 遮蔽贴图 -> 用于表示间接光照的不均匀的情况
        _OcclusionMap("Occlusion", 2D) = "white" {}

        // Emission 复选框勾选后，显示出来的Color属性对应的颜色选择框，表示材质的自发光颜色
        _EmissionColor("Color", Color) = (0,0,0)
        // 自发光贴图
        _EmissionMap("Emission", 2D) = "white" {}

        // 细节蒙版贴图
        _DetailMask("Detail Mask", 2D) = "white" {}

        // 第二张 反照率贴图
        // 对应于 Inspector 面板中的 Secondary Maps 标签下的 Detail Albedo x2 属性
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        // 对应于 Inspector 面板中的 Secondary Maps 标签下的 Normal Map 属性后的文本框控件值
        _DetailNormalMapScale("Scale", Float) = 1.0
        // 第二张法线贴图
        // 对应于 Inspector 面板中的 Secondary Maps 标签下的 Normal Map 属性
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

        // 第二套纹理的uv值，第一套应该在xxx.cginc文件中提供了
        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


        // Blending state
        // 混合状态 干吗用的？
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        // MetallicSetup 函数定义在 UnityStandardCore.cginc 文件中
        // MetallicSetup 表明本着色器将使用金属工作流
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG

    /*
    Standard.shader 文件由两个 SubShader 和一个 Fallback 组成。随着对硬件的性能要求依次递减。
    这里只分析第一个实现最复杂但性能要求最高的SubShader。
    ->
    第一个 SubShader 由 5 个渲染通路组成，分别是：
    基于前向渲染途径的前向通路，
    基于前向渲染途径的 FORWARD_DELTA 通路，（对应于 Light Mode 为 ForwardAdd ）
    基于阴影投射模式的 ShadowCaster 通道，
    基于延迟渲染途径的延迟通路，
    用于生成补偿材质间接光照中的镜面光照部分的 META 通路。
    */
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            // ForwardBase 模型用于前向渲染途径，
            // 该渲染通路会计算环境光、主有向平行光、逐顶点光照、球谐光照和光照贴图
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            // 支持 DirectX 9.0 的shader model 3.0
            // 不能完全支持OpenGL ES 2.0 所有设备，取决于硬件的实现
            #pragma target 3.0

            // -------------------------------------

            // Inspector 面板中的 NormalMap 属性若能使用，要声明此着色器变体
            #pragma shader_feature _NORMALMAP
            // 判定 Alpha测试、Alpha混合、Alpha预乘，如果三者都不启用，则执行下划线 _ 对应的代码段
            // 这里使用了 shader_feature_local 避免关键字 超出Unity的限制（256）
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            // Inspector 面板中的 Emission 属性若能使用，要声明此着色器变体
            #pragma shader_feature _EMISSION
            // Inspector 面板中的 Metallic 属性若能使用，要声明此着色器变体
            #pragma shader_feature_local _METALLICGLOSSMAP
            // Inspector 面板中的 Secondary Maps 标签下的两个属性若能使用,要声明此着色器多样体
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF

            // Inspector 面板中的 Height Map 属性若能使用，要声明此着色器变体
            #pragma shader_feature_local _PARALLAXMAP

            // 当使用了 forward rendering base 这一渲染途径时，
            // 这个指令通知把该渲染路径所依赖的所有着色器变体都编译
            #pragma multi_compile_fwdbase
            // 这个指令将会依据欲使用雾的不同类型（如是 linear 类型的还是 exponent 类型的雾），
            // 对应地把代码中和雾效相关的 shader变体 各自展开成 shader 代码
            #pragma multi_compile_fog
            // 这个指令把代码中和立化渲染技术相关的着色器变体各自展开成 shader 代码
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            // 取消注释以下行以启用 LOD 交叉淡入淡出效果。 注意：文件中还有其他注释需要取消注释。
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            // 指定在本渲染路径中的顶点、片元着色器的主函数入口
            #pragma vertex vertBase
            #pragma fragment fragBase
            // 包含定义上面两个函数的文件
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertDeferred
            #pragma fragment fragDeferred

            #include "UnityStandardCore.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 150

        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            // SM2.0: NOT SUPPORTED shader_feature_local _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP

            #pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP
            #pragma skip_variants SHADOWS_SOFT

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma skip_variants SHADOWS_SOFT
            #pragma multi_compile_shadowcaster

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }


    FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}
