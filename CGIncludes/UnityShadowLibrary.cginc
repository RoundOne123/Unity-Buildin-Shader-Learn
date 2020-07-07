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
                return saturate(dot(rawOcclusionMask, unity_OcclusionMaskSelector));
            #endif

            return atten;
        #endif
    }

    // ------------------------------------------------------------------
    // Used by the deferred rendering path (in the gbuffer pass)
    fixed4 UnityGetRawBakedOcclusions(float2 lightmapUV, float3 worldPos)
    {
        #if defined (SHADOWS_SHADOWMASK)
            #if defined(LIGHTMAP_ON)
                return UNITY_SAMPLE_TEX2D(unity_ShadowMask, lightmapUV.xy);
            #else
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
    half UnityMixRealtimeAndBakedShadows(half realtimeShadowAttenuation, half bakedShadowAttenuation, half fade)
    {
        // -- Static objects --
        // FWD BASE PASS
        // ShadowMask mode          = LIGHTMAP_ON + SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = LIGHTMAP_ON + SHADOWS_SHADOWMASK
        // Subtractive mode         = LIGHTMAP_ON + LIGHTMAP_SHADOW_MIXING
        // Pure realtime direct lit = LIGHTMAP_ON

        // FWD ADD PASS
        // ShadowMask mode          = SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = SHADOWS_SHADOWMASK
        // Pure realtime direct lit = LIGHTMAP_ON

        // DEFERRED LIGHTING PASS
        // ShadowMask mode          = LIGHTMAP_ON + SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = LIGHTMAP_ON + SHADOWS_SHADOWMASK
        // Pure realtime direct lit = LIGHTMAP_ON

        // -- Dynamic objects --
        // FWD BASE PASS + FWD ADD ASS
        // ShadowMask mode          = LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = N/A
        // Subtractive mode         = LIGHTMAP_SHADOW_MIXING (only matter for LPPV. Light probes occlusion being done on CPU)
        // Pure realtime direct lit = N/A

        // DEFERRED LIGHTING PASS
        // ShadowMask mode          = SHADOWS_SHADOWMASK + LIGHTMAP_SHADOW_MIXING
        // Distance shadowmask mode = SHADOWS_SHADOWMASK
        // Pure realtime direct lit = N/A

        #if !defined(SHADOWS_DEPTH) && !defined(SHADOWS_SCREEN) && !defined(SHADOWS_CUBE)
            #if defined(LIGHTMAP_ON) && defined (LIGHTMAP_SHADOW_MIXING) && !defined (SHADOWS_SHADOWMASK)
                //In subtractive mode when there is no shadow we kill the light contribution as direct as been baked in the lightmap.
                return 0.0;
            #else
                return bakedShadowAttenuation;
            #endif
        #endif

        #if (SHADER_TARGET <= 20) || UNITY_STANDARD_SIMPLE
            //no fading nor blending on SM 2.0 because of instruction count limit.
            #if defined(SHADOWS_SHADOWMASK) || defined(LIGHTMAP_SHADOW_MIXING)
                return min(realtimeShadowAttenuation, bakedShadowAttenuation);
            #else
                return realtimeShadowAttenuation;
            #endif
        #endif

        #if defined(LIGHTMAP_SHADOW_MIXING)
            //Subtractive or shadowmask mode
            realtimeShadowAttenuation = saturate(realtimeShadowAttenuation + fade);
            return min(realtimeShadowAttenuation, bakedShadowAttenuation);
        #endif

        //In distance shadowmask or realtime shadow fadeout we lerp toward the baked shadows (bakedShadowAttenuation will be 1 if no baked shadows)
        return lerp(realtimeShadowAttenuation, bakedShadowAttenuation, fade);
    }

    // ------------------------------------------------------------------
    // Shadow fade
    // ------------------------------------------------------------------

    float UnityComputeShadowFadeDistance(float3 wpos, float z)
    {
        float sphereDist = distance(wpos, unity_ShadowFadeCenterAndType.xyz);
        return lerp(z, sphereDist, unity_ShadowFadeCenterAndType.w);
    }

    // ------------------------------------------------------------------
    half UnityComputeShadowFade(float fadeDist)
    {
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
    float3 UnityGetReceiverPlaneDepthBias(float3 shadowCoord, float biasMultiply)
    {
        // Should receiver plane bias be used? This estimates receiver slope using derivatives,
        // and tries to tilt the PCF kernel along it. However, when doing it in screenspace from the depth texture
        // (ie all light in deferred and directional light in both forward and deferred), the derivatives are wrong
        // on edges or intersections of objects, leading to shadow artifacts. Thus it is disabled by default.
        float3 biasUVZ = 0;

        #if defined(UNITY_USE_RECEIVER_PLANE_BIAS) && defined(SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED)
            float3 dx = ddx(shadowCoord);
            float3 dy = ddy(shadowCoord);

            biasUVZ.x = dy.y * dx.z - dx.y * dy.z;
            biasUVZ.y = dx.x * dy.z - dy.x * dx.z;
            biasUVZ.xy *= biasMultiply / ((dx.x * dy.y) - (dx.y * dy.x));

            // Static depth biasing to make up for incorrect fractional sampling on the shadow map grid.
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
    float3 UnityCombineShadowcoordComponents(float2 baseUV, float2 deltaUV, float depth, float3 receiverPlaneDepthBias)
    {
        float3 uv = float3(baseUV + deltaUV, depth + receiverPlaneDepthBias.z);
        uv.z += dot(deltaUV, receiverPlaneDepthBias.xy);
        return uv;
    }

    // ------------------------------------------------------------------
    //  PCF Filtering helpers
    // ------------------------------------------------------------------

    /**
    * Assuming a isoceles rectangle triangle of height "triangleHeight" (as drawn below).
    * This function return the area of the triangle above the first texel.
    *
    * |\      <-- 45 degree slop isosceles rectangle triangle
    * | \
    * ----    <-- length of this side is "triangleHeight"
    * _ _ _ _ <-- texels
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
    void _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(float offset, out float4 computedArea, out float4 computedAreaUncut)
    {
        //Compute the exterior areas
        float offset01SquaredHalved = (offset + 0.5) * (offset + 0.5) * 0.5;
        computedAreaUncut.x = computedArea.x = offset01SquaredHalved - offset;
        computedAreaUncut.w = computedArea.w = offset01SquaredHalved;

        //Compute the middle areas
        //For Y : We find the area in Y of as if the left section of the isoceles triangle would
        //intersect the axis between Y and Z (ie where offset = 0).
        computedAreaUncut.y = _UnityInternalGetAreaAboveFirstTexelUnderAIsocelesRectangleTriangle(1.5 - offset);
        //This area is superior to the one we are looking for if (offset < 0) thus we need to
        //subtract the area of the triangle defined by (0,1.5-offset), (0,1.5+offset), (-offset,1.5).
        float clampedOffsetLeft = min(offset,0);
        float areaOfSmallLeftTriangle = clampedOffsetLeft * clampedOffsetLeft;
        computedArea.y = computedAreaUncut.y - areaOfSmallLeftTriangle;

        //We do the same for the Z but with the right part of the isoceles triangle
        computedAreaUncut.z = _UnityInternalGetAreaAboveFirstTexelUnderAIsocelesRectangleTriangle(1.5 + offset);
        float clampedOffsetRight = max(offset,0);
        float areaOfSmallRightTriangle = clampedOffsetRight * clampedOffsetRight;
        computedArea.z = computedAreaUncut.z - areaOfSmallRightTriangle;
    }

    /**
    * Assuming a isoceles triangle of 1.5 texels height and 3 texels wide lying on 4 texels.
    * This function return the weight of each texels area relative to the full triangle area.
    */
    void _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(float offset, out float4 computedWeight)
    {
        float4 dummy;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedWeight, dummy);
        computedWeight *= 0.44444;//0.44 == 1/(the triangle area)
    }

    /**
    * Assuming a isoceles triangle of 2.5 texel height and 5 texels wide lying on 6 texels.
    * This function return the weight of each texels area relative to the full triangle area.
    *  /       \
    * _ _ _ _ _ _ <-- texels
    * 0 1 2 3 4 5 <-- computed area indices (in texelsWeights[])
    */
    void _UnityInternalGetWeightPerTexel_5TexelsWideTriangleFilter(float offset, out float3 texelsWeightsA, out float3 texelsWeightsB)
    {
        //See _UnityInternalGetAreaPerTexel_3TexelTriangleFilter for details.
        float4 computedArea_From3texelTriangle;
        float4 computedAreaUncut_From3texelTriangle;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedArea_From3texelTriangle, computedAreaUncut_From3texelTriangle);

        //Triangle slop is 45 degree thus we can almost reuse the result of the 3 texel wide computation.
        //the 5 texel wide triangle can be seen as the 3 texel wide one but shifted up by one unit/texel.
        //0.16 is 1/(the triangle area)
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
    void _UnityInternalGetWeightPerTexel_7TexelsWideTriangleFilter(float offset, out float4 texelsWeightsA, out float4 texelsWeightsB)
    {
        //See _UnityInternalGetAreaPerTexel_3TexelTriangleFilter for details.
        float4 computedArea_From3texelTriangle;
        float4 computedAreaUncut_From3texelTriangle;
        _UnityInternalGetAreaPerTexel_3TexelsWideTriangleFilter(offset, computedArea_From3texelTriangle, computedAreaUncut_From3texelTriangle);

        //Triangle slop is 45 degree thus we can almost reuse the result of the 3 texel wide computation.
        //the 7 texel wide triangle can be seen as the 3 texel wide one but shifted up by two unit/texel.
        //0.081632 is 1/(the triangle area)
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
    // ------------------------------------------------------------------

    /**
    * PCF gaussian shadowmap filtering based on a 3x3 kernel (9 taps no PCF hardware support)
    */
    half UnitySampleShadowmap_PCF3x3NoHardwareSupport(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED
            // when we don't have hardware PCF sampling, then the above 5x5 optimized PCF really does not work.
            // Fallback to a simple 3x3 sampling with averaged results.
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
    */
    half UnitySampleShadowmap_PCF3x3Tent(float4 coord, float3 receiverPlaneDepthBias)
    {
        half shadow = 1;

        #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

            #ifndef SHADOWS_NATIVE
                // when we don't have hardware PCF sampling, fallback to a simple 3x3 sampling with averaged results.
                return UnitySampleShadowmap_PCF3x3NoHardwareSupport(coord, receiverPlaneDepthBias);
            #endif

            // tent base is 3x3 base thus covering from 9 to 12 texels, thus we need 4 bilinear PCF fetches
            float2 tentCenterInTexelSpace = coord.xy * _ShadowMapTexture_TexelSize.zw;
            float2 centerOfFetchesInTexelSpace = floor(tentCenterInTexelSpace + 0.5);
            float2 offsetFromTentCenterToCenterOfFetches = tentCenterInTexelSpace - centerOfFetchesInTexelSpace;

            // find the weight of each texel based
            float4 texelsWeightsU, texelsWeightsV;
            _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.x, texelsWeightsU);
            _UnityInternalGetWeightPerTexel_3TexelsWideTriangleFilter(offsetFromTentCenterToCenterOfFetches.y, texelsWeightsV);

            // each fetch will cover a group of 2x2 texels, the weight of each group is the sum of the weights of the texels
            float2 fetchesWeightsU = texelsWeightsU.xz + texelsWeightsU.yw;
            float2 fetchesWeightsV = texelsWeightsV.xz + texelsWeightsV.yw;

            // move the PCF bilinear fetches to respect texels weights
            float2 fetchesOffsetsU = texelsWeightsU.yw / fetchesWeightsU.xy + float2(-1.5,0.5);
            float2 fetchesOffsetsV = texelsWeightsV.yw / fetchesWeightsV.xy + float2(-1.5,0.5);
            fetchesOffsetsU *= _ShadowMapTexture_TexelSize.xx;
            fetchesOffsetsV *= _ShadowMapTexture_TexelSize.yy;

            // fetch !
            float2 bilinearFetchOrigin = centerOfFetchesInTexelSpace * _ShadowMapTexture_TexelSize.xy;
            shadow =  fetchesWeightsU.x * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.x * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.x), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.x * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.x, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
            shadow += fetchesWeightsU.y * fetchesWeightsV.y * UNITY_SAMPLE_SHADOW(_ShadowMapTexture, UnityCombineShadowcoordComponents(bilinearFetchOrigin, float2(fetchesOffsetsU.y, fetchesOffsetsV.y), coord.z, receiverPlaneDepthBias));
        #endif

        return shadow;
    }

    /**
    * PCF tent shadowmap filtering based on a 5x5 kernel (optimized with 9 taps)
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
    half UnitySampleShadowmap_PCF3x3Gaussian(float4 coord, float3 receiverPlaneDepthBias)
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
