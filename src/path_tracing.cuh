#pragma once
#include <vector_types.h>
#include "cutil_math.h"
#include "predefs.cuh"
#include "entities.cuh"

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

__device__ float3 radiance(Sphere* spheres, int count, Ray &r, unsigned int *s1, unsigned int *s2, Preset* presets)
{
	float3 accucolor = make_float3(0.0f, 0.0f, 0.0f);
	float3 mask = make_float3(1.0f, 1.0f, 1.0f); 

	for (int bounces = 0; bounces < MAX_BOUNCES; bounces++) //4 по умолчанию
	{
		float t;
		int id = 0;

		if (!intersect_scene(spheres, count, r, t, id))
			return make_float3(0.0f, 0.0f, 0.0f); //ни с чем не пересеклись, возвращаем чёрный цвет

		const Sphere &obj = spheres[id];
		float3 pt = r.orig + r.dir*t; 
		float3 n = normalize(pt - obj.pos); // нормаль
		float3 nl = dot(n, r.dir) < 0 ? n : n * -1; // нормаль, повёрнутая лесом к переду
		r.orig = pt + nl*0.05f; //новая исходная точка

		// к итоговому цвету добавить испускаемый
		accucolor += mask * obj.emi;

		float r1 = 2 * M_PI * getrandom(s1, s2); //0 до 2Пи
		float r2 = getrandom(s1, s2);
		float r2s = sqrtf(r2); 

		//базис в точке пересечения
		float3 w = nl; 
		float3 u = normalize(cross((fabs(w.x) > 0.1f ? make_float3(0, 1, 0) : make_float3(1, 0, 0)), w));  
		float3 v = cross(w,u);

		float3 d;	//новое направление отраж.
		if (obj.refl == REFR) //стекло (бажит :C )
		{
			float nc = 1, nt = 1.5f; 
			bool into = dot(n, nl) > 0;
			float nnt = into ? nc/nt : nt/nc; 
			float dot_dn = dot(n, r.dir);
			float ddn = into ? dot_dn : -dot_dn; 
			float cos2t = 1-nnt*nnt*(1-ddn*ddn); 
			if (cos2t < 0) d = reflect(r.dir, n);
			else 
			{  
				float3 tdir(normalize(r.dir*nnt - nl*(ddn*nnt + sqrt(cos2t)))); 
				float 
					a = nt-nc, b = nt+nc, 
					R0 = (a*a) / (b*b), 
					c = 1 - (into ? -ddn : dot(tdir, n)), 
					Re = R0+(1-R0)*c*c*c*c*c, 
					P = .25f + .5f*Re; 
					/*Tr = 1.f-Re,  
					RP = Re / P, 
					TP = Tr / (1.f-P);*/
				bool pick = getrandom(s1, s2) < P;
			}
		}
		else 
		{
			if (obj.refl == GENR) //проц. генерация, всегда диффуз				
			{
				int x_even_factor = (int)(pt.x / GRID_CELL_SIZE)%2;
				int z_even_factor = (int)(pt.z / GRID_CELL_SIZE)%2;
				if ((x_even_factor + z_even_factor)%2)
					mask = mask * make_float3(1,1,1);
				else
					mask = mask * make_float3(0,0,0);
				d = normalize(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrtf(1 - r2));					
			}
			else 
			{
				//идеальное отражение + пресет * диффуз.отклонение
				float diff_factor = pow(presets->presets[obj.refl], 5);
				float3 rand_direction = normalize(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrtf(1 - r2));
				d = normalize((1-diff_factor)*reflect(r.dir, n) + diff_factor*rand_direction);
				float3 rc = 1.f/obj.col, unit = make_float3(1.f,1.f,1.f);
				mask = mask * (obj.col*(rc + (unit-rc)*diff_factor)); 
			}
			mask = mask * dot(d,nl);
			mask = mask * 2;
		}
		r.dir = d;
	}
	return accucolor;
}

inline float clamp(float x){ return x < 0.0f ? 0.0f : x > 1.0f ? 1.0f : x; } 