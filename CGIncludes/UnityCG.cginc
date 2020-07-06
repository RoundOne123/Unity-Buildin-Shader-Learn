// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_CG_INCLUDED
    #define UNITY_CG_INCLUDED

    // 数学常数
    #define UNITY_PI            3.14159265359f
    #define UNITY_TWO_PI        6.28318530718f
    #define UNITY_FOUR_PI       12.56637061436f
    #define UNITY_INV_PI        0.31830988618f      // 圆周率的倒数
    #define UNITY_INV_TWO_PI    0.15915494309f      // 两倍圆周率的倒数
    #define UNITY_INV_FOUR_PI   0.07957747155f
    #define UNITY_HALF_PI       1.57079632679f
    #define UNITY_INV_HALF_PI   0.636619772367f     // 半倍圆周率的倒数

    // Should SH (light probe / ambient) calculations be performed?
    // - When both static and dynamic lightmaps are available, no SH evaluation is performed
    // - When static and dynamic lightmaps are not available, SH evaluation is always performed
    // - For low level LODs, static lightmap and real-time GI from light probes can be combined together
    // - Passes that don't do ambient (additive, shadowcaster etc.) should not do SH either.
    #define UNITY_SHOULD_SAMPLE_SH (defined(LIGHTPROBE_SH) && !defined(UNITY_PASS_FORWARDADD) && !defined(UNITY_PASS_PREPASSBASE) && !defined(UNITY_PASS_SHADOWCASTER) && !defined(UNITY_PASS_META))

    #include "UnityShaderVariables.cginc"
    #include "UnityShaderUtilities.cginc"
    #include "UnityInstancing.cginc"

    #ifdef UNITY_COLORSPACE_GAMMA
        #define unity_ColorSpaceGrey fixed4(0.5, 0.5, 0.5, 0.5)
        #define unity_ColorSpaceDouble fixed4(2.0, 2.0, 2.0, 2.0)
        #define unity_ColorSpaceDielectricSpec half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)
        #define unity_ColorSpaceLuminance half4(0.22, 0.707, 0.071, 0.0) // Legacy: alpha is set to 0.0 to specify gamma mode
    #else // Linear values
        #define unity_ColorSpaceGrey fixed4(0.214041144, 0.214041144, 0.214041144, 0.5)
        #define unity_ColorSpaceDouble fixed4(4.59479380, 4.59479380, 4.59479380, 2.0)
        #define unity_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)
        #define unity_ColorSpaceLuminance half4(0.0396819152, 0.458021790, 0.00609653955, 1.0) // Legacy: alpha is set to 1.0 to specify linear mode
    #endif

    // -------------------------------------------------------------------
    //  helper functions and macros used in many standard shaders


    #if defined (DIRECTIONAL) || defined (DIRECTIONAL_COOKIE) || defined (POINT) || defined (SPOT) || defined (POINT_NOATT) || defined (POINT_COOKIE)
        #define USING_LIGHT_MULTI_COMPILE
    #endif

    #if defined(SHADER_API_D3D11) || defined(SHADER_API_PSSL) || defined(SHADER_API_METAL) || defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES3) || defined(SHADER_API_VULKAN) || defined(SHADER_API_SWITCH) // D3D11, D3D12, XB1, PS4, iOS, macOS, tvOS, glcore, gles3, webgl2.0, Switch
        // Real-support for depth-format cube shadow map.
        // D3D11，D3D12，XB1，PS4，iOS，macOS，tvOS，glcore，gles3，webgl2.0，Switch Real支持深度格式的立方体阴影贴图。
        #define SHADOWS_CUBE_IN_DEPTH_TEX
    #endif

    #define SCALED_NORMAL v.normal


    // These constants must be kept in sync with RGBMRanges.h
    #define LIGHTMAP_RGBM_SCALE 5.0
    #define EMISSIVE_RGBM_SCALE 97.0

    struct appdata_base {
        float4 vertex : POSITION;
        float3 normal : NORMAL;
        float4 texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID      // 顶点多例化的ID
    };

    struct appdata_tan {
        float4 vertex : POSITION;
        float4 tangent : TANGENT;
        float3 normal : NORMAL;
        float4 texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct appdata_full {
        float4 vertex : POSITION;
        float4 tangent : TANGENT;
        float3 normal : NORMAL;
        float4 texcoord : TEXCOORD0;
        float4 texcoord1 : TEXCOORD1;
        float4 texcoord2 : TEXCOORD2;
        float4 texcoord3 : TEXCOORD3;
        fixed4 color : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    // ********** 与颜色空间相关的常数和工具函数 **********

    // Legacy for compatibility with existing shaders
    // 判断当前是否启用了伽马颜色空间函数  新版本中已经不再使用
    inline bool IsGammaSpace()
    {
        #ifdef UNITY_COLORSPACE_GAMMA
            return true;
        #else
            return false;
        #endif
    }

    // 把一个颜色值精确的从伽马颜色空间（sRGB颜色空间）转变到线性空间（CIE-XYZ颜色空间）
    inline float GammaToLinearSpaceExact (float value)
    {
        if (value <= 0.04045F)
        return value / 12.92F;
        else if (value < 1.0F)
        return pow((value + 0.055F)/1.055F, 2.4F);
        else
        return pow(value, 2.2F);
    }

    // 用一个近似模拟的函数把颜色值近似地从伽马颜色空间变换到线性空间
    inline half3 GammaToLinearSpace (half3 sRGB)
    {
        // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
        return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

        // Precise version, useful for debugging.
        //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
    }

    // 把一个颜色精确的从线性空间变换到伽马颜色空间
    inline float LinearToGammaSpaceExact (float value)
    {
        if (value <= 0.0F)
        return 0.0F;
        else if (value <= 0.0031308F)
        return 12.92F * value;
        else if (value < 1.0F)
        return 1.055F * pow(value, 0.4166667F) - 0.055F;
        else
        return pow(value, 0.45454545F);
    }

    // 用一个近似模拟的函数把颜色值近似地从线性空间变换到伽马颜色空间
    inline half3 LinearToGammaSpace (half3 linRGB)
    {
        linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
        // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
        return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);

        // Exact version, useful for debugging.
        //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
    }

    // ********** END **********

    // ********** 用于进行空间变换的工具函数 **********

    // Tranforms position from world to homogenous space
    // 世界坐标 -> 齐次裁剪坐标
    inline float4 UnityWorldToClipPos( in float3 pos )
    {
        return mul(UNITY_MATRIX_VP, float4(pos, 1.0));
    }

    // Tranforms position from view to homogenous space
    // 观察坐标 -> 其次裁剪坐标
    inline float4 UnityViewToClipPos( in float3 pos )
    {
        return mul(UNITY_MATRIX_P, float4(pos, 1.0));
    }

    // Tranforms position from object to camera space
    // 模型空间坐标 -> 观察空间坐标
    inline float3 UnityObjectToViewPos( in float3 pos )
    {
        return mul(UNITY_MATRIX_V, mul(unity_ObjectToWorld, float4(pos, 1.0))).xyz;
    }

    // float4类型参数的重载版本
    inline float3 UnityObjectToViewPos(float4 pos) // overload for float4; avoids "implicit truncation" warning for existing shaders
    {
        return UnityObjectToViewPos(pos.xyz);
    }

    // Tranforms position from world to camera space
    // 世界坐标 -> 观察空间坐标
    inline float3 UnityWorldToViewPos( in float3 pos )
    {
        return mul(UNITY_MATRIX_V, float4(pos, 1.0)).xyz;
    }

    // Transforms direction from object to world space
    // 模型空间的方向向量 -> 世界空间下的方向向量，并进行单位化（归一化）
    inline float3 UnityObjectToWorldDir( in float3 dir )
    {
        return normalize(mul((float3x3)unity_ObjectToWorld, dir));
    }

    // Transforms direction from world to object space
    // 世界空间下的方向向量 -> 模型空间的方向向量，并进行归一化
    inline float3 UnityWorldToObjectDir( in float3 dir )
    {
        return normalize(mul((float3x3)unity_WorldToObject, dir));
    }

    // Transforms normal from object to world space
    // 某点的法线向量从模型坐标系 -> 世界坐标系下，并进行归一化
    inline float3 UnityObjectToWorldNormal( in float3 norm )
    {
        #ifdef UNITY_ASSUME_UNIFORM_SCALING
            return UnityObjectToWorldDir(norm);
        #else
            // mul(IT_M, norm) => mul(norm, I_M) => {dot(norm, I_M.col0), dot(norm, I_M.col1), dot(norm, I_M.col2)}
            return normalize(mul(norm, (float3x3)unity_WorldToObject));
        #endif
    }

    // Computes world space light direction, from world space position
    // 计算光源_WorldSpaceLightPos0的对世界空间下的一点worldPos的光照方向
    inline float3 UnityWorldSpaceLightDir( in float3 worldPos )
    {
        #ifndef USING_LIGHT_MULTI_COMPILE       // 这个是个啥？
            return _WorldSpaceLightPos0.xyz - worldPos * _WorldSpaceLightPos0.w;
        #else
            #ifndef USING_DIRECTIONAL_LIGHT     // 非平行光
                return _WorldSpaceLightPos0.xyz - worldPos;
            #else                               // 平行光
                return _WorldSpaceLightPos0.xyz;
            #endif
        #endif
    }

    // Computes world space light direction, from object space position
    // *Legacy* Please use UnityWorldSpaceLightDir instead
    // 模型空间坐标在世界空间下，_WorldSpaceLightPos0光源的光照方向
    inline float3 WorldSpaceLightDir( in float4 localPos )
    {
        float3 worldPos = mul(unity_ObjectToWorld, localPos).xyz;
        return UnityWorldSpaceLightDir(worldPos);
    }

    // Computes object space light direction
    // 模型空间的光照方向
    inline float3 ObjSpaceLightDir( in float4 v )
    {
        float3 objSpaceLightPos = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;
        #ifndef USING_LIGHT_MULTI_COMPILE
            return objSpaceLightPos.xyz - v.xyz * _WorldSpaceLightPos0.w;
        #else
            #ifndef USING_DIRECTIONAL_LIGHT
                return objSpaceLightPos.xyz - v.xyz;
            #else
                return objSpaceLightPos.xyz;
            #endif
        #endif
    }

    // Computes world space view direction, from object space position
    // 世界空间下 视角方向（这里是指向摄像机的）
    inline float3 UnityWorldSpaceViewDir( in float3 worldPos )
    {
        return _WorldSpaceCameraPos.xyz - worldPos;
    }

    // Computes world space view direction, from object space position
    // *Legacy* Please use UnityWorldSpaceViewDir instead
    // 模型空间的点 在世界空间下 的视角方向
    inline float3 WorldSpaceViewDir( in float4 localPos )
    {
        float3 worldPos = mul(unity_ObjectToWorld, localPos).xyz;
        return UnityWorldSpaceViewDir(worldPos);
    }

    // Computes object space view direction
    // 模型空间下的视角方向
    inline float3 ObjSpaceViewDir( in float4 v )
    {
        float3 objSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1)).xyz;
        return objSpaceCameraPos - v.xyz;
    }

    // Declares 3x3 matrix 'rotation', filled with tangent space basis
    // 构建一个3x3的矩阵，该矩阵由顶点的法线、切线以及副切线组成，
    // 构成了一个正交的切线空间。
    #define TANGENT_SPACE_ROTATION \
    float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w; \
    float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal )

    // ********** END **********


    // Used in ForwardBase pass: Calculates diffuse lighting from 4 point lights, with data packed in a special way.
    // 用在ForwardBase渲染通道上，利用Lambert计算光照漫反射（diffuse）效果
    // 参数分别为 四个点光源的光照位置、四个点光源的颜色、四个点光源的二次项衰减系数
    // 顶点、顶点法线
    float3 Shade4PointLights (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
    float4 lightAttenSq,
    float3 pos, float3 normal)
    {
        // to light vectors
        float4 toLightX = lightPosX - pos.x;    // 存储顶点到四个光源的x的坐标差
        float4 toLightY = lightPosY - pos.y;
        float4 toLightZ = lightPosZ - pos.z;
        // squared lengths
        // 算出顶点到四个光源的距离的平方
        float4 lengthSq = 0;
        lengthSq += toLightX * toLightX;
        lengthSq += toLightY * toLightY;
        lengthSq += toLightZ * toLightZ;        
        // don't produce NaNs if some vertex position overlaps with the light
        // 如果顶点距离光源太近了，就微调一个很小的数作为他们的距离
        lengthSq = max(lengthSq, 0.000001);

        // NdotL
        // 计算顶点到四个光源连线在顶点法线方向上的投影
        float4 ndotl = 0;
        ndotl += toLightX * normal.x;   // 顶点到各光源x轴向量差在法线x分量的投影
        ndotl += toLightY * normal.y;
        ndotl += toLightZ * normal.z;
        // correct NdotL
        float4 corr = rsqrt(lengthSq);  // rsqrt 开平方 并求倒数
        ndotl = max (float4(0,0,0,0), ndotl * corr);    // 计算方向法线正在的投影
        // attenuation
        float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);   // 计算衰减
        float4 diff = ndotl * atten;        // 各光源的漫反射系数（法线方向投影） * 衰减
        // final color
        // 最终光照结果
        float3 col = 0;
        col += lightColor0 * diff.x;
        col += lightColor1 * diff.y;
        col += lightColor2 * diff.z;
        col += lightColor3 * diff.w;
        return col;
    }

    // Used in Vertex pass: Calculates diffuse lighting from lightCount lights. Specifying true to spotLight is more expensive
    // to calculate but lights are treated as spot lights otherwise they are treated as point lights.
    // 用在顶点着色器中，计算出光源产生的漫反射效果
    // vertex：定点给的顶点位置（模型空间）
    // normal：法线位置（模型空间）
    // lightCount：参与计算的光源的数量
    // spotLight：光源是不是聚光灯
    float3 ShadeVertexLightsFull (float4 vertex, float3 normal, int lightCount, bool spotLight)
    {
        // 计算观察空间的顶点位置、法线方向
        float3 viewpos = UnityObjectToViewPos (vertex.xyz);
        float3 viewN = normalize (mul ((float3x3)UNITY_MATRIX_IT_MV, normal));

        // 环境光颜色
        float3 lightColor = UNITY_LIGHTMODEL_AMBIENT.xyz;
        for (int i = 0; i < lightCount; i++) {
            // 顶点到光源的位置的向量
            float3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
            // 向量距离平方
            float lengthSq = dot(toLight, toLight);

            // don't produce NaNs if some vertex position overlaps with the light
            lengthSq = max(lengthSq, 0.000001);

            // 归一化后的顶点到光源的位置的向量
            toLight *= rsqrt(lengthSq);

            // 计算衰减
            float atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);
            // 聚光灯的衰减 需要考虑顶点的光线方向与聚光灯正前照射方向的夹角
            if (spotLight)
            {
                // toLight与聚光灯的正前照射方向的点积
                float rho = max (0, dot(toLight, unity_SpotDirection[i].xyz));
                float spotAtt = (rho - unity_LightAtten[i].x) * unity_LightAtten[i].y;
                atten *= saturate(spotAtt);
            }

            // 计算漫反射
            float diff = max (0, dot (viewN, toLight));
            lightColor += unity_LightColor[i].rgb * (diff * atten);
        }
        // 环境光 + 漫反射
        return lightColor;
    }

    // 指定四个非聚光灯光源使用ShadeVertexLightsFull计算光照
    float3 ShadeVertexLights (float4 vertex, float3 normal)
    {
        return ShadeVertexLightsFull (vertex, normal, 4, false);
    }


    // ********** 球谐函数计算方法 **********

    // normal should be normalized, w=1.0
    half3 SHEvalLinearL0L1 (half4 normal)
    {
        half3 x;

        // Linear (L1) + constant (L0) polynomial terms
        x.r = dot(unity_SHAr,normal);
        x.g = dot(unity_SHAg,normal);
        x.b = dot(unity_SHAb,normal);

        return x;
    }

    // normal should be normalized, w=1.0
    half3 SHEvalLinearL2 (half4 normal)
    {
        half3 x1, x2;
        // 4 of the quadratic (L2) polynomials
        half4 vB = normal.xyzz * normal.yzzx;
        x1.r = dot(unity_SHBr,vB);
        x1.g = dot(unity_SHBg,vB);
        x1.b = dot(unity_SHBb,vB);

        // Final (5th) quadratic (L2) polynomial
        half vC = normal.x*normal.x - normal.y*normal.y;
        x2 = unity_SHC.rgb * vC;

        return x1 + x2;
    }

    // normal should be normalized, w=1.0
    // output in active color space
    half3 ShadeSH9 (half4 normal)
    {
        // Linear + constant polynomial terms
        half3 res = SHEvalLinearL0L1 (normal);

        // Quadratic polynomials
        res += SHEvalLinearL2 (normal);

        #   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
        #   endif

        return res;
    }

    // OBSOLETE: for backwards compatibility with 5.0
    half3 ShadeSH3Order(half4 normal)
    {
        // Quadratic polynomials
        half3 res = SHEvalLinearL2 (normal);

        #   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
        #   endif

        return res;
    }

    #if UNITY_LIGHT_PROBE_PROXY_VOLUME

        // normal should be normalized, w=1.0
        half3 SHEvalLinearL0L1_SampleProbeVolume (half4 normal, float3 worldPos)
        {
            const float transformToLocal = unity_ProbeVolumeParams.y;
            const float texelSizeX = unity_ProbeVolumeParams.z;

            //The SH coefficients textures and probe occlusion are packed into 1 atlas.
            //-------------------------
            //| ShR | ShG | ShB | Occ |
            //-------------------------

            float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz : worldPos;
            float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
            texCoord.x = texCoord.x * 0.25f;

            // We need to compute proper X coordinate to sample.
            // Clamp the coordinate otherwize we'll have leaking between RGB coefficients
            float texCoordX = clamp(texCoord.x, 0.5f * texelSizeX, 0.25f - 0.5f * texelSizeX);

            // sampler state comes from SHr (all SH textures share the same sampler)
            texCoord.x = texCoordX;
            half4 SHAr = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

            texCoord.x = texCoordX + 0.25f;
            half4 SHAg = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

            texCoord.x = texCoordX + 0.5f;
            half4 SHAb = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

            // Linear + constant polynomial terms
            half3 x1;
            x1.r = dot(SHAr, normal);
            x1.g = dot(SHAg, normal);
            x1.b = dot(SHAb, normal);

            return x1;
        }
    #endif

    // normal should be normalized, w=1.0
    half3 ShadeSH12Order (half4 normal)
    {
        // Linear + constant polynomial terms
        half3 res = SHEvalLinearL0L1 (normal);

        #   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
        #   endif

        return res;
    }

    // ********** END **********


    // Transforms 2D UV by scale/bias property
    // 变换2D UV
    #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)

    // Deprecated. Used to transform 4D UV by a fixed function texture matrix. Now just returns the passed UV.
    #define TRANSFORM_UV(idx) v.texcoord.xy


    // 用在VertexLit渲染路径中执行光照计算
    // 用到一层纹理，并指定两种颜色来模拟漫反射颜色和镜面反射颜色
    // Vertex-Lit是实现最低保真度的光照且不支持实时阴影的渲染路径，用于旧机器或受限的移动平台上。
    // 通常在一个渲染通路中渲染物体，所有光源都是在顶点着色器上进行计算，不支持大部分逐片元渲染效果。
    struct v2f_vertex_lit {
        float2 uv   : TEXCOORD0;
        fixed4 diff : COLOR0;
        fixed4 spec : COLOR1;
    };

    // 在VertexLit渲染路径中执行光照计算
    inline fixed4 VertexLight( v2f_vertex_lit i, sampler2D mainTex )
    {
        fixed4 texcol = tex2D( mainTex, i.uv );
        fixed4 c;
        c.xyz = ( texcol.xyz * i.diff.xyz + i.spec.xyz * texcol.a );
        c.w = texcol.w * i.diff.w;
        return c;
    }

    // Calculates UV offset for parallax bump mapping
    // 根据当前片元对应的高度图中的高度值h，以及高度缩放系数 height 和切线空间中片元到摄像机的连线向量，
    // 计算到当前片元实际上要使用外观纹理的哪一点的纹理。
    // 视差贴图算法相关->
    inline float2 ParallaxOffset( half h, half height, half3 viewDir )
    {
        h = h * height - height/2.0;
        float3 v = normalize(viewDir);
        v.z += 0.42;
        return h * (v.xy / v.z);
    }

    // Converts color to luminance (grayscale)
    // 将一个RGB颜色转化成亮度值，基于伽马空间或者线性空间最终的结果不同
    inline half Luminance(half3 rgb)
    {
        return dot(rgb, unity_ColorSpaceLuminance.rgb);
    }

    // Convert rgb to luminance
    // with rgb in linear space with sRGB primaries and D65 white point
    // 将一个线性空间的RGB颜色值转换成亮度值
    // 它实质上就是把一个基于 RGB 颜色空间的颜色值变换到 CIE1931-Yxy 颜色空间中得到对应的亮度值Y ？？
    half LinearRgbToLuminance(half3 linearRgb)
    {
        return dot(linearRgb, half3(0.2126729f,  0.7151522f, 0.0721750f));
    }


    // 一般用于在HDR实现过程中，将渲染高精度的浮点渲染目标中的颜色数据，
    // 编码成一个能以8位颜色分量存储的数据的编码方式。这里是编码陈RGBM格式
    // color：RGB颜色分量的颜色值
    // maxRGBM：编码后的取值的最大范围值
    half4 UnityEncodeRGBM (half3 color, float maxRGBM)
    {
        float kOneOverRGBMMaxRange = 1.0 / maxRGBM;
        const float kMinMultiplier = 2.0 * 1e-2;    // 0.02

        // 将color的rgb分量各自除以maxRGBM
        float3 rgb = color * kOneOverRGBMMaxRange;
        // 求最大的数当作alpha
        float alpha = max(max(rgb.r, rgb.g), max(rgb.b, kMinMultiplier));
        alpha = ceil(alpha * 255.0) / 255.0;    // * 255.0 向上取整 再 / 255.0

        // Division-by-zero warning from d3d9, so make compiler happy.
        // 最小的alpha 控制在0.02
        alpha = max(alpha, kMinMultiplier);

        return half4(rgb / alpha, alpha);
    }

    // Decodes HDR textures
    // handles dLDR, RGBM formats
    // 解码HDR纹理
    // 处理dLDR、RGBM格式
    // dLDR：双重低动态范围编码格式一般用在移动平台上。把在[0, 2]范围的亮度值映射到[0, 1]范围内。
    inline half3 DecodeHDR (half4 data, half4 decodeInstructions)
    {
        // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
        // 当 decodeInstruction 的 w 分量为 true，即值为 1，要考虑 HDR 纹理中的
        // alpha 值对纹理的 RGB 值的影响，此时的 alpha 变量值为纹理的 alpha 值。如果
        // decodeInstruction 的 w 分量为 false，则 alpha 始终为 1
        half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;

        // If Linear mode is not supported we can skip exponent part
        #if defined(UNITY_COLORSPACE_GAMMA)
            // 使用伽马工作流
            return (decodeInstructions.x * alpha) * data.rgb;
        #else
            // 使用线性工作流
            #   if defined(UNITY_USE_NATIVE_HDR)
            return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
            #   else
            return (decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
            #   endif
        #endif
    }

    // Decodes HDR textures
    // handles dLDR, RGBM formats
    // 把一个RGBM颜色值解码成一个每通道8位的RGB颜色
    inline half3 DecodeLightmapRGBM (half4 data, half4 decodeInstructions)
    {
        // If Linear mode is not supported we can skip exponent part
        #if defined(UNITY_COLORSPACE_GAMMA)
            // 伽马工作流下
            # if defined(UNITY_FORCE_LINEAR_READ_FOR_RGBM)
            // 解码得到RGB颜色值为：倍数值M的x分量 * 源颜色值得A分量 * 源颜色值的RGB颜色值的各分量开平方
            return (decodeInstructions.x * data.a) * sqrt(data.rgb);
            # else
            // 解码得到RGB颜色值为：倍数值M的x分量 * 源颜色值得A分量 * 源颜色值的RGB颜色值的各分量
            return (decodeInstructions.x * data.a) * data.rgb;
            # endif
        #else
            return (decodeInstructions.x * pow(data.a, decodeInstructions.y)) * data.rgb;
        #endif
    }

    // Decodes doubleLDR encoded lightmaps.
    // 解码一个用dLDR编码得光照贴图
    inline half3 DecodeLightmapDoubleLDR( fixed4 color, half4 decodeInstructions)
    {
        // decodeInstructions.x contains 2.0 when gamma color space is used or pow(2.0, 2.2) = 4.59 when linear color space is used on mobile platforms
        // decodeInstructions.x 在伽马空间和线性空间得值是不一样的 线性 2.0 伽马 4.59
        return decodeInstructions.x * color.rgb;
    }

    // 根据当前的不同的宏定义 调用不同的方法解码color
    inline half3 DecodeLightmap( fixed4 color, half4 decodeInstructions)
    {
        #if defined(UNITY_LIGHTMAP_DLDR_ENCODING)
            return DecodeLightmapDoubleLDR(color, decodeInstructions);
        #elif defined(UNITY_LIGHTMAP_RGBM_ENCODING)
            return DecodeLightmapRGBM(color, decodeInstructions);
        #else //defined(UNITY_LIGHTMAP_FULL_HDR)
            return color.rgb;
        #endif
    }

    // 引擎底层传递给着色器得uniform变量
    // 猜测是一个解码RGBM编码颜色用得系数值
    half4 unity_Lightmap_HDR;

    inline half3 DecodeLightmap( fixed4 color )
    {
        return DecodeLightmap( color, unity_Lightmap_HDR );
    }

    half4 unity_DynamicLightmap_HDR;

    // Decodes Enlighten RGBM encoded lightmaps
    // NOTE: Enlighten dynamic texture RGBM format is _different_ from standard Unity HDR textures
    // (such as Baked Lightmaps, Reflection Probes and IBL images)
    // Instead Enlighten provides RGBM texture in _Linear_ color space with _different_ exponent.
    // WARNING: 3 pow operations, might be very expensive for mobiles!
    // 该函数对Enlighten中间件实时生成的光照贴图进行解码，
    // 格式不同于一般的 Unity 3D 的 HDR 纹理。例如，烘焙式光照贴图、反射用光探针，还有 IBL 图像等
    // Englithen 渲染器的 RGBM 格式纹理是在线性颜色空间中定义颜色，使用了不同的指数操作
    // 要将其还原成 RGB 颜色需要做以下操作
    inline half3 DecodeRealtimeLightmap( fixed4 color )
    {
        //@TODO: Temporary until Geomerics gives us an API to convert lightmaps to RGBM in gamma space on the enlighten thread before we upload the textures.
        #if defined(UNITY_FORCE_LINEAR_READ_FOR_RGBM)
            return pow ((unity_DynamicLightmap_HDR.x * color.a) * sqrt(color.rgb), unity_DynamicLightmap_HDR.y);
        #else
            return pow ((unity_DynamicLightmap_HDR.x * color.a) * color.rgb, unity_DynamicLightmap_HDR.y);
        #endif
    }

    /*
    Unity 3D 使用优势定向辐射入射度（dominant directional irradiance）技术实现了定向光照贴图。
    该方法的原理是将采样点半球空间中的辐射入射度信息处理为一个有向平行光，
    在实时渲染中就可以使用反射模型进行快速还原；其中的 dominant axis 可以看作该有向平行光的方向。
    Decode DirectionalLightmap 函数就是实现了这个还原操作。
    从光照贴图中采样得到的辐射入射度的信息是有向平行光的方向和颜色，即函数的参数 color 和参数 dirTex。
    在渲染过程中使用某一反射模型，如使用代码中的半朗伯光照模型来还原光照颜色。
    在一般情况下也会使用方向贴图的空闲的w分量来存储一个缩放因子，
    用来控制该点上辐射入射度的方向性，即被 dominant 方向影响的程度。
    */
    inline half3 DecodeDirectionalLightmap (half3 color, fixed4 dirTex, half3 normalWorld)
    {
        // In directional (non-specular) mode Enlighten bakes dominant light direction
        // in a way, that using it for half Lambert and then dividing by a "rebalancing coefficient"
        // gives a result close to plain diffuse response lightmaps, but normalmapped.

        // Note that dir is not unit length on purpose. Its length is "directionality", like
        // for the directional specular lightmaps.

        half halfLambert = dot(normalWorld, dirTex.xyz - 0.5) + 0.5;

        return color * halfLambert / max(1e-4h, dirTex.w);
    }

    // ********** 把高精度数据编码到低精度缓冲区的函数 **********

    // Encoding/decoding [0..1) floats into 8 bit/channel RGBA. Note that 1.0 will not be encoded properly.
    // 把一个在区间[0, 1]内的浮点数编码成一个float4类型的RGBA值
    inline float4 EncodeFloatRGBA( float v )
    {
        float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
        float kEncodeBit = 1.0/255.0;
        float4 enc = kEncodeMul * v;
        enc = frac (enc);   // 取小数部分
        enc -= enc.yzww * kEncodeBit;
        // 返回的是一个每分量的浮点数数值都在区间[0,1]内的浮点数
        return enc;
    }

    // 把一个 float4 类型的 RBGA 纹素值解码成一个 float 类型的浮点数
    inline float DecodeFloatRGBA( float4 enc )
    {
        float4 kDecodeDot = float4(1.0, 1/255.0, 1/65025.0, 1/16581375.0);
        return dot( enc, kDecodeDot );
    }

    // Encoding/decoding [0..1) floats into 8 bit/channel RG. Note that 1.0 will not be encoded properly.
    // 只使用两个通道进行编码
    inline float2 EncodeFloatRG( float v )
    {
        float2 kEncodeMul = float2(1.0, 255.0);
        float kEncodeBit = 1.0/255.0;
        float2 enc = kEncodeMul * v;
        enc = frac (enc);
        enc.x -= enc.y * kEncodeBit;
        return enc;
    }
    inline float DecodeFloatRG( float2 enc )
    {
        float2 kDecodeDot = float2(1.0, 1/255.0);
        return dot( enc, kDecodeDot );
    }


    // Encoding/decoding view space normals into 2D 0..1 vector
    // 使用球极投影将观察空间中的物体的法线映射为一个2D纹理坐标值坐标
    // 球级投影：->
    inline float2 EncodeViewNormalStereo( float3 n )
    {
        float kScale = 1.7777;  // 依赖摄像机视截体的FOV值，1.7777 是视截体高宽比为16：9时得到的
        float2 enc;
        enc = n.xy / (n.z+1);
        enc /= kScale;      // 为了纹理效果尽可能好，球极投影应除以一个缩放值后在编码到纹理中
        enc = enc*0.5+0.5;  // 将[-1,1]映射到[0,1]范围
        return enc;
    }
    inline float3 DecodeViewNormalStereo( float4 enc4 )
    {
        float kScale = 1.7777;
        float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
        float g = 2.0 / dot(nn.xyz,nn.xyz);
        float3 n;
        n.xy = g*nn.xy;
        n.z = g-1;
        return n;
    }

    inline float4 EncodeDepthNormal( float depth, float3 normal )
    {
        float4 enc;
        // 将法线编码到一个float4类型的前两个分量
        enc.xy = EncodeViewNormalStereo (normal);
        // 将深度值编码进float4类型分量的后两个分量
        enc.zw = EncodeFloatRG (depth);
        return enc;
    }

    inline void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
    {
        depth = DecodeFloatRG (enc.zw);
        normal = DecodeViewNormalStereo (enc);
    }

    // ********** END **********

    // ********** 法线贴图及其编解码操作的函数 **********
    /*
    DXT是一种纹理压缩格式,以前称为S3TC当前很多图形硬件已经支持这种格式,
    即在显存中依然保持着压缩格式,从而减少显存占用量。
    目前有DXT1 ~ 5[5]这5种编码格式,在DirectX10及后续版本中,这系列格式称为块状压缩(块压缩),
    所以DXT1称为群体BC1、DXT2 ~ 3称为BC2、DXT4 ~ 5称为BC3。
    要使用 DXT 格式压缩图像，要求图像大小至少是 4×4 纹素，而且图像高宽的纹素个数是 2 的整数次幂，
    如 32×32、64×128 等。
    DXT5nm 格式和 BC5 格式类似，当把一个法线存储进 DXT5nm 或者 BC5 格式的法线贴图时，
    该贴图的 RGBA 纹素的各个通道对应存储的法线的分量是（1，y,1,x）或（x,y,0,1）。
    */

    // 解码DXT5nm格式的法线贴图
    inline fixed3 UnpackNormalDXT5nm (fixed4 packednormal)
    {
        fixed3 normal;
        normal.xy = packednormal.wy * 2 - 1;
        normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
        return normal;
    }

    // Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
    // Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
    // 请注意，“bump”之类的中性纹理为（0、0、1、1），可以与普通RGB普通色和DXT5nm / BC5一起使用
    // 能够处理DXT5nm和BC5两种格式的法线贴图，并正确地把法线扰动向量从纹素中解码出来
    fixed3 UnpackNormalmapRGorAG(fixed4 packednormal)
    {
        // This do the trick
        // 确保无论是哪个压缩格式，packednormal的x分量最后值就是扰动向量的x
        packednormal.x *= packednormal.w;

        fixed3 normal;
        normal.xy = packednormal.xy * 2 - 1;    // [0,1] -> [-1,1]
        normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
        return normal;
    }
    inline fixed3 UnpackNormal(fixed4 packednormal)
    {
        #if defined(UNITY_NO_DXT5nm)
            // 不使用DXT5nm格式去压缩法线贴图
            // 只需要把表示颜色的[0,1]范围映射到表示向量的[-1,1]范围即可
            return packednormal.xyz * 2 - 1;
        #else
            // 使用了DXT5nm或者BC5压缩格式的法线纹理贴图
            return UnpackNormalmapRGorAG(packednormal);
        #endif
    }

    fixed3 UnpackNormalWithScale(fixed4 packednormal, float scale)
    {
        #ifndef UNITY_NO_DXT5nm
            // Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
            // Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
            packednormal.x *= packednormal.w;
        #endif
        fixed3 normal;
        normal.xy = (packednormal.xy * 2 - 1) * scale;
        normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
        return normal;
    }

    // ********** END **********
    
    // 线性化深度值的工具函数
    // Z buffer to linear 0..1 depth
    // 把从深度纹理中取得的顶点深度值z变换到观察空间中（一个线性区域），然后映射到[0,1]区间内，下面得公式需要推导
    // _ZBufferParams.x -> 1 - 视截体远截面值与近截面值得商
    // _ZBufferParams.y -> 视截体远截面值与近截面值得商
    inline float Linear01Depth( float z )
    {
        return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
    }
    // Z buffer to linear depth
    // 把从深度纹理中取得的深度值z变换到观察空间中  并没有映射到[0,1]区间内
    // _ZBufferParams.w -> y分量除以视截体远截面值
    inline float LinearEyeDepth( float z )
    {
        return 1.0 / (_ZBufferParams.z * z + _ZBufferParams.w);
    }

    // ********** 合并单程立体渲染时的左右眼图像到一张纹理的函数 **********

    /*
    使用 C#层运行期 API 函数 Graphics.Blit()函数进行后处理效果（post-processing effect）时，
    如果启用了单程立体渲染，则 Blit 函数中用到的纹理采样器（texture sampler）是不能自动地
    在由两个左右眼图像合并而成的可渲染纹理中进行定位采样的。所以，如果要正确使用该可渲染纹理，
    需要告诉着色器在采样左（右）眼对应的纹理内容时要做多少缩放和偏移。
    UnityStereoScreenSpaceUVAdjustInternal函数就是用来做这件事情的
    */
    inline float2 UnityStereoScreenSpaceUVAdjustInternal(float2 uv, float4 scaleAndOffset)
    {
        return uv.xy * scaleAndOffset.xy + scaleAndOffset.zw;
    }

    inline float4 UnityStereoScreenSpaceUVAdjustInternal(float4 uv, float4 scaleAndOffset)
    {
        return float4(UnityStereoScreenSpaceUVAdjustInternal(uv.xy, scaleAndOffset), UnityStereoScreenSpaceUVAdjustInternal(uv.zw, scaleAndOffset));
    }

    #define UnityStereoScreenSpaceUVAdjust(x, y) UnityStereoScreenSpaceUVAdjustInternal(x, y)

    #if defined(UNITY_SINGLE_PASS_STEREO)
        // 对单程立体渲染用到的左右眼图像，放到一张可渲染纹理的左右两边时要做的缩放和偏移操作
        float2 TransformStereoScreenSpaceTex(float2 uv, float w)
        {
            float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
            return uv.xy * scaleOffset.xy + scaleOffset.zw * w;
        }

        inline float2 UnityStereoTransformScreenSpaceTex(float2 uv)
        {
            return TransformStereoScreenSpaceTex(saturate(uv), 1.0);
        }

        // 把两组 uv 坐标打包进一个 float4 类型的参数
        // 并把返回结果值打包进 float4 类型变量中返回
        inline float4 UnityStereoTransformScreenSpaceTex(float4 uv)
        {
            return float4(UnityStereoTransformScreenSpaceTex(uv.xy), UnityStereoTransformScreenSpaceTex(uv.zw));
        }

        // scaleAndOffset 的 x、y 分量包含对纹理的缩放操作参数，z、w 分量包含对纹理的偏移操作参数。
        // 本函数把原始的 uv 坐标的 u 分量限定在缩放范围内
        inline float2 UnityStereoClamp(float2 uv, float4 scaleAndOffset)
        {
            // uv.x 限定在 scaleAndOffset.z 到 scaleAndOffset.z + scaleAndOffset.x 范围内
            return float2(clamp(uv.x, scaleAndOffset.z, scaleAndOffset.z + scaleAndOffset.x), uv.y);
        }
    #else
        // 如果不使用单程立体渲染，则前面定义的函数不做任何操作
        #define TransformStereoScreenSpaceTex(uv, w) uv
        #define UnityStereoTransformScreenSpaceTex(uv) uv
        #define UnityStereoClamp(uv, scaleAndOffset) uv
    #endif

    // ********** END **********


    // ********** 操作深度纹理的工具宏 **********

    // Depth render texture helpers
    #define DECODE_EYEDEPTH(i) LinearEyeDepth(i)
    // 取得模型空间的顶点到观察空间中的z值 并取其相反数
    #define COMPUTE_EYEDEPTH(o) o = -UnityObjectToViewPos( v.vertex ).z
    // 取得模型空间的顶点到观察空间中的z值，取反，并映射到[0,1]范围，
    #define COMPUTE_DEPTH_01 -(UnityObjectToViewPos( v.vertex ).z * _ProjectionParams.w)
    // 把顶点法线，从模型空间变换到观察空间
    #define COMPUTE_VIEW_NORMAL normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal))

    // ********** END **********

    // ********** 用来实现图像效果的工具函数和预定义结构体 ********** 
    // Helpers used in image effects. Most image effects use the same minimal vertex shader (vert_img).
    //图像效果中使用的辅助对象。 大多数图像效果使用相同的最小顶点着色器（vert_img）。

    // 顶点着色器用到的一些简单的顶点描述结构
    struct appdata_img
    {
        float4 vertex : POSITION;           // 顶点的齐次化位置坐标（就是模型空间的顶点坐标吧）
        half2 texcoord : TEXCOORD0;         // 顶点用到的第一层纹理映射坐标
        UNITY_VERTEX_INPUT_INSTANCE_ID      // 硬件instance id值
    };

    // 从顶点着色器返回，传递给片元着色器使用
    struct v2f_img
    {
        float4 pos : SV_POSITION;           // 要传递给片元着色器的顶点坐标，已转换到裁剪空间中
        half2 uv : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO          // 立体渲染时的左右眼索引（此宏在UnityInstancing.cginc文件中定义）
    };

    // 将uv坐标从一个空间变换到另一个空间（右乘一个变换矩阵）
    float2 MultiplyUV (float4x4 mat, float2 inUV) {
        float4 temp = float4 (inUV.x, inUV.y, 0, 0);
        temp = mul (mat, temp);
        return temp.xy;
    }

    // 大多数图像效果使用的相同最小顶点着色器入口函数
    v2f_img vert_img( appdata_img v )
    {
        v2f_img o;
        UNITY_INITIALIZE_OUTPUT(v2f_img, o);    // -> v2f_img = (o)0;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.pos = UnityObjectToClipPos (v.vertex);
        o.uv = v.texcoord;
        return o;
    }

    // ********** END **********


    // ********** 计算屏幕坐标的工具函数 **********
    // Projected screen position helpers
    #define V2F_SCREEN_TYPE float4

    // pos：-> 裁剪空间中的一个齐次坐标值，易知此时的pos.x与pos.y的取值范围是[-pos.w，pos.w]
    // （不使用立体渲染时，该方法才有效）
    // 将裁剪空间中的齐次坐标的x、y值变换到[0,pos.w]范围内（并没有生成在屏幕坐标系下的坐标值）
    inline float4 ComputeNonStereoScreenPos(float4 pos) {
        float4 o = pos * 0.5f;      // 将pos坐标取值范围缩小
        o.xy = float2(o.x, o.y*_ProjectionParams.x) + o.w;
        o.zw = pos.zw;
        return o;
    }

    // 限制裁剪空间的齐次坐标pos值（x、y分量变换到[0,pos.w]），并在立体渲染时进行缩放和偏移
    inline float4 ComputeScreenPos(float4 pos) {
        float4 o = ComputeNonStereoScreenPos(pos);
        #if defined(UNITY_SINGLE_PASS_STEREO)
            o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
        #endif
        return o;
    }

    // 当把当前屏幕内容截屏并保存在一个目标纹理时，计算裁剪空间中某一点将会对应保存在目标纹理中的哪一点？？？
    // pos：基于裁剪空间的齐次坐标
    // 传递进来在裁剪空间中某点的齐次坐标值，返回该点在目标纹理中的【纹理贴图坐标】
    // 疑问，纹理贴图坐标不应该是[0,1]嘛？ 这里为什么纹理坐标可以是 [0, pos.w]
    // 所以这里的纹理坐标怎么理解？需要再除pos.w分量？有这么算的嘛？
    inline float4 ComputeGrabScreenPos (float4 pos) {
        //将给定的裁剪空间的pos，根据不同的平台，将pos的x，y分量分别限定在相应的范围内
        // scale = -1.0，pos.x -> [0, pos.w], pos.y -> [pos.w, 0]  // 注意为-1.0时 范围没变，只是顺序变了
        // scale = 1.0, pos.x -> [0, pos.w], pos.x -> [0, pos.w]
        #if UNITY_UV_STARTS_AT_TOP
            float scale = -1.0;
        #else
            float scale = 1.0;
        #endif
        float4 o = pos * 0.5f;
        o.xy = float2(o.x, o.y*scale) + o.w;    

        // 单程立体渲染 -> 进一步处理tilling、offset
        #ifdef UNITY_SINGLE_PASS_STEREO
            o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
        #endif
        o.zw = pos.zw;
        return o;
    }

    // snaps post-transformed position to screen pixels
    // 真正把视口坐标（裁剪空间齐次坐标？？）转换为屏幕像素坐标的函数
    // 这里的pos参数，是什么？ComputeNonStereoScreenPos限定过的，还是裁剪空间的齐次坐标？还是视口坐标
    inline float4 UnityPixelSnap (float4 pos)
    {
        // 屏幕宽高的一半
        float2 hpc = _ScreenParams.xy * 0.5f;
        #if  SHADER_API_PSSL
            // sdk 4.5 splits round into v_floor_f32(x+0.5) ... sdk 5.0 uses v_rndne_f32, for compatabilty we use the 4.5 version
            // sdk 4.5拆分为v_floor_f32（x + 0.5）... sdk 5.0使用v_rndne_f32，为了兼容，我们使用4.5版本
            // 透视除法 * 屏幕的高、宽 
            // 为什么 +  float2(0.5f,0.5f);  放到像素的中间位置？解决半像素偏移问题？
            float2 temp = ((pos.xy / pos.w) * hpc) + float2(0.5f,0.5f);
            float2 pixelPos = float2(__v_floor_f32(temp.x), __v_floor_f32(temp.y));
        #else
            float2 pixelPos = round ((pos.xy / pos.w) * hpc);   // 四舍五入取整
        #endif
        // 这里又是什么意思呢？
        pos.xy = pixelPos / hpc * pos.w;
        return pos;
    }

    // 将向量从观察空间变换到裁剪空间
    inline float2 TransformViewToProjection (float2 v) {
        return mul((float2x2)UNITY_MATRIX_P, v);
    }

    // 将向量从观察空间变换到裁剪空间
    inline float3 TransformViewToProjection (float3 v) {
        return mul((float3x3)UNITY_MATRIX_P, v);
    }

    // ********** END **********

    // ********** 与阴影处理相关的工具函数 **********
    // Shadow caster pass helpers

    // 把一个float类型的阴影深度值编码进一个float4类型的RGBA数值中
    float4 UnityEncodeCubeShadowDepth (float z)
    {
        #ifdef UNITY_USE_RGBA_FOR_POINT_SHADOWS
            return EncodeFloatRGBA (min(z, 0.999));
        #else
            return z;
        #endif
    }

    // 把一个float4类型的阴影深度值解码到一个float类型的浮点数中
    float UnityDecodeCubeShadowDepth (float4 vals)
    {
        #ifdef UNITY_USE_RGBA_FOR_POINT_SHADOWS
            return DecodeFloatRGBA (vals);
        #else
            return vals.r;
        #endif
    }

    // 将阴影投射者（shadow caster）的坐标沿着其法线做了一定偏移之后再变换至裁剪空间。
    // 根据法线与光线的夹角的正弦值，计算得到用于消除阴影渗漏的合适的偏移值，并将vertex沿法线方向偏移
    // vertex：模型空间顶点的位置
    // normal：模型空间法线的位置
    float4 UnityClipSpaceShadowCasterPos(float4 vertex, float3 normal)
    {
        // 世界空间顶点坐标
        float4 wPos = mul(unity_ObjectToWorld, vertex);

        if (unity_LightShadowBias.z != 0.0)
        {   
            // 世界空间法线
            float3 wNormal = UnityObjectToWorldNormal(normal);
            // 归一化后的世界空间光线方向
            float3 wLight = normalize(UnityWorldSpaceLightDir(wPos.xyz));

            // apply normal offset bias (inset position along the normal)
            // bias needs to be scaled by sine between normal and light direction
            // (http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/)
            //
            // unity_LightShadowBias.z contains user-specified normal offset amount
            // scaled by world space texel size.
            // unity_LightShadowBias.z包含用户指定的标准偏移量，该偏移量通过世界空间纹理像素大小缩放。

            // 法线与光线的夹角的三角函数值
            float shadowCos = dot(wNormal, wLight);
            float shadowSine = sqrt(1-shadowCos*shadowCos);
            // 计算偏移量
            float normalBias = unity_LightShadowBias.z * shadowSine;

            // 把顶点坐标，沿法线方向进行偏移
            wPos.xyz -= wNormal * normalBias;
        }
        
        // 将偏移后的值变换回裁剪空间
        return mul(UNITY_MATRIX_VP, wPos);
    }
    // Legacy, not used anymore; kept around to not break existing user shaders
    // 遗留的方法
    float4 UnityClipSpaceShadowCasterPos(float3 vertex, float3 normal)
    {
        return UnityClipSpaceShadowCasterPos(float4(vertex, 1), normal);
    }

    
    /*
    该函数将调用 UnityClipSpaceShadowCasterPos 函数得到的裁剪空间坐标的z值再做一定的增加
    因为这个增加操作是在裁剪空间这样的齐次坐标系下进行的所以要对透视投影产生的z值进行补偿，
    使得阴影偏移值不会随着与摄像机的距离的变化而变化，
    同时必须保证增加的z值不能超出裁剪空间的远近截面z值。
    */
    float4 UnityApplyLinearShadowBias(float4 clipPos)
    {
        // For point lights that support depth cube map, the bias is applied in the fragment shader sampling the shadow map.
        // This is because the legacy behaviour for point light shadow map cannot be implemented by offseting the vertex position
        // in the vertex shader generating the shadow map.
        // 对于支持深度立方体贴图的点光源，在对阴影贴图进行采样的【片段着色器】中应用该偏差。
        // 这是因为无法通过偏移生成阴影贴图的顶点着色器中的顶点位置来实现点光源阴影贴图的传统行为。
        #if !(defined(SHADOWS_CUBE) && defined(SHADOWS_CUBE_IN_DEPTH_TEX))
            #if defined(UNITY_REVERSED_Z)
                // We use max/min instead of clamp to ensure proper handling of the rare case
                // where both numerator and denominator are zero and the fraction becomes NaN.
                // 我们使用max / min代替clamp，以确保正确处理分子和分母均为零且分数变为NaN（非数或不可表示的值）的罕见情况。
                clipPos.z += max(-1, min(unity_LightShadowBias.x / clipPos.w, 0));
            #else
                clipPos.z += saturate(unity_LightShadowBias.x/clipPos.w);
            #endif
        #endif

        #if defined(UNITY_REVERSED_Z)
            float clamped = min(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
        #else
            float clamped = max(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
        #endif
        // 根据第一次增加后的z值和z的极值，进行线性插值
        clipPos.z = lerp(clipPos.z, clamped, unity_LightShadowBias.y);
        return clipPos;
    }


    #if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
        // Rendering into point light (cubemap) shadows
        // 渲染由点光源产生的立方体阴影

        // 用来存储在世界坐标系下当前顶点到光源位置的连线向量
        #define V2F_SHADOW_CASTER_NOPOS float3 vec : TEXCOORD0;
        #define TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,opos) o.vec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz; opos = UnityObjectToClipPos(v.vertex);
        // _LightPositionRange x、y、z 分量为光源的位置，w分量为光源的照射范围的倒数，
        // 计算在世界坐标系下当前顶点到光源位置的连线向量，同时把顶点位置变换到裁剪空间。
        #define TRANSFER_SHADOW_CASTER_NOPOS(o,opos) o.vec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz; opos = UnityObjectToClipPos(v.vertex);
        // 把一个 float 类型的阴影深度值编码到一个 float4 类型中并返回
        #define SHADOW_CASTER_FRAGMENT(i) return UnityEncodeCubeShadowDepth ((length(i.vec) + unity_LightShadowBias.x) * _LightPositionRange.w);

    #else
        // Rendering into directional or spot light shadows
        // 渲染由平行光或者聚光灯光源产生的阴影

        #define V2F_SHADOW_CASTER_NOPOS
        // Let embedding code know that V2F_SHADOW_CASTER_NOPOS is empty; so that it can workaround
        // empty structs that could possibly be produced.
        // 让嵌入代码知道V2F_SHADOW_CASTER_NOPOS为空； 这样就可以解决可能产生的空结构。
        #define V2F_SHADOW_CASTER_NOPOS_IS_EMPTY
        #define TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,opos) \
        opos = UnityObjectToClipPos(v.vertex.xyz); \    // 模型空间 -> 裁剪空间
        opos = UnityApplyLinearShadowBias(opos);        // 裁剪空间坐标z值做一定的增加
        #define TRANSFER_SHADOW_CASTER_NOPOS(o,opos) \
        opos = UnityClipSpaceShadowCasterPos(v.vertex, v.normal); \     
        opos = UnityApplyLinearShadowBias(opos);
        #define SHADOW_CASTER_FRAGMENT(i) return 0;
    #endif

    // Declare all data needed for shadow caster pass output (any shadow directions/depths/distances as needed),
    // plus clip space position.
    // 声明阴影投射器pass输出所需的所有数据（所需的任何阴影方向/深度/距离）以及剪辑空间位置。
    #define V2F_SHADOW_CASTER V2F_SHADOW_CASTER_NOPOS UNITY_POSITION(pos)

    // Vertex shader part, with support for normal offset shadows. Requires
    // position and normal to be present in the vertex input.
    // 顶点着色器部件，支持普通的偏移阴影。 要求位置和法线出现在顶点输入中。
    #define TRANSFER_SHADOW_CASTER_NORMALOFFSET(o) TRANSFER_SHADOW_CASTER_NOPOS(o,o.pos)

    // Vertex shader part, legacy. No support for normal offset shadows - because
    // that would require vertex normals, which might not be present in user-written shaders.
    // 顶点着色器部分，旧版。 
    // 不支持法线偏移阴影-因为这将需要顶点法线，而在用户编写的着色器中可能不存在。
    #define TRANSFER_SHADOW_CASTER(o) TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,o.pos)

    // ********** END **********

    // ------------------------------------------------------------------
    //  Alpha helper

    #define UNITY_OPAQUE_ALPHA(outputAlpha) outputAlpha = 1.0


    // ********** 与雾效果相关的工具函数和宏 **********
    // ------------------------------------------------------------------
    //  Fog helpers
    //
    //  multi_compile_fog Will compile fog variants.
    //  UNITY_FOG_COORDS(texcoordindex) Declares the fog data interpolator.
    //  UNITY_TRANSFER_FOG(outputStruct,clipspacePos) Outputs fog data from the vertex shader.
    //  UNITY_APPLY_FOG(fogData,col) Applies fog to color "col". Automatically applies black fog when in forward-additive pass.
    //  Can also use UNITY_APPLY_FOG_COLOR to supply your own fog color.

    // In case someone by accident tries to compile fog code in one of the g-buffer or shadow passes:
    // treat it as fog is off.
    #if defined(UNITY_PASS_PREPASSBASE) || defined(UNITY_PASS_DEFERRED) || defined(UNITY_PASS_SHADOWCASTER)
        #undef FOG_LINEAR
        #undef FOG_EXP
        #undef FOG_EXP2
    #endif

    /*
        在计算雾化因子时，需要取得当前片元和摄像机的距离的绝对值，并且离摄像机越远这个值要越大。
        而这个距离的绝对值要通过片元在裁剪空间中的z值计算得到。
        在不同平台下，裁剪空间的z取值范围有所不同。
        所以 UNITY_Z_0_FAR_FROM_CLIPSPACE 宏就是把各个平台的差异化给处理掉。
    */
    #if defined(UNITY_REVERSED_Z)
        #if UNITY_REVERSED_Z == 1
            //D3d with reversed Z => z clip range is [near, 0] -> remapping to [0, far]
            //max is required to protect ourselves from near plane not being correct/meaningfull in case of oblique matrices.
            // Z取反的D3d => z片段范围为[near，0]->重新映射为[0，far] 
            // max是为了保护我们自己免受近平面的影响（如果是倾斜矩阵的话）
            #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(((1.0-(coord)/_ProjectionParams.y)*_ProjectionParams.z),0)
        #else
            //GL with reversed z => z clip range is [near, -far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
            // z反转的GL => z片段范围是[near，-far]
            // ->理论上应该重新映射，但实际上不要这样做以节省一些性能（范围足够近），直接对坐标值取反即可
            #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(-(coord), 0)
        #endif
    #elif UNITY_UV_STARTS_AT_TOP
        //D3d without reversed z => z clip range is [0, far] -> nothing to do
        // 没有反转z的D3d => z剪辑范围是[0，far]-> 什么都不用做
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
    #else
        //Opengl => z clip range is [-near, far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
        // 没有z反转的GL => z片段范围是[-near，far]
        // ->理论上应该重新映射，但实际上不要这样做以节省一些性能（范围足够近）
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
    #endif

    // 不同雾化因子计算方式下UNITY_CALC_FOG_FACTOR_RAW宏的实现
    #if defined(FOG_LINEAR)
        // 雾化因子线性化衰减
        // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
        #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = (coord) * unity_FogParams.z + unity_FogParams.w
    #elif defined(FOG_EXP)
        // 雾化因子指数衰减
        // factor = exp(-density*z)     exp2是以2为底数的指数函数
        #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = unity_FogParams.y * (coord); unityFogFactor = exp2(-unityFogFactor)
    #elif defined(FOG_EXP2)
        // 雾化因子指数平方衰减
        // factor = exp(-(density*z)^2)
        #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = unity_FogParams.x * (coord); unityFogFactor = exp2(-unityFogFactor*unityFogFactor)
    #else
        // 不启用雾化效果，雾化因子为0
        #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = 0.0
    #endif

    // 封装了上面的两个宏定义，计算雾化因子
    // coord -> 未经透视除法的裁剪空间中的坐标值z分量
    #define UNITY_CALC_FOG_FACTOR(coord) UNITY_CALC_FOG_FACTOR_RAW(UNITY_Z_0_FAR_FROM_CLIPSPACE(coord))

    // 利用顶点格式声明中的纹理坐标语义，借用一个纹理坐标寄存器【把雾化因子声明在一个顶点格式结构体中】。
    // 如果使用 UNITY_FOG_COORDS_ PACKED 宏，则在顶点着色器中计算雾化效果。
    #define UNITY_FOG_COORDS_PACKED(idx, vectype) vectype fogCoord : TEXCOORD##idx;

    // 不同平台下和不同雾化因子计算方式下 UNITY_TRANSFER_FOG 宏定义
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #define UNITY_FOG_COORDS(idx) UNITY_FOG_COORDS_PACKED(idx, float1)

        #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
            // mobile or SM2.0: calculate fog factor per-vertex
            // 如果使用移动平台或者使用 shade model 2.0 的平台，则在顶点中计算雾化效果
            #define UNITY_TRANSFER_FOG(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.fogCoord.x = unityFogFactor
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.tSpace1.y = tangentSign; o.tSpace2.y = unityFogFactor
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.worldPos.w = unityFogFactor
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.eyeVec.w = unityFogFactor
        #else
            // SM3.0 and PC/console: calculate fog distance per-vertex, and fog factor per-pixel
            // 如果是使用 shader model 3.0 的平台，或者使用 PC 以及一些游戏主机平台，
            // 就在顶点着色器中计算每个顶点离当前摄像机的距离。在片元着色器中计算雾化因子。
            #define UNITY_TRANSFER_FOG(o,outpos) o.fogCoord.x = (outpos).z
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos) o.tSpace2.y = (outpos).z
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos) o.worldPos.w = (outpos).z
            #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos) o.eyeVec.w = (outpos).z
        #endif
    #else
        #define UNITY_FOG_COORDS(idx)
        #define UNITY_TRANSFER_FOG(o,outpos)
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos)
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos)
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos)
    #endif

    // 利用雾的颜色和当前像素的颜色，根据雾化因子进行线性插值运算，得到最终的雾化效果颜色
    #define UNITY_FOG_LERP_COLOR(col,fogCol,fogFac) col.rgb = lerp((fogCol).rgb, (col).rgb, saturate(fogFac))

    // 在不同平台上的最终雾化效果的颜色计算方法 UNITY_APPLY_FOG_COLOR 的宏定义
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
            // mobile or SM2.0: fog factor was already calculated per-vertex, so just lerp the color
            // 在移动平台或者使用 shader model 2.0 的平台中，因为雾化因子已经在顶点着色器中计算过了，
            // 所以直接在片元着色器中插值以计算雾化效果颜色
            #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_FOG_LERP_COLOR(col,fogCol,(coord).x)
        #else
            // SM3.0 and PC/console: calculate fog factor and lerp fog color
            //  如果是 PC 或者游戏主机平台，或者是使用 shader model 3.0 的平台将在片元着色器中计算雾化因子，
            // 然后在片元着色器中通过插值计算雾化效果的颜色
            #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_CALC_FOG_FACTOR((coord).x); UNITY_FOG_LERP_COLOR(col,fogCol,unityFogFactor)
        #endif
        #define UNITY_EXTRACT_FOG(name) float _unity_fogCoord = name.fogCoord
        #define UNITY_EXTRACT_FOG_FROM_TSPACE(name) float _unity_fogCoord = name.tSpace2.y
        #define UNITY_EXTRACT_FOG_FROM_WORLD_POS(name) float _unity_fogCoord = name.worldPos.w
        #define UNITY_EXTRACT_FOG_FROM_EYE_VEC(name) float _unity_fogCoord = name.eyeVec.w
    #else
        #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol)
        #define UNITY_EXTRACT_FOG(name)
        #define UNITY_EXTRACT_FOG_FROM_TSPACE(name)
        #define UNITY_EXTRACT_FOG_FROM_WORLD_POS(name)
        #define UNITY_EXTRACT_FOG_FROM_EYE_VEC(name)
    #endif

    #ifdef UNITY_PASS_FORWARDADD
        #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,fixed4(0,0,0,0))
    #else
        #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,unity_FogColor)
    #endif

    // ********** END **********


    // ------------------------------------------------------------------
    //  TBN helpers
    #define UNITY_EXTRACT_TBN_0(name) fixed3 _unity_tbn_0 = name.tSpace0.xyz
    #define UNITY_EXTRACT_TBN_1(name) fixed3 _unity_tbn_1 = name.tSpace1.xyz
    #define UNITY_EXTRACT_TBN_2(name) fixed3 _unity_tbn_2 = name.tSpace2.xyz

    #define UNITY_EXTRACT_TBN(name) UNITY_EXTRACT_TBN_0(name); UNITY_EXTRACT_TBN_1(name); UNITY_EXTRACT_TBN_2(name)

    #define UNITY_EXTRACT_TBN_T(name) fixed3 _unity_tangent = fixed3(name.tSpace0.x, name.tSpace1.x, name.tSpace2.x)
    #define UNITY_EXTRACT_TBN_N(name) fixed3 _unity_normal = fixed3(name.tSpace0.z, name.tSpace1.z, name.tSpace2.z)
    #define UNITY_EXTRACT_TBN_B(name) fixed3 _unity_binormal = cross(_unity_normal, _unity_tangent)
    #define UNITY_CORRECT_TBN_B_SIGN(name) _unity_binormal *= name.tSpace1.y;
    #define UNITY_RECONSTRUCT_TBN_0 fixed3 _unity_tbn_0 = fixed3(_unity_tangent.x, _unity_binormal.x, _unity_normal.x)
    #define UNITY_RECONSTRUCT_TBN_1 fixed3 _unity_tbn_1 = fixed3(_unity_tangent.y, _unity_binormal.y, _unity_normal.y)
    #define UNITY_RECONSTRUCT_TBN_2 fixed3 _unity_tbn_2 = fixed3(_unity_tangent.z, _unity_binormal.z, _unity_normal.z)

    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #define UNITY_RECONSTRUCT_TBN(name) UNITY_EXTRACT_TBN_T(name); UNITY_EXTRACT_TBN_N(name); UNITY_EXTRACT_TBN_B(name); UNITY_CORRECT_TBN_B_SIGN(name); UNITY_RECONSTRUCT_TBN_0; UNITY_RECONSTRUCT_TBN_1; UNITY_RECONSTRUCT_TBN_2
    #else
        #define UNITY_RECONSTRUCT_TBN(name) UNITY_EXTRACT_TBN(name)
    #endif

    //  LOD cross fade helpers
    // keep all the old macros
    #define UNITY_DITHER_CROSSFADE_COORDS
    #define UNITY_DITHER_CROSSFADE_COORDS_IDX(idx)
    #define UNITY_TRANSFER_DITHER_CROSSFADE(o,v)
    #define UNITY_TRANSFER_DITHER_CROSSFADE_HPOS(o,hpos)

    #ifdef LOD_FADE_CROSSFADE
        #define UNITY_APPLY_DITHER_CROSSFADE(vpos)  UnityApplyDitherCrossFade(vpos)
        sampler2D unity_DitherMask;
        void UnityApplyDitherCrossFade(float2 vpos)
        {
            vpos /= 4; // the dither mask texture is 4x4
            float mask = tex2D(unity_DitherMask, vpos).a;
            float sgn = unity_LODFade.x > 0 ? 1.0f : -1.0f;
            clip(unity_LODFade.x - mask * sgn);
        }
    #else
        #define UNITY_APPLY_DITHER_CROSSFADE(vpos)
    #endif


    // ------------------------------------------------------------------
    //  Deprecated things: these aren't used; kept here
    //  just so that various existing shaders still compile, more or less.


    // Note: deprecated shadow collector pass helpers
    #ifdef SHADOW_COLLECTOR_PASS

        #if !defined(SHADOWMAPSAMPLER_DEFINED)
            UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
        #endif

        // Note: V2F_SHADOW_COLLECTOR and TRANSFER_SHADOW_COLLECTOR are deprecated
        #define V2F_SHADOW_COLLECTOR float4 pos : SV_POSITION; float3 _ShadowCoord0 : TEXCOORD0; float3 _ShadowCoord1 : TEXCOORD1; float3 _ShadowCoord2 : TEXCOORD2; float3 _ShadowCoord3 : TEXCOORD3; float4 _WorldPosViewZ : TEXCOORD4
        #define TRANSFER_SHADOW_COLLECTOR(o)    \
        o.pos = UnityObjectToClipPos(v.vertex); \
        float4 wpos = mul(unity_ObjectToWorld, v.vertex); \
        o._WorldPosViewZ.xyz = wpos; \
        o._WorldPosViewZ.w = -UnityObjectToViewPos(v.vertex).z; \
        o._ShadowCoord0 = mul(unity_WorldToShadow[0], wpos).xyz; \
        o._ShadowCoord1 = mul(unity_WorldToShadow[1], wpos).xyz; \
        o._ShadowCoord2 = mul(unity_WorldToShadow[2], wpos).xyz; \
        o._ShadowCoord3 = mul(unity_WorldToShadow[3], wpos).xyz;

        // Note: SAMPLE_SHADOW_COLLECTOR_SHADOW is deprecated
        #define SAMPLE_SHADOW_COLLECTOR_SHADOW(coord) \
        half shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture,coord); \
        shadow = _LightShadowData.r + shadow * (1-_LightShadowData.r);

        // Note: COMPUTE_SHADOW_COLLECTOR_SHADOW is deprecated
        #define COMPUTE_SHADOW_COLLECTOR_SHADOW(i, weights, shadowFade) \
        float4 coord = float4(i._ShadowCoord0 * weights[0] + i._ShadowCoord1 * weights[1] + i._ShadowCoord2 * weights[2] + i._ShadowCoord3 * weights[3], 1); \
        SAMPLE_SHADOW_COLLECTOR_SHADOW(coord) \
        float4 res; \
        res.x = saturate(shadow + shadowFade); \
        res.y = 1.0; \
        res.zw = EncodeFloatRG (1 - i._WorldPosViewZ.w * _ProjectionParams.w); \
        return res;

        // Note: deprecated
        #if defined (SHADOWS_SPLIT_SPHERES)
            #define SHADOW_COLLECTOR_FRAGMENT(i) \
            float3 fromCenter0 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[0].xyz; \
            float3 fromCenter1 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[1].xyz; \
            float3 fromCenter2 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[2].xyz; \
            float3 fromCenter3 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[3].xyz; \
            float4 distances2 = float4(dot(fromCenter0,fromCenter0), dot(fromCenter1,fromCenter1), dot(fromCenter2,fromCenter2), dot(fromCenter3,fromCenter3)); \
            float4 cascadeWeights = float4(distances2 < unity_ShadowSplitSqRadii); \
            cascadeWeights.yzw = saturate(cascadeWeights.yzw - cascadeWeights.xyz); \
            float sphereDist = distance(i._WorldPosViewZ.xyz, unity_ShadowFadeCenterAndType.xyz); \
            float shadowFade = saturate(sphereDist * _LightShadowData.z + _LightShadowData.w); \
            COMPUTE_SHADOW_COLLECTOR_SHADOW(i, cascadeWeights, shadowFade)
        #else
            #define SHADOW_COLLECTOR_FRAGMENT(i) \
            float4 viewZ = i._WorldPosViewZ.w; \
            float4 zNear = float4( viewZ >= _LightSplitsNear ); \
            float4 zFar = float4( viewZ < _LightSplitsFar ); \
            float4 cascadeWeights = zNear * zFar; \
            float shadowFade = saturate(i._WorldPosViewZ.w * _LightShadowData.z + _LightShadowData.w); \
            COMPUTE_SHADOW_COLLECTOR_SHADOW(i, cascadeWeights, shadowFade)
        #endif

    #endif // #ifdef SHADOW_COLLECTOR_PASS


    // Legacy; used to do something on platforms that had to emulate depth textures manually. Now all platforms have native depth textures.
    #define UNITY_TRANSFER_DEPTH(oo)
    // Legacy; used to do something on platforms that had to emulate depth textures manually. Now all platforms have native depth textures.
    #define UNITY_OUTPUT_DEPTH(i) return 0



    #define API_HAS_GUARANTEED_R16_SUPPORT !(SHADER_API_VULKAN || SHADER_API_GLES || SHADER_API_GLES3)

    float4 PackHeightmap(float height)
    {
        #if (API_HAS_GUARANTEED_R16_SUPPORT)
            return height;
        #else
            uint a = (uint)(65535.0f * height);
            return float4((a >> 0) & 0xFF, (a >> 8) & 0xFF, 0, 0) / 255.0f;
        #endif
    }

    float UnpackHeightmap(float4 height)
    {
        #if (API_HAS_GUARANTEED_R16_SUPPORT)
            return height.r;
        #else
            return (height.r + height.g * 256.0f) / 257.0f; // (255.0f * height.r + 255.0f * 256.0f * height.g) / 65535.0f
        #endif
    }

#endif // UNITY_CG_INCLUDED
