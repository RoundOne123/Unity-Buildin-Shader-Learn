// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef AUTOLIGHT_INCLUDED
    #define AUTOLIGHT_INCLUDED

    #include "HLSLSupport.cginc"
    #include "UnityShadowLibrary.cginc"

    // ----------------
    //  Shadow helpers
    //  阴影和光照计算工具函数
    // ----------------

    // If none of the keywords are defined, assume directional?
    // 如果没有使用点光源和聚光灯光源，没有定义一个有向平行光光源，没有使用点 cookie 和有向平行光 cookie，
    // 则默认定义一个有向平行光
    #if !defined(POINT) && !defined(SPOT) && !defined(DIRECTIONAL) && !defined(POINT_COOKIE) && !defined(DIRECTIONAL_COOKIE)
        #define DIRECTIONAL
    #endif

    // ---- Screen space direction light shadows helpers (any version)
    // 如果在屏幕空间中处理阴影
    #if defined (SHADOWS_SCREEN)
        // 当屏幕空间层叠式阴影不启用
        // 引擎的 C#层代码有，BuiltinShaderDefine.UNITY_NO_SCREENSPACE_SHADOWS 对应控制设置
        #if defined(UNITY_NO_SCREENSPACE_SHADOWS)
            // 声明一个名为 _ShadowMapTexture 的阴影纹理贴图
            UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);

            /*
            // 把顶点从模型空间转换到世界空间；
            // 然后再从世界空间转换到阴影空间中，得到阴影空间中的坐标值，并赋值给a._ShadowCoord （这里的阴影空间是啥？灯光的投影空间？还是啥？）
            _ShadowCoord变量在代码段中有定义，是一个 unityShadowCoord4 （-> float4）类型的变量；
            SHADOW_COORDS 可以声明_ShadowCoord 变量绑定一个 TEXTCOORD 语义；
            */
            #define TRANSFER_SHADOW(a) a._ShadowCoord = mul( unity_WorldToShadow[0], mul( unity_ObjectToWorld, v.vertex ) );

            // 启用 UNITY_NO_SCREENSPACE_SHADOWS 时的版本
            inline fixed unitySampleShadow (unityShadowCoord4 shadowCoord)
            {
                // 内置了阴影比较采样器时 直接采样
                #if defined(SHADOWS_NATIVE)
                    // 直接用阴影空间中的坐标，采样纹理，作为shadow的值
                    fixed shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, shadowCoord.xyz);
                    // r分量表示阴影强度，1表示全黑，0表示完全透明不黑
                    shadow = _LightShadowData.r + shadow * (1-_LightShadowData.r);
                    return shadow;
                #else 
                    // 自己对比深度
                    // 贴图纹素中表示的深度值
                    unityShadowCoord dist = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, shadowCoord.xy);
                    // tegra is confused if we use _LightShadowData.x directly
                    // with "ambiguous overloaded function reference max(mediump float, float)"
                    /*
                    在 tegra 处理器上，如果直接把_LightShadowData.x 传给 Cg
                    库函数 max，会因为参数类型精度的问题而导致混乱和不精确，
                    所以在此要先把_LightShadowData.x 复制给一个 unityShadowCoord
                    类型变量 lightShadowDataX，然后传递给 max 函数
                    */
                    unityShadowCoord lightShadowDataX = _LightShadowData.x; // 阴影的强度，有多黑 [0,1]
                    // 当前片元的深度值
                    unityShadowCoord threshold = shadowCoord.z;
                    // 如果深度贴图中的深度值大于当前片元的深度值，表示当前片元在阴影之外，
                    // dist>threshold的值为 1，这时 max 函数返回的是 1      （注意！这里阴影之外会返回1）
                    // 如果深度贴图中的深度值小于当前片元的深度值，表示当前片元在阴影之内，
                    // dist>threshold的值为 0，这时 max 函数返回的值是 lightShadowDataX
                    return max(dist > threshold, lightShadowDataX);
                #endif
            }

        #else // UNITY_NO_SCREENSPACE_SHADOWS
            // 当前开启屏幕空间层叠式阴影  -> 基于屏幕空间的阴影 -> 直接采样相应的阴影纹理

            // 声明 _ShadowMapTexture 屏幕空间阴影纹理
            UNITY_DECLARE_SCREENSPACE_SHADOWMAP(_ShadowMapTexture);  // -> 定义在HLSLSupport.cginc 文件中
            // 限制裁剪空间的齐次坐标pos值（x、y分量变换到[0,pos.w]）
            // 将待处理片元变换到屏幕空间中
            #define TRANSFER_SHADOW(a) a._ShadowCoord = ComputeScreenPos(a.pos);
            inline fixed unitySampleShadow (unityShadowCoord4 shadowCoord)
            {
                // -> 定义在HLSLSupport.cginc 文件中
                fixed shadow = UNITY_SAMPLE_SCREEN_SHADOW(_ShadowMapTexture, shadowCoord);
                return shadow;
            }

        #endif

        //  SHADOW_COORDS 可以声明_ShadowCoord 变量绑定一个 TEXTCOORD 语义；
        #define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
        #define SHADOW_ATTENUATION(a) unitySampleShadow(a._ShadowCoord)
    #endif

    // -----------------------------
    //  Shadow helpers (5.6+ version)
    //  Unity3D 5.6 版本后的阴影和光照计算工具函数
    // -----------------------------
    // This version depends on having worldPos available in the fragment shader and using that to compute light coordinates.
    // if also supports ShadowMask (separately baked shadows for lightmapped objects)
    // 此版本取决于在片段着色器中是否有可用的worldPos并使用它来计算光坐标。
    // 如果还支持ShadowMask（为灯光映射的对象单独烘焙的阴影）

    /*
    本函数从Unity 5.6之后添加
    此版本的函数根据传递进来的使用的光照贴图坐标、某片元在世界空间下的坐标
    以及它所在的屏幕坐标，计算出该片元的阴影值为多少
    */
    half UnityComputeForwardShadows(float2 lightmapUV, float3 worldPos, float4 screenPos)
    {
        //fade value  阴影淡化值
        // UNITY_MATRIX_V：当前摄像机对应的观察矩阵
        // 片元到摄像机的向量，在摄像机观察空间的位置
        float zDist = dot(_WorldSpaceCameraPos - worldPos, UNITY_MATRIX_V[2].xyz);
        // 根据当前片元到摄像机的距离值和阴影的类型，计算淡化距离
        float fadeDist = UnityComputeShadowFadeDistance(worldPos, zDist);
        // 根据淡化距离，求得实时烘焙的阴影淡化值
        half  realtimeToBakedShadowFade = UnityComputeShadowFade(fadeDist);

        //baked occlusion if any
        // 返回烘焙中阴影的衰减值
        half shadowMaskAttenuation = UnitySampleBakedOcclusion(lightmapUV, worldPos);

        half realtimeShadowAttenuation = 1.0f;
        //directional realtime shadow
        // 计算主有向平行光产生的实时阴影 ，从中取得衰减值
        #if defined (SHADOWS_SCREEN)
            #if defined(UNITY_NO_SCREENSPACE_SHADOWS) && !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
                // 不是基于屏幕空间生成的阴影，光源空间下坐标对阴影贴图进行采样
                realtimeShadowAttenuation = unitySampleShadow(mul(unity_WorldToShadow[0], unityShadowCoord4(worldPos, 1)));
            #else
                // 在屏幕空间中进行采样

                //Only reached when LIGHTMAP_ON is NOT defined (and thus we use interpolator for screenPos rather than lightmap UVs). See HANDLE_SHADOWS_BLENDING_IN_GI below.
                // 仅当未定义LIGHTMAP_ON时才执行这里的代码
                //（因此我们将插值器用于screenPos，而不是lightmap UV。？？）
                // 请参阅下面的 HANDLE_SHADOWS_BLENDING_IN_GI 
                realtimeShadowAttenuation = unitySampleShadow(screenPos);
            #endif
        #endif

        // 动态分支 + 软阴影 + 不混合？？？ 时 使用 UNITY_BRANCH
        #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT) && !defined(LIGHTMAP_SHADOW_MIXING)
            //avoid expensive shadows fetches in the distance where coherency will be good
            // 使用 UNITY_BRANCH 分支，明确告诉着色器编译生成真正的动态分支功能，避免执行性能消耗较大的fetch操作
            UNITY_BRANCH
            if (realtimeToBakedShadowFade < (1.0f - 1e-2f))
            {
            #endif

            //spot realtime shadow
            // 就算聚光灯产生的实时阴影，从实时阴影贴图中取得衰减值
            #if (defined (SHADOWS_DEPTH) && defined (SPOT))
                // 计算采样用到的向量
                #if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
                    unityShadowCoord4 spotShadowCoord = mul(unity_WorldToShadow[0], unityShadowCoord4(worldPos, 1));
                #else
                    unityShadowCoord4 spotShadowCoord = screenPos;
                #endif
                // 采样到衰减值
                realtimeShadowAttenuation = UnitySampleShadowmap(spotShadowCoord);
            #endif

            //point realtime shadow
            // 计算点光源产生的实时阴影，从实时阴影中取得衰减值
            #if defined (SHADOWS_CUBE)
                realtimeShadowAttenuation = UnitySampleShadowmap(worldPos - _LightPositionRange.xyz);
            #endif

            #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT) && !defined(LIGHTMAP_SHADOW_MIXING)
            }
        #endif

        // 混合实时、阴影蒙版以及实时转烘焙的阴影值
        return UnityMixRealtimeAndBakedShadows(realtimeShadowAttenuation, shadowMaskAttenuation, realtimeToBakedShadowFade);
    }

    #if defined(SHADER_API_D3D11) || defined(SHADER_API_D3D12) || defined(SHADER_API_XBOXONE) || defined(SHADER_API_PSSL)
        #   define UNITY_SHADOW_W(_w) _w
    #else
        #   define UNITY_SHADOW_W(_w) (1.0/_w)
    #endif

    #if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
        #    define UNITY_READ_SHADOW_COORDS(input) 0
    #else
        #    define UNITY_READ_SHADOW_COORDS(input) READ_SHADOW_COORDS(input)
    #endif


    /// ****** 不同编译条件下的 UNITY SHADOW COORDS、UNITY TRANSFER SHADOW 和 UNITY SHADOW ATTENUATION 宏的定义 ******

    // 如果定义了在全局光照下进行阴影混合的宏，使用既有的 SHADOW_COORDS 宏、TRANSFER_SHADOW 宏、
    // SHADOW_ATTENUATION 宏对应定义一个需要带坐标的版本
    #if defined(HANDLE_SHADOWS_BLENDING_IN_GI) 
        // handles shadows in the depths of the GI function for performance reasons
        // 由于性能原因，处理GI函数的阴影in the depths？？
        #   define UNITY_SHADOW_COORDS(idx1) SHADOW_COORDS(idx1)
        #   define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)
        #   define UNITY_SHADOW_ATTENUATION(a, worldPos) SHADOW_ATTENUATION(a)
    #elif defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON) && !defined(UNITY_NO_SCREENSPACE_SHADOWS) 
        /*
        定义了屏幕空间处理阴影；
        且不使用贴图；
        没有使用层叠式屏幕空间阴影贴图；
        当有两个有向平行光时，主有向平行光在全局照明的相关代码中进行处理。第二个有向平行光在屏幕空间中进行阴影计算 ？？？why
        */
        // no lightmap uv thus store screenPos instead
        // can happen if we have two directional lights. main light gets handled in GI code, but 2nd dir light can have shadow screen and mask.
        // - Disabled on ES2 because WebGL 1.0 seems to have junk in .w (even though it shouldn't)

        // 如果使用了阴影蒙版，且不是在 D3D9 和 OpenGLES 平台下，那就从烘焙出来的光照贴图中取得阴影数据
        #   if defined(SHADOWS_SHADOWMASK) && !defined(SHADER_API_GLES)
        #       define UNITY_SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
                /*
                因为阴影是在屏幕空间中进行处理，所以阴影坐标的 x、y 分量就是光照贴图的 u、v 贴图坐标换算而来的。
                当 LIGHTMAP_ON 为 false 时才能进入代码此处，但 LIGHTMAP_ON 为 false 并不等于不能使用 unity_LightmapST
                */
        #       define UNITY_TRANSFER_SHADOW(a, coord) {a._ShadowCoord.xy = coord * unity_LightmapST.xy + unity_LightmapST.zw; a._ShadowCoord.zw = ComputeScreenPos(a.pos).xy;}
                // 计算衰减 转调 UnityComputeForwardShadows
        #       define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, worldPos, float4(a._ShadowCoord.zw, 0.0, UNITY_SHADOW_W(a.pos.w)));
        #   else
        #       define UNITY_SHADOW_COORDS(idx1) SHADOW_COORDS(idx1)
                // 如果不从主光照贴图 unity_LightmapST 中计算阴影坐标，就使用前文定义的 TRANSFER_SHADOW 计算
        #       define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)
        #       define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, a._ShadowCoord)
        #   endif
    #else   // 其它条件下
        #   define UNITY_SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
            // 如果使用阴影蒙版、那么根据光照图纹理uv坐标求出阴影坐标
        #   if defined(SHADOWS_SHADOWMASK)
        #       define UNITY_TRANSFER_SHADOW(a, coord) a._ShadowCoord.xy = coord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                // 如果使用立方体阴影，或者光探针代理体等有体积空间的阴影实现，需要把在世界空间中的坐标也传递进去
        #       if (defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE) || UNITY_LIGHT_PROBE_PROXY_VOLUME)
        #           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, worldPos, UNITY_READ_SHADOW_COORDS(a))
        #       else    // 否则worldPos的参数为0
        #           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, 0, 0)
        #       endif
        #   else    // 如果不使用阴影蒙版，就不用实现 TRANSFER_SHADOW 的操作
        #       if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
        #           define UNITY_TRANSFER_SHADOW(a, coord)
        #       else
        #           define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)
        #       endif
        #       if (defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE))
        #           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, UNITY_READ_SHADOW_COORDS(a))
        #       else
        #           if UNITY_LIGHT_PROBE_PROXY_VOLUME
        #               define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, UNITY_READ_SHADOW_COORDS(a))
        #           else
        #               define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, 0, 0)
        #           endif
        #       endif
        #   endif
    #endif

    #ifdef POINT
        // 存储点光源发出的光线在空间中各个位置值得衰减值纹理
        sampler2D_float _LightTexture0;
        // 世界空间到光源空间的变换矩阵
        unityShadowCoord4x4 unity_WorldToLight;

        // 计算点光源的光亮度衰减的宏
        #   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        // 把世界空间坐标变换到光源空间中
        unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
        // 求出该点的阴影衰减值
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        // 使用lightCoord 对 _LightTexture0进行采样 然后使用r分量与阴影衰减值相乘 的到最终光亮度的衰减值
        // ->
        // lightCoord 做一个和自身的点积操作，实质上就是计算出光源空间中位置点 lightCoord 到光源位置点的距离的平方；
        // 然后利用这个距离值重组（swizzle）出一个二维向量，用作衰减纹理的索引坐标
        fixed destName = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).r * shadow;
    #endif

    #ifdef SPOT
        sampler2D_float _LightTexture0;
        unityShadowCoord4x4 unity_WorldToLight;
        // 存储光亮度随着距离而衰减的信息的纹理
        sampler2D_float _LightTextureB0;

        // 处理和夹角有关的衰减值
        inline fixed UnitySpotCookie(unityShadowCoord4 LightCoord)
        {   
            // 这个0.5 出现的原因是为了把最终值控制在 [0,1] 范围内
            return tex2D(_LightTexture0, LightCoord.xy / LightCoord.w + 0.5).w;
        }

        // 根据数学原理，用距离值的平方作为衰减值纹理图的索引，求出光亮度衰减值
        inline fixed UnitySpotAttenuate(unityShadowCoord3 LightCoord)
        {
            return tex2D(_LightTextureB0, dot(LightCoord, LightCoord).xx).r;
        }

        #if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
            #define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1))
        #else
            #define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord4 lightCoord = input._LightCoord
        #endif

        // 计算聚光灯光源的光亮度衰减的宏
        #   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        // 计算出采样用的坐标
        DECLARE_LIGHT_COORD(input, worldPos); \
        // 采样出 阴影衰减
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        // 夹角导致的衰减 * 采样到的光亮度衰减 * 阴影衰减
        fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz) * shadow;
    #endif

    #ifdef DIRECTIONAL
        // 平行光光亮度的衰减
        // 平行光亮度不会随着 距离衰减，所以直接转调计算阴影产生的衰减效果即可
        #   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) fixed destName = UNITY_SHADOW_ATTENUATION(input, worldPos);
    #endif

    #ifdef POINT_COOKIE
        // 产生cookie效果的立方体纹理采样器，在Light组件中的Cookie属性项中指定
        samplerCUBE_float _LightTexture0;
        unityShadowCoord4x4 unity_WorldToLight;
        // 点光源光线亮度衰减值纹理图
        sampler2D_float _LightTextureB0;
            // 未定义 不要求片段着色器全浮点精度支持 由平台自动设置
        #   if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
        #       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz
        #   else
        #       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord3 lightCoord = input._LightCoord
        #   endif

        // 计算带cookie的点光源的光亮度衰减的宏
        #   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        // 计算采样用的坐标
        DECLARE_LIGHT_COORD(input, worldPos); \
        // 计算阴影衰减值
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        // 光亮度纹理衰减（距离引起的） * cookie的影响 * 阴影衰减的影响
        fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).r * texCUBE(_LightTexture0, lightCoord).w * shadow;
    #endif

    #ifdef DIRECTIONAL_COOKIE
        sampler2D_float _LightTexture0;     // 产生cookie效果的纹理采样器
        unityShadowCoord4x4 unity_WorldToLight;
        #   if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
        #       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy
        #   else
        #       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord2 lightCoord = input._LightCoord
        #   endif

        // 计算带cookie的有向平行光源的亮度衰减的宏
        #   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        // cookie 纹理 * 阴影纹理衰减
        fixed destName = tex2D(_LightTexture0, lightCoord).w * shadow;
    #endif


    // -----------------------------
    //  Light/Shadow helpers (4.x version)
    // -----------------------------
    // This version computes light coordinates in the vertex shader and passes them to the fragment shader.

    // ---- Spot light shadows
    #if defined (SHADOWS_DEPTH) && defined (SPOT)
        #define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
        #define TRANSFER_SHADOW(a) a._ShadowCoord = mul (unity_WorldToShadow[0], mul(unity_ObjectToWorld,v.vertex));
        #define SHADOW_ATTENUATION(a) UnitySampleShadowmap(a._ShadowCoord)
    #endif

    // ---- Point light shadows
    #if defined (SHADOWS_CUBE)
        #define SHADOW_COORDS(idx1) unityShadowCoord3 _ShadowCoord : TEXCOORD##idx1;
        #define TRANSFER_SHADOW(a) a._ShadowCoord.xyz = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz;
        #define SHADOW_ATTENUATION(a) UnitySampleShadowmap(a._ShadowCoord)
        #define READ_SHADOW_COORDS(a) unityShadowCoord4(a._ShadowCoord.xyz, 1.0)
    #endif

    // ---- Shadows off
    #if !defined (SHADOWS_SCREEN) && !defined (SHADOWS_DEPTH) && !defined (SHADOWS_CUBE)
        #define SHADOW_COORDS(idx1)
        #define TRANSFER_SHADOW(a)
        #define SHADOW_ATTENUATION(a) 1.0
        #define READ_SHADOW_COORDS(a) 0
    #else
        #ifndef READ_SHADOW_COORDS
            #define READ_SHADOW_COORDS(a) a._ShadowCoord
        #endif
    #endif

    #ifdef POINT
        #   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord3 _LightCoord : TEXCOORD##idx;
        #   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xyz;
        #   define LIGHT_ATTENUATION(a)    (tex2D(_LightTexture0, dot(a._LightCoord,a._LightCoord).rr).r * SHADOW_ATTENUATION(a))
    #endif

    #ifdef SPOT
        #   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord4 _LightCoord : TEXCOORD##idx;
        #   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex));
        #   define LIGHT_ATTENUATION(a)    ( (a._LightCoord.z > 0) * UnitySpotCookie(a._LightCoord) * UnitySpotAttenuate(a._LightCoord.xyz) * SHADOW_ATTENUATION(a) )
    #endif

    #ifdef DIRECTIONAL
        #   define DECLARE_LIGHT_COORDS(idx)
        #   define COMPUTE_LIGHT_COORDS(a)
        #   define LIGHT_ATTENUATION(a) SHADOW_ATTENUATION(a)
    #endif

    #ifdef POINT_COOKIE
        #   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord3 _LightCoord : TEXCOORD##idx;
        #   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xyz;
        #   define LIGHT_ATTENUATION(a)    (tex2D(_LightTextureB0, dot(a._LightCoord,a._LightCoord).rr).r * texCUBE(_LightTexture0, a._LightCoord).w * SHADOW_ATTENUATION(a))
    #endif

    #ifdef DIRECTIONAL_COOKIE
        #   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord2 _LightCoord : TEXCOORD##idx;
        #   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xy;
        #   define LIGHT_ATTENUATION(a)    (tex2D(_LightTexture0, a._LightCoord).w * SHADOW_ATTENUATION(a))
    #endif

    #define UNITY_LIGHTING_COORDS(idx1, idx2) DECLARE_LIGHT_COORDS(idx1) UNITY_SHADOW_COORDS(idx2)
    #define LIGHTING_COORDS(idx1, idx2) DECLARE_LIGHT_COORDS(idx1) SHADOW_COORDS(idx2)
    #define UNITY_TRANSFER_LIGHTING(a, coord) COMPUTE_LIGHT_COORDS(a) UNITY_TRANSFER_SHADOW(a, coord)
    #define TRANSFER_VERTEX_TO_FRAGMENT(a) COMPUTE_LIGHT_COORDS(a) TRANSFER_SHADOW(a)

#endif
