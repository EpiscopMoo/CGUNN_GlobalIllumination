#pragma once
#include <vector_types.h>
#include "cutil_math.h"

struct Ray 
{ 
	float3 orig; // точка испускания луча
	float3 dir;  // направление луча
	__device__ Ray(float3 o_, float3 d_) : orig(o_), dir(d_) {} 
};

struct Preset
{
	float* presets;
	int size;
	__device__ Preset(float* p, int n) : presets(p), size(n){}
};

enum Refl_t { DIFF=0, SPEC=1, GENR=-1, REFR=-2 };  // пресеты свойств материала для radiance(), коэфф. диффузности

struct Sphere 
{
	float rad; 
	float3 pos, emi, col; // position, emission, colour 
	int refl;          // пресет отражения

	__device__ float intersect_sphere(const Ray &r) const 
	{          
		// детекция пересечения сферы и пути
		// возвращает дистанцию t до точки пересечения или ноль, если оного нет
		// ур-е пути (прямой), параметризация по t: p(x,y,z) = ray.orig + t*ray.dir
		// ур-е сферы: x^2 + y^2 + z^2 = rad^2 
		// т.е. имеем х = х0 + t*dirX, y = y0 + t*dirY и т.д. Подставляем, получим квадратное уравнение относительно t
		// решение t = (-b +- sqrt(b*b - 4ac)) / 2a
		// решая t^2*ray.dir*ray.dir + 2*t*(orig-p)*ray.dir + (orig-p)*(orig-p) - rad*rad = 0 
		float3 op = pos - r.orig;    // дистанция от ray.orig до центра сфера
		float t, epsilon = 0.0001f;  // epsilon для сравнения флотов
		float b = dot(op, r.dir);    // b в уравнении
		float disc = b*b - dot(op, op) + rad*rad;
		if (disc<0) return 0;
		else disc = sqrtf(disc);
		return (t = b - disc)>epsilon ? t : ((t = b + disc)>epsilon ? t : 0);
	}
};