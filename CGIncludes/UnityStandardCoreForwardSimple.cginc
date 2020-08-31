// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED
#define UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED

#include "UnityStandardCore.cginc"

//  Does not support: _PARALLAXMAP, DIRLIGHTMAP_COMBINED
#define GLOSSMAP (defined(_SPECGLOSSMAP) || defined(_METALLICGLOSSMAP))

#ifndef SPECULAR_HIGHLIGHTS
    #define SPECULAR_HIGHLIGHTS (!defined(_SPECULAR_HIGHLIGHTS_OFF))
#endif

// 顶点着色器输出的结构体
struct VertexOutputBaseSimple
{
    // 声明顶点的坐标位置
    UNITY_POSITION(pos);
    float4 tex                          : TEXCOORD0; // 顶点的第一层纹理坐标
    half4 eyeVec                        : TEXCOORD1; // x、y、z 存储了顶点到摄像机连线的向量 （还是摄像机到顶点的？）
                                                        // w: 存储了掠射角（grazingTerm）-> 入射光线和反射平面的夹角

    half4 ambientOrLightmapUV           : TEXCOORD2; // 存储球谐或者光照贴图坐标 SH or Lightmap UV  
    SHADOW_COORDS(3)
    UNITY_FOG_COORDS_PACKED(4, half4) // x: fogCoord, yzw: reflectVec   x 雾化因子， yzw反射向量

    half4 normalWorld                   : TEXCOORD5; // w: fresnelTerm   w 分量存储了 菲涅尔方程函数的值

#ifdef _NORMALMAP
    half3 tangentSpaceLightDir          : TEXCOORD6;
    #if SPECULAR_HIGHLIGHTS
        half3 tangentSpaceEyeVec        : TEXCOORD7;
    #endif
#endif

// UNITY_STANDARD_SIMPLE 是否开启对应定义 UNITY_REQUIRE_FRAG_WORLDPOS 为 0 还是为 1
// 最终决定是否需要将世界空间的分量，输入到片元着色器中
#if UNITY_REQUIRE_FRAG_WORLDPOS
    float3 posWorld                     : TEXCOORD8;
#endif

    UNITY_VERTEX_OUTPUT_STEREO          // 立体渲染时左右眼索引 
};

// UNIFORM_REFLECTIVITY(): workaround to get (uniform) reflecivity based on UNITY_SETUP_BRDF_INPUT
// UNIFORM_REFLECTIVITY(): 基于UNITY_SETUP_BRDF_INPUT获得（统一）反射率的解决方法
half MetallicSetup_Reflectivity()
{   
    // OneMinusReflectivityFromMetallic 函数用来计算任意材质的基础反射比例
    return 1.0h - OneMinusReflectivityFromMetallic(_Metallic);
}

half SpecularSetup_Reflectivity()
{
    return SpecularStrength(_SpecColor.rgb);
}

half RoughnessSetup_Reflectivity()
{
    return MetallicSetup_Reflectivity();
}

#define JOIN2(a, b) a##b
#define JOIN(a, b) JOIN2(a,b)
#define UNIFORM_REFLECTIVITY JOIN(UNITY_SETUP_BRDF_INPUT, _Reflectivity)


#ifdef _NORMALMAP

// 将 v 变换到切线空间
half3 TransformToTangentSpace(half3 tangent, half3 binormal, half3 normal, half3 v)
{
    // Mali400 shader compiler prefers explicit dot product over using a half3x3 matrix
    // Mali400着色器编译器更喜欢显式点积，而不是使用half3x3矩阵
    return half3(dot(tangent, v), dot(binormal, v), dot(normal, v));
}

