// MIT License

// Copyright (c) 2021 NedMakesGames

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#ifndef CUSTOM_ADDITIONAL_LIGHTS_INCLUDED
#define CUSTOM_ADDITIONAL_LIGHTS_INCLUDED

// This is a neat trick to work around a bug in the shader graph when
// enabling shadow keywords. Created by @cyanilux
// https://github.com/Cyanilux/URP_ShaderGraphCustomLighting
// Licensed under the MIT License, Copyright (c) 2020 Cyanilux
#ifndef SHADERGRAPH_PREVIEW
#include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
#if (SHADERPASS != SHADERPASS_FORWARD)
        #undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
#endif
#endif

struct CustomLightingData
{
    float3 WorldPosition;
    float3 WorldNormal;
    float3 WorldView;
    half4 Shadowmask;

    float3 SpecColor;
    float Smoothness;
};

void CalculateCustomLighting(CustomLightingData d, out float3 Diffuse, out float3 Specular, out float Alpha)
{
    // attentuation = light.distanceAttenuation * light.shadowAttenuation;
    //
    // color = light.color * attentuation;

    float3 diffuseColor = 0;
    float3 specularColor = 0;
    float averageAttenuation = 0;

    float attenuation = 0;
    #ifndef SHADERGRAPH_PREVIEW
    d.Smoothness = exp2(10 * d.Smoothness + 1);
    uint pixelLightCount = GetAdditionalLightsCount();
    uint meshRenderingLayers = GetMeshRenderingLayer();

    #if USE_FORWARD_PLUS
    for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++) {
        FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
        Light light = GetAdditionalLight(lightIndex, d.WorldPosition, d.Shadowmask);
    #ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
        {
            // Blinn-Phong
            float3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
            diffuseColor += LightingLambert(attenuatedLightColor, light.direction, d.WorldNormal);
            specularColor += LightingSpecular(attenuatedLightColor, light.direction, d.WorldNormal, d.WorldView, float4(d.SpecColor, 0), d.Smoothness);
        }
    }
    #endif

    // For Foward+ the LIGHT_LOOP_BEGIN macro will use inputData.normalizedScreenSpaceUV, inputData.positionWS, so create that:
    InputData inputData = (InputData)0;
    float4 screenPos = ComputeScreenPos(TransformWorldToHClip(d.WorldPosition));
    inputData.normalizedScreenSpaceUV = screenPos.xy / screenPos.w;
    inputData.positionWS = d.WorldPosition;

    LIGHT_LOOP_BEGIN(pixelLightCount)
    Light light = GetAdditionalLight(lightIndex, d.WorldPosition, d.Shadowmask);
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
    #endif
    {
        float attenuation = light.distanceAttenuation * light.shadowAttenuation;
        averageAttenuation += attenuation;

        // Blinn-Phong
        float3 attenuatedLightColor = light.color * attenuation;
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, d.WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, d.WorldNormal, d.WorldView,
            float4(d.SpecColor, 0), d.Smoothness);
    }
    LIGHT_LOOP_END
    averageAttenuation /= pixelLightCount;
    #endif

    Diffuse = diffuseColor;
    Specular = specularColor;

    // TODO: Calculate alpha value based on attenuation.
    Alpha = averageAttenuation * 0.5;
}

void CalculateCustomLighting_float(float3 Position, float3 Normal, float3 View, float Smoothness, half4 Shadowmask, float3 SpecularColor,
    out float3 Diffuse, out float3 Specular, out float Alpha)
{
    CustomLightingData d;
    d.WorldPosition = Position;

    d.WorldNormal = Normal;
    d.WorldView = View;
    d.Shadowmask = Shadowmask;

    d.SpecColor = SpecularColor;
    d.Smoothness = Smoothness;

    CalculateCustomLighting(d, Diffuse, Specular, Alpha);
}

void CalculateCustomLighting_half(half3 Position, half3 Normal, half3 View, half Smoothness, half4 Shadowmask, half3 SpecularColor,
    out half3 Diffuse, out half3 Specular, out half Alpha)
{
    CustomLightingData d;
    d.WorldPosition = Position;

    d.WorldNormal = Normal;
    d.WorldView = View;
    d.Shadowmask = Shadowmask;

    d.SpecColor = SpecularColor;
    d.Smoothness = Smoothness;

    CalculateCustomLighting(d, Diffuse, Specular, Alpha);
}

#endif
