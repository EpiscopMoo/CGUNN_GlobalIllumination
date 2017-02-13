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

struct ray_stack //single purpose stack (for recursion)
{
	suint ptr;
	static const suint depth = MAX_BOUNCES;
	Ray mem[depth];

	__device__ sp_stack() :	ptr(0) {}
    __device__ bool push(const Ray& ray)
    {
        if (ptr == depth)
            return false;
        mem[ptr].orig = ray.orig;
        mem[ptr].dir = ray.dir;
        ptr++;
        return true;
    }
    __device__ Ray pop()
    {
        ptr--;
        return Ray(mem[ptr].orig, mem[ptr].dir);
    }
    __device__ bool is_not_empty()
    {
        return ptr > 0;
    }
};

struct acc_stack //accumulator for recursion
{
    suint ptr;
    static const suint depth = MAX_BOUNCES+1;
    float3 emissions[depth];
    float3 intencities[depth];
    __device__ acc_stack() : ptr(0) {}
    __device__ bool store_emission_and_intencity(float3 emission, float3 intencity)
    {
        if (ptr == depth)
            return false;
        emissions[ptr] = emission;
        intencities[ptr] = intencity;
        ptr++;
        return true;
    }
    __device__ float3 accumulate(float3 value)
    {
        for (int i=ptr-1; i>=0; i--)
            value = emissions[i] + value*intencities[i];
        return value;
    }
};