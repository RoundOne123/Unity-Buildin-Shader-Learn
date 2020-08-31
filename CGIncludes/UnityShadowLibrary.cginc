// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED
    #define UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED

    // Shadowmap helpers.
    // 根据宏SHADOWS_SCREEN 和 LIGHTMAP_ON 是否启用决定是否在全局照明系统下对阴影进行混合处理
    // SHADOWS_SCREEN：本质上着色器多样体，表示是否在品目空间中处理阴影计算
    #if defined( SHADOWS_SCREEN ) && defined( LIGHTMAP_ON )
        #define HANDLE_SHADOWS_BLENDING_IN_GI 1
    #endif

    #define unityShadowCoord float
    #define unityShadowCoord2 float2
    #define unityShadowCoord3 float3
    #define unityShadowCoord4 float4
    #define unityShadowCoord4x4 float4x4

    half    UnitySampleShadowmap_PCF7x7(float4 coord, float3 receiverPlaneDepthBias);   // Samples the shadowmap based on PCF filtering (7x7 kernel)
    half    UnitySampleShadowmap_PCF5x5(float4 coord, float3 receiverPlaneDepthBias);   // Samples the shadowmap based on PCF filtering (5x5 kernel)
    half    UnitySampleShadowmap_PCF3x3(float4 coord, float3 receiverPlaneDepthBias);   // Samples the shadowmap based on PCF filtering (3x3 kernel)
    float3  UnityGetReceiverPlaneDepthBias(float3 shadowCoord, float biasbiasMultiply); // Receiver plane depth bias

    /*
    Unity会根据不同类型的光源，用不同的计算方式对应计算所产生的阴影
    */


    // ------------------------------------------------------------------
    // Spot light shadows
    // 聚光灯的阴影
    // ------------------------------------------------------------------

    // 如果定义了 SPOT 则表示使用聚光灯的阴影计算方式计算阴影
    #if defined (SHADOWS_DEPTH) && defined (SPOT)

        // declare shadowmap
        // 如果没有声明shadowmap，则声明一个阴影贴图纹理_ShadowMapTexture
        #if !defined(SHADOWMAPSAMPLER_DEFINED)
            // 这个深度纹理贴图 _ShadowMapTexture 哪个空间的？
            // 光源空间的？还是摄像机的裁剪空间的？
            UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
            #define SHADOWMAPSAMPLER_DEFINED
        #endif

        // shadow sampling offsets and texel size
        // 如果启用了软阴影效果
        // 则定义阴影纹理贴图的偏移量和纹素的大小
        #if defined (SHADOWS_SOFT)
            float4 _ShadowOffsets[4];   //柔化阴影的四个偏移采样点
            float4 _ShadowMapTexture_TexelSize;
            #define SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED
        #endif

        // 根据给定的阴影纹理坐标，采样阴影深度贴图，获取对应的贴图纹素代表的【深度值】
        // _ShadowMapTexture代表的是哪个空间的深度？
        inline fixed UnitySampleShadowmap (float4 shadowCoord)
        {
            // 开启软阴影效果
            #if defined (SHADOWS_SOFT)
                // shadow是什么？阴影纹理对应得深度值？
                // 默认为1，表示在阴影中还是不在阴影中？
                half shadow = 1;

                // No hardware comparison sampler (ie some mobile + xbox360) : simple 4 tap PCF
                // 没有硬件比较采样器时（某些移动设备+xbox360） -> 进行简单的4点PCF
                #if !defined (SHADOWS_NATIVE)
                    // 将纹理坐标转化到 NDC坐标上执行
                    float3 coord = shadowCoord.xyz / shadowCoord.w;
                    float4 shadowVals;
                    // 获取四个偏移采样点的深度值，存储到shadowVals中
                    shadowVals.x = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, coord + _ShadowOffsets[0].xy);
                    shadowVals.y = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, coord + _ShadowOffsets[1].xy);
                    shadowVals.z = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, coord + _ShadowOffsets[2].xy);
                    shadowVals.w = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, coord + _ShadowOffsets[3].xy);
                    // 如果本采样点四周的4个采样点的z值都小于阴影贴图采样点的z值，就表明该点不处于阴影区域
                    // _LightShadowData的r分量，即x分量表示阴影的强度值
                    // 感觉这里不对吧 应该是 -> （具体是哪个，现在无法确定）
                    // 这里应该是 四个采样点的值（深度）都小于给定坐标的NDC空间的z分量（深度），
                    // 表明给定的点在阴影中，阴影强度是_LightShadowData.r
                    half4 shadows = (shadowVals < coord.zzzz) ? _LightShadowData.rrrr : 1.0f;
                    // 阴影值为本采样点四周的4个采样点的阴影值得平均值
                    shadow = dot(shadows, 0.25f);
                #else
                    // Mobile with comparison sampler : 4-tap linear comparison filter
                    // 移动端使用硬件比较采样器：4抽头线性比较滤波器
                    #if defined(SHADER_API_MOBILE)
                        float3 coord = shadowCoord.xyz / shadowCoord.w;
                        half4 shadows;
                        shadows.x = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[0]);
                        shadows.y = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[1]);
                        shadows.z = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[2]);
                        shadows.w = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, coord + _ShadowOffsets[3]);
                        // 这里直接取得采样值的平均值，
                        shadow = dot(shadows, 0.25f);
                        // Everything else
                    #else
                        // 其他未特别声明的平台中 （非移动平台 + 使用了硬件比较采样器？）
                        // 转调UnityGetReceiverPlaneDepthBias、UnitySampleShadowmap_PCF3x3
                        float3 coord = shadowCoord.xyz / shadowCoord.w;
                        float3 receiverPlaneDepthBias = UnityGetReceiverPlaneDepthBias(coord, 1.0f);
                        shadow = UnitySampleShadowmap_PCF3x3(float4(coord, 1), receiverPlaneDepthBias);
                    #endif
                    // 在_lightShadowData.r 与 1.0之间进行插值
                    shadow = lerp(_LightShadowData.r, 1.0f, shadow);
                #endif
            #else   // 未开启软阴影效果
                // 1-tap shadows
                #if defined (SHADOWS_NATIVE)
                    // 使用着色器内置的阴影操作函数
                    half shadow = UNITY_SAMPLE_SHADOW_PROJ(_ShadowMapTexture, shadowCoord);
                    // 插值
                    shadow = lerp(_LightShadowData.r, 1.0f, shadow);
                #else
                    // 没有着色器内建的阴影操作函数，直接比较当前判断点的z值和阴影值，然后返回
                    half shadow = SAMPLE_DEPTH_TEXTURE_PROJ(_ShadowMapTexture, UNITY_PROJ_COORD(shadowCoord)) < (shadowCoord.z / shadowCoord.w) ? _LightShadowData.r : 1.0;
                #endif
            #endif

            return shadow;
        }

    #endif // #if defined (SHADOWS_DEPTH) && defined (SPOT)

    // ------------------------------------------------------------------
    // Point light shadows
    // 点光源生成的阴影
    // 点光源生成的阴影，其阴影深度贴图存储在一个立方体纹理中，
    // 贴图中某一点纹素存储的深度值，即某处离光源最远且光线能照射到的位置的深度值（能照射到的最远，就是全部透明情况下最近的，这个描述太抽象）
    // ------------------------------------------------------------------

    // 启用 SHADOWS_CUBE，使用点光源生成阴影
    #if defined (SHADOWS_CUBE)

        // 当支持深度格式的立方体纹理
        #if defined(SHADOWS_CUBE_IN_DEPTH_TEX)
            // 声明一个立方体阴影纹理贴图
            UNITY_DECLARE_TEXCUBE_SHADOWMAP(_ShadowMapTexture);
        #else
            // 声明一个立方体纹理贴图
            UNITY_DECLARE_TEXCUBE(_ShadowMapTexture);
            // 同时定义一个函数
            // vec是从原点触发，指向立方体上某点位置的连线向量，用于立方体纹理的贴图的采样
            inline float SampleCubeDistance (float3 vec)
            {
                // 采样_ShadowMapTexture的vec处的深度值，xxx_LOD 会根据不同的mipmap进行不同精度的采样
                // 并把一个float4类型的阴影深度值，解码到一个float的浮点数中
                return UnityDecodeCubeShadowDepth(UNITY_SAMPLE_TEXCUBE_LOD(_ShadowMapTexture, vec, 0));
            }
        #endif

        // 上面是定义了 纹理贴图 / （阴影纹理贴图 + 定义了个采样立方体纹理的函数）
        // -> 接下来如何操作呢？

        // vec：当前待判断是否在阴影中的片元在光源空间中的坐标
        inline half UnitySampleShadowmap (float3 vec)
        {
            // 支持深度格式的立方体纹理
            #if defined(SHADOWS_CUBE_IN_DEPTH_TEX)
                // 这一部分其实是没看太懂的....

                // 取绝对值
                float3 absVec = abs(vec);
                // 取最大的分量
                float dominantAxis = max(max(absVec.x, absVec.y), absVec.z); // TODO use max3() instead
                // 应用阴影偏移
                // .z分量为shadow bias
                // 0.00001 是相当于近平面一样的作用吗？
                dominantAxis = max(0.00001, dominantAxis - _LightProjectionParams.z); // shadow bias from point light is apllied here.
                // 乘 w分量表示的shadow scale bias
                dominantAxis *= _LightProjectionParams.w; // bias
                // 将 dominantAxis 投影 到阴影贴图的裁剪空间[0, 1]
                // mydist这里的话就是取最小的了
                float mydist = -_LightProjectionParams.x + _LightProjectionParams.y/dominantAxis; // project to shadow map clip space [0; 1]

                // 反转z
                #if defined(UNITY_REVERSED_Z)
                    mydist = 1.0 - mydist; // depth buffers are reversed! Additionally we can move this to CPP code!
                #endif
            #else
                // 长度 * 光源范围的倒数 （光源范围就对应了 光源的视截体吧）
                float mydist = length(vec) * _LightPositionRange.w;
                // *shadow scale bias
                mydist *= _LightProjectionParams.w; // bias
            #endif
            
            // 上面就根据传入的参数vec，算出不同情况下所需要的深度值mydist
            // 不同的平台、条件、设置下 深度的计算方式可能不太一样，所以要对应计算出用于比较的深度mydist

            // 软阴影
            #if defined (SHADOWS_SOFT)
                float z = 1.0/128.0;    // 偏移的大小
                float4 shadowVals;
                // No hardware comparison sampler (ie some mobile + xbox360) : simple 4 tap PCF
                // 没有硬件比较采样器（某些移动设备 + xbox360）-> 采用简单的4点PCF
                #if defined (SHADOWS_CUBE_IN_DEPTH_TEX)
                    // 从四个4采样点采样立方体阴影纹理
                    shadowVals.x = UNITY_SAMPLE_TEXCUBE_SHADOW(_ShadowMapTexture, float4(vec+float3( z, z, z), mydist));
                    shadowVals.y = UNITY_SAMPLE_TEXCUBE_SHADOW(_ShadowMapTexture, float4(vec+float3(-z,-z, z), mydist));
                    shadowVals.z = UNITY_SAMPLE_TEXCUBE_SHADOW(_ShadowMapTexture, float4(vec+float3(-z, z,-z), mydist));
                    shadowVals.w = UNITY_SAMPLE_TEXCUBE_SHADOW(_ShadowMapTexture, float4(vec+float3( z,-z,-z), mydist));
                    // 求平均值
                    half shadow = dot(shadowVals, 0.25);
                    // 插值阴影强度
                    return lerp(_LightShadowData.r, 1.0, shadow);
                #else
                    shadowVals.x = SampleCubeDistance (vec+float3( z, z, z));
                    shadowVals.y = SampleCubeDistance (vec+float3(-z,-z, z));
                    shadowVals.z = SampleCubeDistance (vec+float3(-z, z,-z));
                    shadowVals.w = SampleCubeDistance (vec+float3( z,-z,-z));
                    // 如果四个采样点的深度值小于当前片元的深度值，在阴影中，取出表示阴影强度的r分量
                    half4 shadows = (shadowVals < mydist.xxxx) ? _LightShadowData.rrrr : 1.0f;
                    // 求平均值
                    return dot(shadows, 0.25);
                #endif
            #else       // 未启用柔和（软）阴影
                // 使用立体深度纹理贴图
                #if defined (SHADOWS_CUBE_IN_DEPTH_TEX)
                    // 采样纹理中的深度
                    half shadow = UNITY_SAMPLE_TEXCUBE_SHADOW(_ShadowMapTexture, float4(vec, mydist));
                    // 进行插值
                    return lerp(_LightShadowData.r, 1.0, shadow);
                #else
                    // 采样纹理的深度 -> 解码为float
                    half shadowVal = UnityDecodeCubeShadowDepth(UNITY_SAMPLE_TEXCUBE(_ShadowMapTexture, vec));
                    // 比较后获得最终的阴影强度
                    half shadow = shadowVal < mydist ? _LightShadowData.r : 1.0;
                    return shadow;
                #endif
            #endif

        }
    #endif // #if defined (SHADOWS_CUBE)


    // ------------------------------------------------------------------
    // Baked shadows
    // 预烘焙的阴影计算
    // ------------------------------------------------------------------

    // 使用了光照探针的情况下才能使用本函数
    #if UNITY_LIGHT_PROBE_PROXY_VOLUME

        // 这个方法是做什么的？计算衰减？
        half4 LPPV_SampleProbeOcclusion(float3 worldPos)
        {
            const float transformToLocal = unity_ProbeVolumeParams.y;
            const float texelSizeX = unity_ProbeVolumeParams.z;

            //The SH coefficients textures and probe occlusion are packed into 1 atlas.
            // SH系数纹理和探针遮挡打包成1个图集 -> 详见7.7.5节中关于从纹理中取得纹素并解码的部分
            //-------------------------
            //| ShR | ShG | ShB | Occ |
            //-------------------------

            // 判断是在世界空间还是在局部空间中进行计算
            float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz : worldPos;

            //Get a tex coord between 0 and 1
            // unity_ProbeVolumeSizeInv.xyz：分别表示光探针代理体的长宽高方向上的纹素个数
            // 获得本位置点对应的纹理映射坐标
            float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;

            // Sample fourth texture in the atlas
            // We need to compute proper U coordinate to sample.
            // Clamp the coordinate otherwize we'll have leaking between ShB coefficients and Probe Occlusion(Occ) info
            // 在atlas中采样第四个纹理
            // 我们需要计算适当的U坐标进行采样。
            // 夹紧坐标否则将在ShB系数和Probe Occlusion（Occ）信息之间泄漏
            texCoord.x = max(texCoord.x * 0.25f + 0.75f, 0.75f + 0.5f * texelSizeX);

            return UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);
        }

    #endif //#if UNITY_LIGHT_PROBE_PROXY_VOLUME

    // ------------------------------------------------------------------
    // Used by the forward rendering path
    // 前向渲染中被使用
    // --> 用于返回烘焙的阴影的衰减值
    // lightmapUV：光照贴图的UV坐标
    // worldPos：待处理的片元在世界坐标系上的位置点
    fixed UnitySampleBakedOcclusion (float2 lightmapUV, float3 worldPos)
    {

        // rawOcclusionMask：记录的是该像素，被灯光影响的情况，如果采样的结果是（1，1，0，1）那么表示这个像素，
        // 被0、1、3号灯照射到了，但是2号灯，不能照射到
        // unity_OcclusionMaskSelector记录的是最强的灯光的编号

        // 如果启动了阴影蒙版
        #if defined (SHADOWS_SHADOWMASK)
            #if defined(LIGHTMAP_ON)
                // 如果启动了光照贴图，则从光照贴图中提取遮蔽蒙版信息（这是个啥）
                fixed4 rawOcclusionMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
            #else
                fixed4 rawOcclusionMask = fixed4(1.0, 1.0, 1.0, 1.0);
                // 如果启用了光照探针
                #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                    // 启用了光照探针代理体
                    if (unity_ProbeVolumeParams.x == 1.0)   
                    // 从位置点 worldPos 所处的光探针代理体处取得此处的原始遮蔽信息
                    rawOcclusionMask = LPPV_SampleProbeOcclusion(worldPos);
                    else
                    // 否则就仍从阴影蒙版贴图中取得遮蔽信息
                    rawOcclusionMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
                #else
                    rawOcclusionMask = UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
                #endif
            #endif
            // 这里是根据记录的灯光编号筛选灯光的？
            return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));

        #else

            //In forward dynamic objects can only get baked occlusion from LPPV, light probe occlusion is done on the CPU by attenuating the light color.
            //在forward的动态对象只能从LPPV进行烘焙遮挡的情况下，通过减弱光的颜色在CPU上完成光探针遮挡。
            fixed atten = 1.0f;
            #if defined(UNITY_INSTANCING_ENABLED) && defined(UNITY_USE_SHCOEFFS_ARRAYS)
                // ...unless we are doing instancing, and the attenuation is packed into SHC array's .w component.
                // ...除非我们正在执行实例化，并且衰减被打包到SHC阵列的.w分量中。
                atten = unity_SHC.w;
            #endif

            #if UNITY_LIGHT_PROBE_PROXY_VOLUME && !defined(LIGHTMAP_ON) && !UNITY_STANDARD_SIMPLE
                fixed4 rawOcclusionMask = atten.xxxx;
                if (unity_ProbeVolumeParams.x == 1.0)   // 启用
                rawOcclusionMask = LPPV_SampleProbeOcclusion(worldPos);
                // unity_OcclusionMaskSelector：用来控制当前渲染的光源中那些通道可用
                // 阴影蒙版中的每一个纹素中，存储着它对应场景某个位置点上至多4个光源在此的遮挡信息
                // 即记录着这一点中有多少个光源能照的到，多少个光源照不到的信息
                // dot 操作 unity_OcclusionMaskSelector 就是用来控制这些遮挡信息
                return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));
            #endif

            return atten;
        #endif
    }

    // ------------------------------------------------------------------
    // Used by the deferred rendering path (in the gbuffer pass)
    // 在延迟渲染的GBuffer中使用
    // 和 UnitySampleBakedOcclusion 功能相似，不同之处在于它没有使用 unity_OcclusionMaskSelector 变量选择其中的通道
    fixed4 UnityGetRawBakedOcclusions(float2 lightmapUV, float3 worldPos)
    {
        #if defined (SHADOWS_SHADOWMASK)
            #if defined(LIGHTMAP_ON)
                return UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
            #else
                // unity_ProbesOcclusion ：在UnityShaderVariables.cginc文件中定义，
                // 通过C#层提供的API：MaterialPropertyBlock.CopyProbeOcculusionArrayFrom，可以从客户端填充此值
                half4 probeOcclusion = unity_ProbesOcclusion;

                #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                    if (unity_ProbeVolumeParams.x == 1.0)
                    probeOcclusion = LPPV_SampleProbeOcclusion(worldPos);
                #endif

                return probeOcclusion;
            #endif
        #else
            return fixed4(1.0, 1.0, 1.0, 1.0);
        #endif
    }

    // ------------------------------------------------------------------
    // Used by both the forward and the deferred rendering path
    // 可用于前向渲染路径和延迟渲染路径
    // 可以对实时阴影和烘焙阴影进行混合 --> 最终返回值，是用于和当前阴影相乘的类似强度一样的概念？
    // 主要算法思想是：按照平常的做法衰减实时阴影，然后取其和烘焙阴影的最小值
    half UnityMixRealtimeAndBakedShadows(half realtimeShadowAttenuation, half bakedShadowAttenuation, half fade)
    {
        // -- Static objects 静态物体 --
        // FWD BASE PASS    前向渲染 base
        // ShadowMask mode          = LIGHTMAP_ON + SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = LIGHTMAP_ON + SHADOWS_SHADOWMASK
        // Subtractive mode         = LIGHTMAP_ON + LIGHTMAP_SHADOW_MIXING
        // Pure realtime direct lit = LIGHTMAP_ON

        // FWD ADD PASS     前向渲染 add
        // ShadowMask mode          = SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = SHADOWS_SHADOWMASK
        // Pure realtime direct lit = LIGHTMAP_ON

        // DEFERRED LIGHTING PASS   延迟光照
        // ShadowMask mode          = LIGHTMAP_ON + SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = LIGHTMAP_ON + SHADOWS_SHADOWMASK
        // Pure realtime direct lit = LIGHTMAP_ON

        // -- Dynamic objects 动态物体 --
        // FWD BASE PASS + FWD ADD ASS      前向渲染
        // ShadowMask mode          = LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = N/A
        // Subtractive mode         = LIGHTMAP_SHADOW_MIXING (only matter for LPPV. Light probes occlusion being done on CPU)
        // Pure realtime direct lit = N/A

        // DEFERRED LIGHTING PASS           延迟光照
        // ShadowMask mode          = SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = SHADOWS_SHADOWMASK
        // Pure realtime direct lit = N/A

        // 如果基于深度贴图的阴影、基于屏幕空间的阴影、基于立方体纹理的阴影这三者都没有打开
        #if !defined(SHADOWS_DEPTH) && !defined(SHADOWS_SCREEN) && !defined(SHADOWS_CUBE)
            #if defined(LIGHTMAP_ON) && defined (LIGHTMAP_SHADOW_MIXING) && !defined (SHADOWS_SHADOWMASK)
                // 如果没有使用蒙版阴影
                //In subtractive mode when there is no shadow we kill the light contribution as direct as been baked in the lightmap.
                // 在 subtractive 模式，当没有阴影时，我们将消除光照贡献，使得就像直接在光照贴图中烘焙的一样
                return 0.0;
            #else
                // 使用了阴影蒙版，直接返回预烘焙的衰减值
                return bakedShadowAttenuation;
            #endif
        #endif

        #if (SHADER_TARGET <= 20) || UNITY_STANDARD_SIMPLE
            //no fading nor blending on SM 2.0 because of instruction count limit.
            // 如果shade model不大于2.0，则不进行 fading（衰减？淡出更合理吧） 或者 blending操作
            #if defined(SHADOWS_SHADOWMASK) || defined(LIGHTMAP_SHADOW_MIXING)
                // 取实时阴影和烘焙阴影的最小值
                return min(realtimeShadowAttenuation, bakedShadowAttenuation);
            #else
                // 直接返回实时阴影的衰减值
                return realtimeShadowAttenuation;
            #endif
        #endif

        #if defined(LIGHTMAP_SHADOW_MIXING)
            //Subtractive or shadowmask mode
            // 实时阴影 + fade（淡化参数）后，将它限制在[0,1]范围内
            realtimeShadowAttenuation = saturate(realtimeShadowAttenuation + fade);
            // 然后将它和预烘焙阴影衰减值进行比较，返回较小值
            return min(realtimeShadowAttenuation, bakedShadowAttenuation);
        #endif

        //In distance shadowmask or realtime shadow fadeout we lerp toward the baked shadows (bakedShadowAttenuation will be 1 if no baked shadows)
        // 在远距离阴影遮罩或实时阴影淡出中，我们朝着烘焙的阴影方向进行插值（如果没有烘焙的阴影，bakedShadowAttenuation将为1）
        // 根据淡化参数在实时阴影衰减值和预烘焙阴影衰减值之间进行线性插值
        return lerp(realtimeShadowAttenuation, bakedShadowAttenuation, fade);
    }

    // ------------------------------------------------------------------
    // Shadow fade
    // 阴影淡化的处理
    // ------------------------------------------------------------------

    // 根据当前片元到摄像机的距离值，计算阴影的淡化程度
    // wpos：待计算的当前片元在世界坐标系下的位置坐标值
    // z：待计算的当前片元在世界坐标系下到当前摄像机的距离
    float UnityComputeShadowFadeDistance(float3 wpos, float z)
    {
        // unity_ShadowFadeCenterAndType ：包含了阴影的中心和阴影的类型

        // 计算距离
        float sphereDist = distance(wpos, unity_ShadowFadeCenterAndType.xyz);
        // 使用w分量进行插值，w分量是啥？0或1 
        return lerp(z, sphereDist, unity_ShadowFadeCenterAndType.w);
    }

    // ------------------------------------------------------------------
    // 计算阴影淡化程度
    half UnityComputeShadowFade(float fadeDist)
    {
        // _LightShadowData 的各分量 书上的解释，不一定正确，具体可以查看一下网上的资料
        // x：表示阴影的强度，1表示全黑，0表示完全透明不黑
        // y：暂时未被使用
        // z：当z分量为1除以需要渲染的阴影时，表示阴影离当前摄像机的最远距离值
        // w：表示阴影离摄像机的最近距离值
        return saturate(fadeDist * _LightShadowData.z + _LightShadowData.w);
    }


    // ------------------------------------------------------------------
    //  Bias
    // ------------------------------------------------------------------

    /**
    * Computes the receiver plane depth bias for the given shadow coord in screen space.
    * Inspirations:
    *   http://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
    *   http://amd-dev.wpengine.netdna-cdn.com/wordpress/media/2012/10/Isidoro-ShadowMapping.pdf
    */
    // 根据给定的在屏幕空间的阴影坐标值，计算【阴影接受平面】的深度偏移值
    float3 UnityGetReceiverPlaneDepthBias(float3 shadowCoord, float biasMultiply)
    {
        // Should receiver plane bias be used? This estimates receiver slope using derivatives,
        // and tries to tilt the PCF kernel along it. However, when doing it in screenspace from the depth texture
        // (ie all light in deferred and directional light in both forward and deferred), the derivatives are wrong
        // on edges or intersections of objects, leading to shadow artifacts. Thus it is disabled by default.
        /*
        是否应使用接收器平面偏置？ 这使用导数估算接收器的斜率，并尝试使PCF内核沿其倾斜。
        但是，当从深度纹理在屏幕空间中进行操作时（即，所有延迟和定向光都在正向和延迟中），
        导数在对象的边缘或相交处是错误的，从而导致阴影伪影。 因此，默认情况下它是禁用的。
        */
        float3 biasUVZ = 0;

        /*
        现代 GPU 为了提高效率，会同时对至少 4 个片元进行并行处理。而且这 4 个片元一般以 2×2 的方式组织排列。
        在实际计算中，计算某一片元与它水平（或垂直）方向上的邻接片元的属性（如它的纹理坐标）的一阶差分值，
        便可以近似等于该片元在水平（或垂直）方向上的【导数】。这个计算水平（或垂直）一阶差分值（或者称导数值），
        在 Cg/HLSL 平台上用 ddx[2]（或 ddy）函数计算，在 GLSL 平台上用 dFdx（或 dFdy）函数计算。
        因为 ddx/ddy（或 dFdx/dFdy）函数需要用到片元的属性，因此只能在片元着色器中使用它们。
        */
        #if defined(UNITY_USE_RECEIVER_PLANE_BIAS) && defined(SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED)
            // 得到当前纹理坐标点与水平方向的邻居坐标点
            float3 dx = ddx(shadowCoord);   // 计算水平方向 shadowCoord 的一阶差分值，近似等于该片元在水平方向上的导数
            float3 dy = ddy(shadowCoord);

            biasUVZ.x = dy.y * dx.z - dx.y * dy.z;
            biasUVZ.y = dx.x * dy.z - dy.x * dx.z;
            biasUVZ.xy *= biasMultiply / ((dx.x * dy.y) - (dx.y * dy.x));

            // Static depth biasing to make up for incorrect fractional sampling on the shadow map grid.
            // 静态深度偏差可弥补阴影贴图网格上不正确的分数采样
            const float UNITY_RECEIVER_PLANE_MIN_FRACTIONAL_ERROR = 0.01f;
            float fractionalSamplingError = dot(_ShadowMapTexture_TexelSize.xy, abs(biasUVZ.xy));
            biasUVZ.z = -min(fractionalSamplingError, UNITY_RECEIVER_PLANE_MIN_FRACTIONAL_ERROR);
            #if defined(UNITY_REVERSED_Z)
                biasUVZ.z *= -1;
            #endif
        #endif

        return biasUVZ;
    }

    /**
    * Combines the different components of a shadow coordinate and returns the final coordinate.
    * See UnityGetReceiverPlaneDepthBias
    */
    // 组合一个阴影坐标的不同分量并返回最后一下分量
    // baseUV：本采样点对应的阴影贴图uv坐标
    // deltaUV：本采样点对应的uv左边的偏移量
    // depth：本采样点存储的深度值
    // receiverPlaneDepthBias：接受阴影投射的平面的深度偏差值
    float3 UnityCombineShadowcoordComponents(float2 baseUV, float2 deltaUV, float depth, float3 receiverPlaneDepthBias)
    {
        // 阴影贴图的 uv 采样坐标，还有对应的深度值都加上偏移值
        float3 uv = float3(baseUV + deltaUV, depth + receiverPlaneDepthBias.z);
        uv.z += dot(deltaUV, receiverPlaneDepthBias.xy);
        return uv;
    }

    // ------------------------------------------------------------------
    //  PCF Filtering helpers
    //  用于进行PCF过滤的辅助函数
    // ------------------------------------------------------------------

    /*
    Unity 3D 引擎使用了若干不同规格的等腰直角三角形，在 4 阶、6 阶、8 阶采样内核上进行覆盖，
    以获取不同纹素对阴影的贡献程度，然后遵循n阶采样内核执行次采样的规则进行 PCF 处理。
    下面的代码就是进行 PCF 操作的一系列工具函数。
    */

    /**
    * Assuming a isoceles rectangle triangle of height "triangleHeight" (as drawn below).
    * This function return the area of the triangle above the first texel.
    *
    * |\      <-- 45 degree slop isosceles rectangle triangle
    * | \
    * ----    <-- length of this side is "triangleHeight"
    * _ _ _ _ <-- texels
    */
    // 
    /*
    此函数返回第一个纹理像素上方的三角形面积：
    个人理解：
    这里返回的是【第一个纹理像素】这一列上的图形（三角形，更多情况下是个梯形）面积。
    */
    float _UnityInternalGetAreaAboveFirstTexelUnderAIsocelesRectangleTriangle(float triangleHeight)
    {
        return triangleHeight - 0.5;
    }

    /**
    * Assuming a isoceles triangle of 1.5 texels height and 3 texels wide lying on 4 texels.
    * This function return the area of the triangle above each of those texels.
    *    |    <-- offset from -0.5 to 0.5, 0 meaning triangle is exactly in the center
    *   / \   <-- 45 degree slop isosceles triangle (ie tent projected in 2D)
    *  /   \
    * _ _ _ _ <-- texels
    * X Y Z W <-- result indices (in computedArea.xyzw and computedAreaUncut.xyzw)
    */
    /*
    本函数假定本等腰三角形的高为1.5纹素，底为3纹素，共占据了4个纹素点，
    本函数返回这4个纹素点分割了多少面积
    offset：取值范围是[-0.5, 0.5]，为0时表示三角形居中
    */
    void _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(float offset, out float4 computedArea, out float4 computedAreaUncut)
    {
        //Compute the exterior areas  计算两边（x、w）区域
        // 假设 offset 为 0，则 offset01SquaredHalved 为 0.125
        // computedAreaUncut.x 和 computedArea.x 为 0.125
        // computedAreaUncut.w 和 computedArea.w 也为 0.125
        // 假设 offset 为 0.5，则 offset01SquaredHalved 为 0.5
        // computedAreaUncut.x 和 computedArea.x 为 0
        // computedAreaUncut.w 和 computedArea.w 也为 0
        float offset01SquaredHalved = (offset + 0.5) * (offset + 0.5) * 0.5;
        computedAreaUncut.x = computedArea.x = offset01SquaredHalved - offset;
        computedAreaUncut.w = computedArea.w = offset01SquaredHalved;

        //Compute the middle areas  计算中间区域
        //For Y : We find the area in Y of as if the left section of the isoceles triangle would
        //intersect the axis between Y and Z (ie where offset = 0).
        // 对于Y：我们在Y中找到等腰三角形的左部分将与Y和Z之间的轴相交的区域（即，偏移= 0）
        computedAreaUncut.y = _UnityInternalGetAreaAboveFirstTexelUnderAIsocelesRectangleTriangle(1.5 - offset);
        //This area is superior to the one we are looking for if (offset < 0) thus we need to
        //subtract the area of the triangle defined by (0,1.5-offset), (0,1.5+offset), (-offset,1.5).
        // 如果（offset <0），则此区域大于我们要查找的区域，
        // 因此我们需要减去由（0,1.5-offset），（0,1.5 + offset）， (-offset,1.5)定义的三角形的面积。
        //当 offset 等于 0 时，computedAreaUncut.y 为 1
        //当 offset 等于 0.5 时，computedAreaUncut.y 为 0.5.
        float clampedOffsetLeft = min(offset,0);
        float areaOfSmallLeftTriangle = clampedOffsetLeft * clampedOffsetLeft;
        computedArea.y = computedAreaUncut.y - areaOfSmallLeftTriangle;     // 这里就是求y（-1，0）区域的面积

        //We do the same for the Z but with the right part of the isoceles triangle
        // 对等腰三角形的右边执行相同的操作，并将其保存到z分量中
        // 当 offset 为 0 时，computedAreaUncut.y 和 computedArea.y 都为 1
        computedAreaUncut.z = _UnityInternalGetAreaAboveFirstTexelUnderAIsocelesRectangleTriangle(1.5 + offset);
        float clampedOffsetRight = max(offset,0);   // 这里是max
        float areaOfSmallRightTriangle = clampedOffsetRight * clampedOffsetRight;
        computedArea.z = computedAreaUncut.z - areaOfSmallRightTriangle;    // 这里就是求（0，1）区域的面积
    }

    /**
    * Assuming a isoceles triangle of 1.5 texels height and 3 texels wide lying on 4 texels.
    * This function return the weight of each texels area relative to the full triangle area.
    */
    /*
    本函数假定等腰直角三角形的高为 1.5 纹素，底为 3 纹素，该三角形覆盖在 4 个纹素点上
    本函数将求出每个纹素点那一列的三角形的面积，并求出各部分面积占总面积的【比例】
    */
    void _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(float offset, out float4 computedWeight)
    {
        float4 dummy;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedWeight, dummy);
        computedWeight *= 0.44444;//0.44 == 1/(the triangle area)  0.44444 就是 总面积的倒数  相当于除总面积
    }

    /**
    * Assuming a isoceles triangle of 2.5 texel height and 5 texels wide lying on 6 texels.
    * This function return the weight of each texels area relative to the full triangle area.
    *  /       \
    * _ _ _ _ _ _ <-- texels
    * 0 1 2 3 4 5 <-- computed area indices (in texelsWeights[])
    */
    /*
    本函数假定一个等腰直角三角形的高为 2.5 纹素，底为 5 纹素，该三角形覆盖在 6 个纹素点上；
    本函数将求出每个纹素点那一列的三角形的面积，并求出各部分面积占总面积的【比例】
    */
    void _UnityInternalGetWeightPerTexel_5TexelsWideTriangleFilter(float offset, out float3 texelsWeightsA, out float3 texelsWeightsB)
    {
        //See _UnityInternalGetAreaPerTexel_3TexelTriangleFilter for details.
        float4 computedArea_From3texelTriangle;
        float4 computedAreaUncut_From3texelTriangle;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedArea_From3texelTriangle, computedAreaUncut_From3texelTriangle);

        //Triangle slop is 45 degree thus we can almost reuse the result of the 3 texel wide computation.
        //the 5 texel wide triangle can be seen as the 3 texel wide one but shifted up by one unit/texel.
        // 三角形斜率是45度，因此我们几乎可以重用3 texel宽的计算结果。 
        // 5 texel宽的三角形可以看作是3 texel宽的三角形，但向上移动了一个单位/ texel。
        //0.16 is 1/(the triangle area) // 0.16 是总面积的倒数
        texelsWeightsA.x = 0.16 * (computedArea_From3texelTriangle.x);
        texelsWeightsA.y = 0.16 * (computedAreaUncut_From3texelTriangle.y);
        texelsWeightsA.z = 0.16 * (computedArea_From3texelTriangle.y + 1);
        texelsWeightsB.x = 0.16 * (computedArea_From3texelTriangle.z + 1);
        texelsWeightsB.y = 0.16 * (computedAreaUncut_From3texelTriangle.z);
        texelsWeightsB.z = 0.16 * (computedArea_From3texelTriangle.w);
    }

    /**
    * Assuming a isoceles triangle of 3.5 texel height and 7 texels wide lying on 8 texels.
    * This function return the weight of each texels area relative to the full triangle area.
    *  /           \
    * _ _ _ _ _ _ _ _ <-- texels
    * 0 1 2 3 4 5 6 7 <-- computed area indices (in texelsWeights[])
    */
    /*
    本函数假定一个等腰直角三角形的高为 3.5 纹素，底为 7 纹素，该三角形覆盖在 8 个纹素点上
    本函数将求出每个纹素点那一列的三角形的面积，并求出各部分面积占总面积的【比例】
    */
    void _UnityInternalGetWeightPerTexel_7TexelsWideTriangleFilter(float offset, out float4 texelsWeightsA, out float4 texelsWeightsB)
    {
        //See _UnityInternalGetAreaPerTexel_3TexelTriangleFilter for details.
        float4 computedArea_From3texelTriangle;
        float4 computedAreaUncut_From3texelTriangle;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedArea_From3texelTriangle, computedAreaUncut_From3texelTriangle);

        //Triangle slop is 45 degree thus we can almost reuse the result of the 3 texel wide computation.
        //the 7 texel wide triangle can be seen as the 3 texel wide one but shifted up by two unit/texel.
        // 三角形斜率是45度，因此我们几乎可以重用3 texel宽的计算结果。
        // 7 texel宽的三角形可以看成是3 texel宽的三角形，但向上移动了两个单位/ texel
        //0.081632 is 1/(the triangle area) // 0.081632 是总面积的倒数
        texelsWeightsA.x = 0.081632 * (computedArea_From3texelTriangle.x);
        texelsWeightsA.y = 0.081632 * (computedAreaUncut_From3texelTriangle.y);
        texelsWeightsA.z = 0.081632 * (computedAreaUncut_From3texelTriangle.y + 1);
        texelsWeightsA.w = 0.081632 * (computedArea_From3texelTriangle.y + 2);
        texelsWeightsB.x = 0.081632 * (computedArea_From3texelTriangle.z + 2);
        texelsWeightsB.y = 0.081632 * (computedAreaUncut_From3texelTriangle.z + 1);
        texelsWeightsB.z = 0.081632 * (computedAreaUncut_From3texelTriangle.z);
        texelsWeightsB.w = 0.081632 * (computedArea_From3texelTriangle.w);
    }

    // ------------------------------------------------------------------
    //  PCF Filtering
    //  PCF过滤相关的函数
    // ------------------------------------------------------------------

    /**
    * PCF gaussian shadowmap filtering based on a 3x3 kernel (9 taps no PCF hardware support)
    * 基于3x3内核的PCF高斯阴影贴图过滤（没有PCF硬件支持，没有优化，采样9次）
    */
    half UnitySampleShadowmap_PCF3x3NoHardwareSupport(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED
            // when we don't have hardware PCF sampling, then the above 5x5 optimized PCF really does not work.
            // Fallback to a simple 3x3 sampling with averaged results.
            // 当我们没有硬件PCF采样时，上述5x5优化的PCF确实不起作用。
            // 退回到具有平均结果的简单3x3采样。
            float2 base_uv = coord.xy;
            float2 ts = _ShadowMapTexture_TexelSize.xy;
            shadow = 0;
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(-ts.x, -ts.y), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(0, -ts.y), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(ts.x, -ts.y), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(-ts.x, 0), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(0, 0), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(ts.x, 0), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(-ts.x, ts.y), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(0, ts.y), coord.z, receiverPlaneDepthBias));
            shadow += UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(ts.x, ts.y), coord.z, receiverPlaneDepthBias));
            shadow /= 9.0;
        #endif

        return shadow;
    }

    /**
    * PCF tent shadowmap filtering based on a 3x3 kernel (optimized with 4 taps)
    * 基于3x3内核的PCF帐篷（tent）阴影贴图过滤（优化成只要采样4次）
    */
    /*
    没看懂...
    */
    half UnitySampleShadowmap_PCF3x3Tent(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // 硬件不支持时，退回 UnitySampleShadowmap_PCF3x3NoHardwareSupport 
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            // tent base is 3x3 base thus covering from 9 to 12 texels, thus we need 4 bilinear PCF fetches
            // 帐篷（tent）底是3x3底，因此覆盖9到12像素，因此我们需要4个双线性PCF提取 ？？？
            // ->
            // 把单位化纹理映射坐标转为纹素坐标，
            // _ShadowMapTexture_TexelSize.zw，为阴影贴图的长和宽方向各自的纹素个数
            float2 tentCenterInTexelSpace = coord.xy * _ShadowMapTexture_TexelSize.zw;
            // 向下取整
            float2 centerOfFetchesInTexelSpace = floor(tentCenterInTexelSpace + 0.5);
            // 计算tent中点 到fetch中点 的偏移值
            float2 offsetFromTentCenterToCenterOfFetches = tentCenterInTexelSpace - centerOfFetchesInTexelSpace;

            // find the weight of each texel based
            // 求出基于每个纹素的权重
            // 判断每个纹素所占有的部分三角形的权重   为什么分成uv两个方向？
            float4 texelsWeightsU, texelsWeightsV;
            _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.x, texelsWeightsU);
            _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.y, texelsWeightsV);

            // each fetch will cover a group of 2x2 texels, the weight of each group is the sum of the weights of the texels
            // 每次提取会覆盖一组的2x2的纹素，该组的权重是纹素权重的和
            float2 fetchesWeightsU = texelsWeightsU.xz + texelsWeightsU.yw;
            float2 fetchesWeightsV = texelsWeightsV.xz + texelsWeightsV.yw;

            // move the PCF bilinear fetches to respect texels weights
            // 移动PCF双线性获取以尊重（？？）纹素权重
            float2 fetchesOffsetsU = texelsWeightsU.yw / fetchesWeightsU.xy + float2(-1.5,0.5);
            float2 fetchesOffsetsV = texelsWeightsV.yw / fetchesWeightsV.xy + float2(-1.5,0.5);
            fetchesOffsetsU *= _ShadowMapTexture_TexelSize.xx;
            fetchesOffsetsV *= _ShadowMapTexture_TexelSize.yy;

            // fetch !
            // 采样点开始的纹理贴图坐标
            float2 bilinearFetchOrigin = centerOfFetchesInTexelSpace * _ShadowMapTexture_TexelSize.xy;
            // fetchesWeightsU.x 对应于 x0，fetchesWeightsU.y 对应于 x1
            // fetchesWeightsV.x 对应于 y0，fetchesWeightsV.y 对应于 y1
            // 双线性过滤
            shadow =  fetchesWeightsU.x * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
        #endif

        return shadow;
    }

    /**
    * PCF tent shadowmap filtering based on a 5x5 kernel (optimized with 9 taps)
    * 参考 3x3
    */
    half UnitySampleShadowmap_PCF5x5Tent(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            // tent base is 5x5 base thus covering from 25 to 36 texels, thus we need 9 bilinear PCF fetches
            float2 tentCenterInTexelSpace = coord.xy * _ShadowMapTexture_TexelSize.zw;
            float2 centerOfFetchesInTexelSpace = floor(tentCenterInTexelSpace + 0.5);
            float2 offsetFromTentCenterToCenterOfFetches = tentCenterInTexelSpace - centerOfFetchesInTexelSpace;

            // find the weight of each texel based on the area of a 45 degree slop tent above each of them.
            float3 texelsWeightsU_A, texelsWeightsU_B;
            float3 texelsWeightsV_A, texelsWeightsV_B;
            _UnityInternalGetWeightPerTexel_5TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.x, texelsWeightsU_A, texelsWeightsU_B);
            _UnityInternalGetWeightPerTexel_5TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.y, texelsWeightsV_A, texelsWeightsV_B);

            // each fetch will cover a group of 2x2 texels, the weight of each group is the sum of the weights of the texels
            float3 fetchesWeightsU = float3(texelsWeightsU_A.xz, texelsWeightsU_B.y) + float3(texelsWeightsU_A.y, texelsWeightsU_B.xz);
            float3 fetchesWeightsV = float3(texelsWeightsV_A.xz, texelsWeightsV_B.y) + float3(texelsWeightsV_A.y, texelsWeightsV_B.xz);

            // move the PCF bilinear fetches to respect texels weights
            float3 fetchesOffsetsU = float3(texelsWeightsU_A.y, texelsWeightsU_B.xz) / fetchesWeightsU.xyz + float3(-2.5,-0.5,1.5);
            float3 fetchesOffsetsV = float3(texelsWeightsV_A.y, texelsWeightsV_B.xz) / fetchesWeightsV.xyz + float3(-2.5,-0.5,1.5);
            fetchesOffsetsU *= _ShadowMapTexture_TexelSize.xxx;
            fetchesOffsetsV *= _ShadowMapTexture_TexelSize.yyy;

            // fetch !
            float2 bilinearFetchOrigin = centerOfFetchesInTexelSpace * _ShadowMapTexture_TexelSize.xy;
            shadow  = fetchesWeightsU.x * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
        #endif

        return shadow;
    }

    /**
    * PCF tent shadowmap filtering based on a 7x7 kernel (optimized with 16 taps)
    * 参考 3x3
    */
    half UnitySampleShadowmap_PCF7x7Tent(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            // tent base is 7x7 base thus covering from 49 to 64 texels, thus we need 16 bilinear PCF fetches
            float2 tentCenterInTexelSpace = coord.xy * _ShadowMapTexture_TexelSize.zw;
            float2 centerOfFetchesInTexelSpace = floor(tentCenterInTexelSpace + 0.5);
            float2 offsetFromTentCenterToCenterOfFetches = tentCenterInTexelSpace - centerOfFetchesInTexelSpace;

            // find the weight of each texel based on the area of a 45 degree slop tent above each of them.
            float4 texelsWeightsU_A, texelsWeightsU_B;
            float4 texelsWeightsV_A, texelsWeightsV_B;
            _UnityInternalGetWeightPerTexel_7TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.x, texelsWeightsU_A, texelsWeightsU_B);
            _UnityInternalGetWeightPerTexel_7TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.y, texelsWeightsV_A, texelsWeightsV_B);

            // each fetch will cover a group of 2x2 texels, the weight of each group is the sum of the weights of the texels
            float4 fetchesWeightsU = float4(texelsWeightsU_A.xz, texelsWeightsU_B.xz) + float4(texelsWeightsU_A.yw, texelsWeightsU_B.yw);
            float4 fetchesWeightsV = float4(texelsWeightsV_A.xz, texelsWeightsV_B.xz) + float4(texelsWeightsV_A.yw, texelsWeightsV_B.yw);

            // move the PCF bilinear fetches to respect texels weights
            float4 fetchesOffsetsU = float4(texelsWeightsU_A.yw, texelsWeightsU_B.yw) / fetchesWeightsU.xyzw + float4(-3.5,-1.5,0.5,2.5);
            float4 fetchesOffsetsV = float4(texelsWeightsV_A.yw, texelsWeightsV_B.yw) / fetchesWeightsV.xyzw + float4(-3.5,-1.5,0.5,2.5);
            fetchesOffsetsU *= _ShadowMapTexture_TexelSize.xxxx;
            fetchesOffsetsV *= _ShadowMapTexture_TexelSize.yyyy;

            // fetch !
            float2 bilinearFetchOrigin = centerOfFetchesInTexelSpace * _ShadowMapTexture_TexelSize.xy;
            shadow  = fetchesWeightsU.x * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.w * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.w, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.w * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.w, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.w * fetchesWeightsV.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.w, fetchesOffsetsV.z), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.w * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.w), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.w * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.w), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.z * fetchesWeightsV.w * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.z, fetchesOffsetsV.w), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.w * fetchesWeightsV.w * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.w, fetchesOffsetsV.w), coord.z, receiverPlaneDepthBias));
        #endif

        return shadow;
    }

    /**
    * PCF gaussian shadowmap filtering based on a 3x3 kernel (optimized with 4 taps)
    *
    * Algorithm: http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
    * Implementation example: http://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
    */
    /*
    高斯模糊是根据高斯公式先计算出周围片元对需要模糊的那个片元的影响程度，即权重值，
    然后对图像中该像素的颜色值进行卷积计算，最后得到该片元的颜色值。
    */
    // 在 PCF 采样的基础上，用高斯模糊算法重建了各采样点的权重值
    half UnitySampleShadowmap_PCF3x3Gaussian(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            // 求得每个采样点得权重
            const float2 offset = float2(0.5, 0.5);
            float2 uv = (coord.xy * _ShadowMapTexture_TexelSize.zw) + offset;
            float2 base_uv = (floor(uv) - offset) * _ShadowMapTexture_TexelSize.xy;
            float2 st = frac(uv);

            float2 uw = float2(3 - 2 * st.x, 1 + 2 * st.x);
            float2 u = float2((2 - st.x) / uw.x - 1, (st.x) / uw.y + 1);
            u *= _ShadowMapTexture_TexelSize.x;

            float2 vw = float2(3 - 2 * st.y, 1 + 2 * st.y);
            float2 v = float2((2 - st.y) / vw.x - 1, (st.y) / vw.y + 1);
            v *= _ShadowMapTexture_TexelSize.y;

            half sum = 0;

            sum += uw[0] * vw[0] * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u[0], v[0]), coord.z, receiverPlaneDepthBias));
            sum += uw[1] * vw[0] * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u[1], v[0]), coord.z, receiverPlaneDepthBias));
            sum += uw[0] * vw[1] * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u[0], v[1]), coord.z, receiverPlaneDepthBias));
            sum += uw[1] * vw[1] * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u[1], v[1]), coord.z, receiverPlaneDepthBias));

            shadow = sum / 16.0f;
        #endif

        return shadow;
    }

    /**
    * PCF gaussian shadowmap filtering based on a 5x5 kernel (optimized with 9 taps)
    *
    * Algorithm: http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/
    * Implementation example: http://mynameismjp.wordpress.com/2013/09/10/shadow-maps/
    */
    // 参考 xxx3x3xxx
    half UnitySampleShadowmap_PCF5x5Gaussian(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            const float2 offset = float2(0.5, 0.5);
            float2 uv = (coord.xy * _ShadowMapTexture_TexelSize.zw) + offset;
            float2 base_uv = (floor(uv) - offset) * _ShadowMapTexture_TexelSize.xy;
            float2 st = frac(uv);

            float3 uw = float3(4 - 3 * st.x, 7, 1 + 3 * st.x);
            float3 u = float3((3 - 2 * st.x) / uw.x - 2, (3 + st.x) / uw.y, st.x / uw.z + 2);
            u *= _ShadowMapTexture_TexelSize.x;

            float3 vw = float3(4 - 3 * st.y, 7, 1 + 3 * st.y);
            float3 v = float3((3 - 2 * st.y) / vw.x - 2, (3 + st.y) / vw.y, st.y / vw.z + 2);
            v *= _ShadowMapTexture_TexelSize.y;

            half sum = 0.0f;

            half3 accum = uw * vw.x;
            sum += accum.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.x, v.x), coord.z, receiverPlaneDepthBias));
            sum += accum.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.y, v.x), coord.z, receiverPlaneDepthBias));
            sum += accum.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.z, v.x), coord.z, receiverPlaneDepthBias));

            accum = uw * vw.y;
            sum += accum.x *  UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.x, v.y), coord.z, receiverPlaneDepthBias));
            sum += accum.y *  UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.y, v.y), coord.z, receiverPlaneDepthBias));
            sum += accum.z *  UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.z, v.y), coord.z, receiverPlaneDepthBias));

            accum = uw * vw.z;
            sum += accum.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.x, v.z), coord.z, receiverPlaneDepthBias));
            sum += accum.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.y, v.z), coord.z, receiverPlaneDepthBias));
            sum += accum.z * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(base_uv, float2(u.z, v.z), coord.z, receiverPlaneDepthBias));
            shadow = sum / 144.0f;

        #endif

        return shadow;
    }

    // 转调 xxxTent
    half UnitySampleShadowmap_PCF3x3(float4 coord, float3 receiverPlaneDepthBias)
    {
        return UnitySampleShadowmap_PCF3x3Tent(coord, receiverPlaneDepthBias);
    }

    half UnitySampleShadowmap_PCF5x5(float4 coord, float3 receiverPlaneDepthBias)
    {
        return UnitySampleShadowmap_PCF5x5Tent(coord, receiverPlaneDepthBias);
    }

    half UnitySampleShadowmap_PCF7x7(float4 coord, float3 receiverPlaneDepthBias)
    {
        return UnitySampleShadowmap_PCF7x7Tent(coord, receiverPlaneDepthBias);
    }

#endif // UNITY_BUILTIN_SHADOW_LIBRARY_INCLUDED
