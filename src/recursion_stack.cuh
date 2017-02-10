#pragma once
#include <vector_types.h>
#include "cutil_math.h"

/*
Using stack in pseudocode:
stack -> obviously, stack
accumulated_values -> emission summand, light intencity multiplier

float[] render(args){
    stack.push(args);
    
    while(stack.is_not_empty()){
        current_args = stack.pop();
        results = use_args_in_algorithm(current_args);
        if (algorith_terminates == true){ //make sure that loop always terminates after finite number of iterations!
            //results = some value, usually emission from light source
            break;
        }
        //otherwise results consist of emission value, some multiplier value and new args for next bounce
        accumulated_values.store_emission(results.e);
        accumulated_values.store_intencity(results.i);
        stack.push(results.new_args);        
    }
    
    //the loop will always finish with some singular emission value inside 'results' variable
    while(accumulated_values.not_empty()){
        result = result * accumulated_values.get_intencity() + accumulated_values.get_emission();
    }
}

*/

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