// 把顶点-光源连线和顶点-摄像机连线向量从世界空间变换到切线空间后返回
void TangentSpaceLightingInput(half3 normalWorld, half4 vTangent, half3 lightDirWorld, half3 eyeVecWorld, out half3 tangentSpaceLightDir, out half3 tangentSpaceEyeVec)
{
    half3 tangentWorld = UnityObjectToWorldDir(vTangent.xyz);
    // 计算决定副法线的方向
    // vTangent.w 分量存储了 切线 叉乘 法线的 向量方向的结果（-1或1）
    half sign = half(vTangent.w) * half(unity_WorldTransformParams.w);  // 这里的计算 差不多理解
    /*
    延申：
    用第三方工具导出模型时，模型的顶点一般携带法向量、切线向量、副法线（binormal）向量或者是副切线（bintangent）向量。
    Unity 3D 在导入这些模型数据时，会丢弃具体的副法向量值，而仅存储法向量和切线向量的叉乘顺序。
    利用切线向量的w分量存储叉乘顺序，要么是 1，要么是 −1。
    */
    // 计算副法线
    half3 binormalWorld = cross(normalWorld, tangentWorld) * sign;
    tangentSpaceLightDir = TransformToTangentSpace(tangentWorld, binormalWorld, normalWorld, lightDirWorld);
    #if SPECULAR_HIGHLIGHTS
        tangentSpaceEyeVec = normalize(TransformToTangentSpace(tangentWorld, binormalWorld, normalWorld, eyeVecWorld));
    #else
        tangentSpaceEyeVec = 0;
    #endif
}

#endif // _NORMALMAP

// 简化版本前向渲染的顶点着色器入口
VertexOutputBaseSimple vertForwardBaseSimple (VertexInput v)
{
    // 设置顶点的 instance ID
    UNITY_SETUP_INSTANCE_ID(v);
    VertexOutputBaseSimple o;
    // 初始化 结构体
    UNITY_INITIALIZE_OUTPUT(VertexOutputBaseSimple, o);
    // 声明立体渲染时用到的左右眼索引
    // 等价于：o.stereoTargetEyeIndex = unity_StereoEyeIndices[unity_StereoEyeIndex].x；
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);       // 世界空间坐标
    o.pos = UnityObjectToClipPos(v.vertex);     // 裁剪空间坐标
    // TexCoords 的 主要作用是 将定义的_MainTex（反照率贴图）和_DetailAlbedoMap（反照率细节贴图）的纹理映射坐标依次存储进一个 float4 变量中的 x、y、z、w 分量后返回
    o.tex = TexCoords(v);   // 设置第一层纹理映射坐标 

    // 摄像机到顶点的连线
    half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);
    half3 normalWorld = UnityObjectToWorldNormal(v.normal);

    o.normalWorld.xyz = normalWorld;
    o.eyeVec.xyz = eyeVec;

    #ifdef _NORMALMAP
        // 使用了法线贴图
        half3 tangentSpaceEyeVec;   // 切线空间的 视线向量
        // 把顶点-光源连线和顶点-摄像机连线向量从世界空间变换到切线空间后返回
        TangentSpaceLightingInput(normalWorld, v.tangent, _WorldSpaceLightPos0.xyz, eyeVec, o.tangentSpaceLightDir, tangentSpaceEyeVec);
        #if SPECULAR_HIGHLIGHTS
            o.tangentSpaceEyeVec = tangentSpaceEyeVec;
        #endif
    #endif

    //We need this for shadow receiving
    TRANSFER_SHADOW(o);     // 将片元中携带的阴影坐标转换到各个空间下

    // VertexGIForward：要么得到静态/动态（实时）光照贴图的UV纹理坐标，
    // 要么利用球谐函数得到作用再本物体上的光线RGB值
    o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

    // 根据顶点在世界坐标系中的法向量 normalWorld 和摄像机到本顶点的连线向量 eyeVec，
    // 求得连线向量所对应的反射向量，并将其存储到顶点的雾坐标值 fogCoord 中的y、z、w分量中
    // 注意这里是 eyeVec 的反射向量
    o.fogCoord.yzw = reflect(eyeVec, normalWorld);

    // 使用简化的菲涅尔方程函数
    o.normalWorld.w = Pow4(1 - saturate(dot(normalWorld, -eyeVec))); // fresnel term

    // 如果没有使用金属贴图，或者在镜面工作流中没有使用镜面高光贴图掠射角项
    // 则利用_Glossiness 变量和函数 MetallicSetup_Refelctivity 返回值之和得到一个掠射角项。
    // 此项用来对 o.normalWorld.w 值，即菲涅尔方程函数项值做一个调制，用来计算物体之间的间接照明的镜面高光部分的颜色值。
    #if !GLOSSMAP
        // UNIFORM_REFLECTIVITY 指函数 SpecularSetup_Reflectivity
        o.eyeVec.w = saturate(_Glossiness + UNIFORM_REFLECTIVITY()); // grazing term
    #endif

    // 根据顶点的位置计算雾化因子
    UNITY_TRANSFER_FOG(o, o.pos);
    return o;
}


