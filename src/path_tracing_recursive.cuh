#pragma once
#include <vector_types.h>
#include "cutil_math.h"
#include "predefs.cuh"
#include "entities.cuh"
#include "recursion_stack"

__device__ bool intersect_scene(Sphere* spheres, int count, const Ray &r, float &t, int &id)
{
	float n = count;
	float d; 
	float inf = t = 1e20;  // t - дистанция до ближайшего пересечения, иниц в бесконечности (т.е. нет пересечения нигде)
	for (int i = int(n); i--;)  //по всем объектам сцены
	if ((d = spheres[i].intersect_sphere(r)) && d < t)
	{  //отбираем наименьшую дистанцию и запоминаем, с чем образовано это пересечение
		t = d; 
		id = i;
	}
	return t < inf;
}


__device__ static float getrandom(unsigned int *seed0, unsigned int *seed1) 
{
	*seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);  // hash the seeds using bitwise AND and bitshifts
	*seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);

	unsigned int ires = ((*seed0) << 16) + (*seed1);

	union {
		float f;
		unsigned int ui;
	} res;

	res.ui = (ires & 0x007fffff) | 0x40000000;  // bitwise AND, bitwise OR

	return (res.f - 2.f) / 2.f;
}

__device__ static float3 surface_color_at(const Sphere& target_sphere, const float3& hit_point)
{
    if (target_sphere.refl == GENR) //procedure-generated chessboard texture			
    {
        int x_even_factor = (int)(hit_point.x / GRID_CELL_SIZE)%2;
        int z_even_factor = (int)(hit_point.z / GRID_CELL_SIZE)%2;
        if ((x_even_factor + z_even_factor)%2)
            return make_float3(1,1,1);
        else
            return make_float3(0,0,0);		
    }
    else return target_sphere.col;
}

__device__ static bool russian_roulette(float3& color_multiplier, int iteration)
{
    if (iteration > MAX_BOUNCES)
        return true;
    if (iteration > R_R_THRESHOLD)
    {
        float max_light_cmpnt_value = max(color_multiplier.x, max(color_multiplier.y, color_multiplier.z));
        if (getrandom(s1, s2) < max_light_cmpnt_value)
        {
            color_multiplier *= 1.0f/max_light_cmpnt_value;
            return false;
        }
        return true;
    }
}

__device__ float3 radiance(Sphere* spheres, int count, Ray &r, unsigned int *s1, unsigned int *s2, Preset* presets)
{
    ray_stack stack;
    acc_stack light_values;
    
    float3 new_origin;
    float3 new_direction;
    float3 color_multiplier;
    
    int iteration = 0;
    
    stack.push(r);
    while(stack.is_not_empty())
    {
        iteration++;
        Ray ray = stack.pop();
        
        // Step 0. Intersection(s) with the scene.
        float t;
		int id = 0; //sphere index in array of spheres
        if (!intersect_scene(spheres, count, ray, t, id))
			return make_float3(0.0f, 0.0f, 0.0f); //no intersection
        const Sphere& target_sphere = spheres[id]; 
        float3 hit_point = ray.orig + ray.dir*t; 
        
        // Step 1. Compute colour value             
        color_multiplier = surface_color_at(target_sphere, hit_point);
        
        // Step 2. Russian Roulette. Color multiplier gets modified here.
        if (russian_roulette(color_multiplier, iteration))
        {
            light_values.store_emission_and_intencity(target_sphere.emi, make_float3(1.0f, 1.0f, 1.0f));
            continue;
        }
        
        // Step 3. Computing directional vectors (normals, basis vectors, aligned normal etc)
		float3 n = normalize(hit_point - target_sphere.pos); //normal vector
		float3 a_n = dot(n, ray.dir) < 0 ? n : n * -1; //aligned normal facing the direction of true reflection
		
        float r1 = 2 * M_PI * getrandom(s1, s2); //[0..2Pi] random value
		float r2 = getrandom(s1, s2);
		float r2s = sqrtf(r2);
        
        float3 w = a_n; 
		float3 u = normalize(cross((fabs(w.x) > 0.1f ? make_float3(0, 1, 0) : make_float3(1, 0, 0)), w));
		float3 v = cross(w,u);
        
        //Step 4. Computing new direction and colour values based on material type        
        if (target_sphere.refl == REFR) //glass
		{
			//TODO: glass refractions + R.R.
            return make_float3(1.0f, 1.0f, 1.0f);
		}
		else if (target_sphere.refl == GENR) //procedure-generated chessboard texture, always diffuse.			
        {
            new_direction = normalize(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrtf(1 - r2));		
            color_multiplier *= dot(new_direction, a_n) * 2;                
        }
        else 
        {
            //ideal refraction + preset * diffuse_deviation
            float diff_factor = pow(presets->presets[target_sphere.refl], 5);
            float3 rand_direction = normalize(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrtf(1 - r2));
            new_direction = normalize((1-diff_factor)*reflect(ray.dir, n) + diff_factor*rand_direction);
            float3 rc = 1.f/(color_multiplier+0.0001f), unit = make_float3(1.f, 1.f, 1.f);
            color_multiplier *= (rc + (unit-rc)*diff_factor); 
            color_multiplier *= dot(new_direction, a_n) * 2;
        }
        
        //Step 4. Produce new arguments for next recursive iteration, save light values into accumulator.
        new_origin = hit_point + a_n*0.05f; //a little offset to avoid weird collisions with the same object due to float compute errors.
        stack.push(Ray(new_origin, new_direction));
        light_values.store_emission_and_intencity(target_sphere.emi, color_multiplier);
    }//end of recursion loop
    return light_values.accumulate();
}

inline float clamp(float x){ return x < 0.0f ? 0.0f : x > 1.0f ? 1.0f : x; } 