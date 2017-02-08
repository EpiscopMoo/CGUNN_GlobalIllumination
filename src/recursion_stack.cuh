#pragma once
#include <vector_types.h>
#include "cutil_math.h"

typedef short unsigned int suint;

struct func_hdr_info
{
	float3 mask_value;
	float3 target_pt;
	float3 target_dir;
	__device__ func_hdr_info(float3 _val, float3 _pt, float3 _dir) :
		mask_value(_val),
		target_pt(_pt),
		target_dir(_dir){}
	__device__ func_hdr_info() :
		mask_value(make_float3(1.0, 1.0, 1.0)) {}
};

struct sp_stack //single purpose stack (for recursion)
{
	suint ptr;
	static const suint depth = 5;
	func_hdr_info mem[depth];

	__device__ sp_stack() :
	ptr(0)
	{

	}
};