FragmentCommonData FragmentSetupSimple(VertexOutputBaseSimple i)
{
    half alpha = Alpha(i.tex.xy);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif

    FragmentCommonData s = UNITY_SETUP_BRDF_INPUT (i.tex);

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    s.diffColor = PreMultiplyAlpha (s.diffColor, alpha, s.oneMinusReflectivity, /*out*/ s.alpha);

    s.normalWorld = i.normalWorld.xyz;
    s.eyeVec = i.eyeVec.xyz;
    s.posWorld = IN_WORLDPOS(i);
    s.reflUVW = i.fogCoord.yzw;

    #ifdef _NORMALMAP
        s.tangentSpaceNormal =  NormalInTangentSpace(i.tex);
    #else
        s.tangentSpaceNormal =  0;
    #endif

    return s;
}

UnityLight MainLightSimple(VertexOutputBaseSimple i, FragmentCommonData s)
{
    UnityLight mainLight = MainLight();
    return mainLight;
}

half PerVertexGrazingTerm(VertexOutputBaseSimple i, FragmentCommonData s)
{
    #if GLOSSMAP
        return saturate(s.smoothness + (1-s.oneMinusReflectivity));
    #else
        return i.eyeVec.w;
    #endif
}

half PerVertexFresnelTerm(VertexOutputBaseSimple i)
{
    return i.normalWorld.w;
}

#if !SPECULAR_HIGHLIGHTS
#   define REFLECTVEC_FOR_SPECULAR(i, s) half3(0, 0, 0)
#elif defined(_NORMALMAP)
#   define REFLECTVEC_FOR_SPECULAR(i, s) reflect(i.tangentSpaceEyeVec, s.tangentSpaceNormal)
#else
#   define REFLECTVEC_FOR_SPECULAR(i, s) s.reflUVW
#endif

half3 LightDirForSpecular(VertexOutputBaseSimple i, UnityLight mainLight)
{
    #if SPECULAR_HIGHLIGHTS && defined(_NORMALMAP)
        return i.tangentSpaceLightDir;
    #else
        return mainLight.dir;
    #endif
}

half3 BRDF3DirectSimple(half3 diffColor, half3 specColor, half smoothness, half rl)
{
    #if SPECULAR_HIGHLIGHTS
        return BRDF3_Direct(diffColor, specColor, Pow4(rl), smoothness);
    #else
        return diffColor;
    #endif
}

half4 fragForwardBaseSimpleInternal (VertexOutputBaseSimple i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    FragmentCommonData s = FragmentSetupSimple(i);

    UnityLight mainLight = MainLightSimple(i, s);

    #if !defined(LIGHTMAP_ON) && defined(_NORMALMAP)
    half ndotl = saturate(dot(s.tangentSpaceNormal, i.tangentSpaceLightDir));
    #else
    half ndotl = saturate(dot(s.normalWorld, mainLight.dir));
    #endif

    //we can't have worldpos here (not enough interpolator on SM 2.0) so no shadow fade in that case.
    half shadowMaskAttenuation = UnitySampleBakedOcclusion(i.ambientOrLightmapUV, 0);
    half realtimeShadowAttenuation = SHADOW_ATTENUATION(i);
    half atten = UnityMixRealtimeAndBakedShadows(realtimeShadowAttenuation, shadowMaskAttenuation, 0);

    half occlusion = Occlusion(i.tex.xy);
    half rl = dot(REFLECTVEC_FOR_SPECULAR(i, s), LightDirForSpecular(i, mainLight));

    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
    half3 attenuatedLightColor = gi.light.color * ndotl;

    half3 c = BRDF3_Indirect(s.diffColor, s.specColor, gi.indirect, PerVertexGrazingTerm(i, s), PerVertexFresnelTerm(i));
    c += BRDF3DirectSimple(s.diffColor, s.specColor, s.smoothness, rl) * attenuatedLightColor;
    c += Emission(i.tex.xy);

    UNITY_APPLY_FOG(i.fogCoord, c);

    return OutputForward (half4(c, 1), s.alpha);
}

half4 fragForwardBaseSimple (VertexOutputBaseSimple i) : SV_Target  // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardBaseSimpleInternal(i);
}

