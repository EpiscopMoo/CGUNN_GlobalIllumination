#include <stdio.h>
#include <vector_types.h>
#include "device_launch_parameters.h"
#include "cutil_math.h"
#include "predefs.cuh"
#include "entities.cuh"
#include "path_tracing.cuh"

// SCENE
// { float radius, { float3 position }, { float3 emission }, { float3 colour }, refl_type }
__constant__ Sphere spheres[] = 
{
	{ 1e5f, { 1e5f + 1.0f, 40.8f, 81.6f }, { 0.0f, 0.0f, 0.0f }, { 0.99f, 0.25f, 0.25f }, SPEC }, //Левая стена 
	{ 1e5f, { -1e5f + 99.0f, 40.8f, 81.6f }, { 0.0f, 0.0f, 0.0f }, { .25f, .25f, .99f }, DIFF }, //Правая 
	{ 1e5f, { 50.0f, 40.8f, 1e5f }, { 0.0f, 0.0f, 0.0f }, { .75f, .75f, .75f }, DIFF }, //Дальняя 
	{ 1e5f, { 50.0f, 40.8f, -1e5f + 600.0f }, { .0f, 0.0f, 0.0f }, { 1.00f, 1.00f, 1.00f }, DIFF }, //Передняя, но в неё не будем попадать 
	{ 1e5f, { 50.0f, 1e5f, 81.6f }, { 0.0f, 0.0f, 0.0f }, { .75f, .75f, .75f }, GENR }, //Пол 
	{ 1e5f, { 50.0f, -1e5f + 81.6f, 81.6f }, { 0.0f, 0.0f, 0.0f }, { .75f, .75f, .75f }, DIFF }, //Потолок 
	{ 16.5f, { 18.0f, 49.5f, 47.0f }, { 0.0f, 0.0f, 0.0f }, { 1.0f, 1.0f, 1.0f }, DIFF }, // шар 1
	{ 16.5f, { 73.0f, 16.5f, 47.0f }, { 0.0f, 0.0f, 0.0f }, { 0.99f, 0.99f, 1.0f }, SPEC }, // шар 2
	{ 16.5f, { 30.0f, 20.0f, 78.0f }, { 0.0f, 0.0f, 0.0f }, { 0.99f, 0.99f, 0.99f }, REFR }, // шар 3
	{ 600.0f, { 50.0f, 681.6f - .77f, 81.6f }, { 2.0f, 1.8f, 1.6f }, { 0.0f, 0.0f, 0.0f }, DIFF }  // свет
};

__global__ void render_kernel(float3 *output, Sphere* spheres, int count, float* presets, int preset_num, int samps)
{
	Preset preset(presets, preset_num);
	unsigned int x = blockIdx.x*blockDim.x + threadIdx.x;   
	unsigned int y = blockIdx.y*blockDim.y + threadIdx.y;

	unsigned int i = (height - y - 1)*width + x; // index of current pixel (calculated using thread index) 

	unsigned int s1 = x;  // seeds for random number generator
	unsigned int s2 = y;

	Ray cam(make_float3(50, 52, 295.6), normalize(make_float3(0, -0.042612, -1)));
	float3 cx = make_float3(width * .5135 / height, 0.0f, 0.0f);
	float3 cy = normalize(cross(cx, cam.dir)) * .5135;
	float3 r; // r is final pixel color       
    
	r = make_float3(0.0f);

	for (int s = 0; s < samps; s++)
	{    
		float3 d = cam.dir + cx*((.25 + x) / width - .5) + cy*((.25 + y) / height - .5);
  
		Ray cam_ray(cam.orig + d * 40, normalize(d));
		r = r + radiance(
			spheres, count, 
			cam_ray, &s1, &s2, &preset)*(1. / samps); 
	}
	output[i] = make_float3(clamp(r.x, 0.0f, 1.0f), clamp(r.y, 0.0f, 1.0f), clamp(r.z, 0.0f, 1.0f));
}

float3* cuda_main(int* w, int* h, float* cpu_presets, int preset_num, int samples = 128)
{
	*w = width;
	*h = height;
	float3* output_h = new float3[width*height]; // pointer to memory for image on the host (system RAM)
	float3* output_d;    // pointer to memory for image on the device (GPU VRAM)
	float* cuda_presets; //укз на параметры материалов (GPU)

	// allocate memory on the CUDA device (GPU VRAM)
	cudaMalloc(&output_d, width * height * sizeof(float3));
	cudaMalloc(&cuda_presets, preset_num*sizeof(float));
	
	cudaMemcpy(cuda_presets, cpu_presets, preset_num*sizeof(float), cudaMemcpyHostToDevice);
        
	// dim3 is CUDA specific type, block and grid are required to schedule CUDA threads over streaming multiprocessors
	dim3 block(8, 8, 1);   
	dim3 grid(width / block.x, height / block.y, 1);
	
	// schedule threads on device and launch CUDA kernel from host
	render_kernel<<<grid, block>>>(output_d, spheres, 10, cuda_presets, preset_num, samples);  

	// copy results of computation from device back to host
	cudaMemcpy(output_h, output_d, width * height *sizeof(float3), cudaMemcpyDeviceToHost);  
 
	// free CUDA memory
	cudaFree(cuda_presets);
	cudaFree(output_d);
	return output_h;
}