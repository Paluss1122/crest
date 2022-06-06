﻿// Crest Ocean System

// This file is subject to the MIT License as seen in the root of this folder structure (LICENSE)

Shader "Hidden/Crest/Inputs/Flow/Inject SWS"
{
	SubShader
	{
		// Additive blend everywhere
		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite Off
		ZTest Always
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			//#pragma enable_d3d11_debug_symbols

			#include "UnityCG.cginc"

			#include "../../OceanGlobals.hlsl"
			#include "../../OceanInputsDriven.hlsl"
			#include "../../OceanHelpers.hlsl"
			#include "../../FullScreenTriangle.hlsl"

			Texture2D<float> _swsVx;
			Texture2D<float> _swsVy;
			Texture2D<float> _swsSimulationMask;

			CBUFFER_START(CrestPerOceanInput)
			int _WaveBufferSliceIndex;
			float _Weight;
			float _AverageWavelength;
			float _AttenuationInShallows;
			float2 _AxisX;
			float _RespectShallowWaterAttenuation;
			half _DomainWidth;
			float3 _SimOrigin;
			CBUFFER_END

			struct Attributes
			{
				uint VertexID : SV_VertexID;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			Varyings Vert(Attributes input)
			{
				Varyings o;
				o.positionCS = GetFullScreenTriangleVertexPosition(input.VertexID);

				const float2 quadUV = GetFullScreenTriangleTexCoord(input.VertexID);

				const float2 worldXZ = UVToWorld(quadUV, _LD_SliceIndex, _CrestCascadeData[_LD_SliceIndex]);
				o.uv = (worldXZ - _SimOrigin.xz) / _DomainWidth + 0.5;

				return o;
			}

			half4 Frag(Varyings input) : SV_Target
			{
				// Over scan to ensure signal continued off the edges which helps at low LODs
				if (any(input.uv != saturate(input.uv))) discard;

				const float wt = _Weight;

				// These should use mip maps. Without this bad pops ensue from aliasing x combine-pass-flow
				const float vx = _swsVx.Sample(LODData_linear_clamp_sampler, input.uv).x;
				const float vy = _swsVy.Sample(LODData_linear_clamp_sampler, input.uv).x;

				float alpha = _swsSimulationMask.SampleLevel(LODData_linear_clamp_sampler, input.uv, 0.0).x;

				float2 offset = abs(input.uv - 0.5);
				float maxOff = max(offset.x, offset.y);
				alpha *= smoothstep(0.5, 0.45, maxOff);

				return half4(wt * vx, wt * vy, 0.0, alpha);
			}
			ENDCG
		}
	}
}