struct VertexOutputForwardAddSimple
{
    UNITY_POSITION(pos);
    float4 tex                          : TEXCOORD0;
    float3 posWorld                     : TEXCOORD1;

#if !defined(_NORMALMAP) && SPECULAR_HIGHLIGHTS
    UNITY_FOG_COORDS_PACKED(2, half4) // x: fogCoord, yzw: reflectVec
#else
    UNITY_FOG_COORDS_PACKED(2, half1)
#endif

    half3 lightDir                      : TEXCOORD3;

#if defined(_NORMALMAP)
    #if SPECULAR_HIGHLIGHTS
        half3 tangentSpaceEyeVec        : TEXCOORD4;
    #endif
#else
    half3 normalWorld                   : TEXCOORD4;
#endif

    UNITY_LIGHTING_COORDS(5, 6)

    UNITY_VERTEX_OUTPUT_STEREO
};

VertexOutputForwardAddSimple vertForwardAddSimple (VertexInput v)
{
    VertexOutputForwardAddSimple o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAddSimple, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);
    o.tex = TexCoords(v);
    o.posWorld = posWorld.xyz;

    //We need this for shadow receiving and lighting
    UNITY_TRANSFER_LIGHTING(o, v.uv1);

    half3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
    #ifndef USING_DIRECTIONAL_LIGHT
        lightDir = NormalizePerVertexNormal(lightDir);
    #endif

    #if SPECULAR_HIGHLIGHTS
        half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);
    #endif

    half3 normalWorld = UnityObjectToWorldNormal(v.normal);

    #ifdef _NORMALMAP
        #if SPECULAR_HIGHLIGHTS
            TangentSpaceLightingInput(normalWorld, v.tangent, lightDir, eyeVec, o.lightDir, o.tangentSpaceEyeVec);
        #else
            half3 ignore;
            TangentSpaceLightingInput(normalWorld, v.tangent, lightDir, 0, o.lightDir, ignore);
        #endif
    #else
        o.lightDir = lightDir;
        o.normalWorld = normalWorld;
        #if SPECULAR_HIGHLIGHTS
            o.fogCoord.yzw = reflect(eyeVec, normalWorld);
        #endif
    #endif

    UNITY_TRANSFER_FOG(o,o.pos);
    return o;
}

FragmentCommonData FragmentSetupSimpleAdd(VertexOutputForwardAddSimple i)
{
    half alpha = Alpha(i.tex.xy);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif

    FragmentCommonData s = UNITY_SETUP_BRDF_INPUT (i.tex);

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    s.diffColor = PreMultiplyAlpha (s.diffColor, alpha, s.oneMinusReflectivity, /*out*/ s.alpha);

    s.eyeVec = 0;
    s.posWorld = i.posWorld;

    #ifdef _NORMALMAP
        s.tangentSpaceNormal = NormalInTangentSpace(i.tex);
        s.normalWorld = 0;
    #else
        s.tangentSpaceNormal = 0;
        s.normalWorld = i.normalWorld;
    #endif

    #if SPECULAR_HIGHLIGHTS && !defined(_NORMALMAP)
        s.reflUVW = i.fogCoord.yzw;
    #else
        s.reflUVW = 0;
    #endif

    return s;
}

half3 LightSpaceNormal(VertexOutputForwardAddSimple i, FragmentCommonData s)
{
    #ifdef _NORMALMAP
        return s.tangentSpaceNormal;
    #else
        return i.normalWorld;
    #endif
}

half4 fragForwardAddSimpleInternal (VertexOutputForwardAddSimple i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    FragmentCommonData s = FragmentSetupSimpleAdd(i);

    half3 c = BRDF3DirectSimple(s.diffColor, s.specColor, s.smoothness, dot(REFLECTVEC_FOR_SPECULAR(i, s), i.lightDir));

    #if SPECULAR_HIGHLIGHTS // else diffColor has premultiplied light color
        c *= _LightColor0.rgb;
    #endif

    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
    c *= atten * saturate(dot(LightSpaceNormal(i, s), i.lightDir));

    UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
    return OutputForward (half4(c, 1), s.alpha);
}

half4 fragForwardAddSimple (VertexOutputForwardAddSimple i) : SV_Target // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardAddSimpleInternal(i);
}

#endif // UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED
