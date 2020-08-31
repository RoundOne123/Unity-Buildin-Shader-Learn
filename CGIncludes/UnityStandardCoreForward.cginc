// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_FORWARD_INCLUDED
#define UNITY_STANDARD_CORE_FORWARD_INCLUDED

// 如果定义了 UNITY_NO_FULL_STANDARD_SHADER，即不使用完全版本的标准着色器，
// 就定义一个使用简化版本的标准着色器的 UNITY_STANDARD_SIMPLE 宏
#if defined(UNITY_NO_FULL_STANDARD_SHADER)
#   define UNITY_STANDARD_SIMPLE 1
#endif

#include "UnityStandardConfig.cginc"

/*
如果是简化版本，将会在内部使用简化版本的 BRDF3 机制实现光照计算。
对应于宏 UNITY_NO_FULL_STANDARD_SHADER，在引擎的运行时库 UnityEngine.Rendering 空间中的枚举类型 BuiltShaderDefine 中有同名的枚举量，对应这一项是否开启。
*/
#if UNITY_STANDARD_SIMPLE
    // 使用简化版
    #include "UnityStandardCoreForwardSimple.cginc"
    // forwardBase 和 forwardAdd 渲染路径下 都转调 UnityStandardCoreForwardSimple 中相应的方法
    VertexOutputBaseSimple vertBase (VertexInput v) { return vertForwardBaseSimple(v); }
    VertexOutputForwardAddSimple vertAdd (VertexInput v) { return vertForwardAddSimple(v); }
    half4 fragBase (VertexOutputBaseSimple i) : SV_Target { return fragForwardBaseSimpleInternal(i); }
    half4 fragAdd (VertexOutputForwardAddSimple i) : SV_Target { return fragForwardAddSimpleInternal(i); }
#else
    #include "UnityStandardCore.cginc"
    VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
    VertexOutputForwardAdd vertAdd (VertexInput v) { return vertForwardAdd(v); }
    half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardBaseInternal(i); }
    half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragForwardAddInternal(i); }
#endif

#endif // UNITY_STANDARD_CORE_FORWARD_INCLUDED
