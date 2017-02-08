#pragma once
#include <vector_types.h>
#include "cutil_math.h"

struct Ray 
{ 
	float3 orig; // ����� ���������� ����
	float3 dir;  // ����������� ����
	__device__ Ray(float3 o_, float3 d_) : orig(o_), dir(d_) {} 
};

struct Preset
{
	float* presets;
	int size;
	__device__ Preset(float* p, int n) : presets(p), size(n){}
};

enum Refl_t { DIFF=0, SPEC=1, GENR=-1, REFR=-2 };  // ������� ������� ��������� ��� radiance(), �����. �����������

struct Sphere 
{
	float rad; 
	float3 pos, emi, col; // position, emission, colour 
	int refl;          // ������ ���������

	__device__ float intersect_sphere(const Ray &r) const 
	{          
		// �������� ����������� ����� � ����
		// ���������� ��������� t �� ����� ����������� ��� ����, ���� ����� ���
		// ��-� ���� (������), �������������� �� t: p(x,y,z) = ray.orig + t*ray.dir
		// ��-� �����: x^2 + y^2 + z^2 = rad^2 
		// �.�. ����� � = �0 + t*dirX, y = y0 + t*dirY � �.�. �����������, ������� ���������� ��������� ������������ t
		// ������� t = (-b +- sqrt(b*b - 4ac)) / 2a
		// ����� t^2*ray.dir*ray.dir + 2*t*(orig-p)*ray.dir + (orig-p)*(orig-p) - rad*rad = 0 
		float3 op = pos - r.orig;    // ��������� �� ray.orig �� ������ �����
		float t, epsilon = 0.0001f;  // epsilon ��� ��������� ������
		float b = dot(op, r.dir);    // b � ���������
		float disc = b*b - dot(op, op) + rad*rad;
		if (disc<0) return 0;
		else disc = sqrtf(disc);
		return (t = b - disc)>epsilon ? t : ((t = b + disc)>epsilon ? t : 0);
	}
};