#include <stdio.h>
#include <omp.h>
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>

//#define PSKEL_SHARED_MASK
#include "../include/PSkel.h"

#include "../util/hr_time.h"

using namespace std;
using namespace PSkel;

struct Arguments{
	float alpha, beta;
};

namespace PSkel{
	__parallel__
	void stencilKernel(Array3D<float> input,Array3D<float> output,Mask3D<float> mask,Arguments args, size_t i, size_t j, size_t k){
		output(i,j,k) = args.alpha * input(i,j,k) +
						args.beta * (mask.get(0,input,i,j,k) + mask.get(1,input,i,j,k) + 
									 mask.get(2,input,i,j,k) + mask.get(3,input,i,j,k) + 
									 mask.get(4,input,i,j,k) + mask.get(5,input,i,j,k) );
	}
}

int main(int argc, char **argv){
	int width,height,depth,iterations,GPUBlockSize,numCPUThreads,mode,tileHeight,tileIterations;
	if (argc != 10){
		printf ("Wrong number of parameters.\n", argv[0]);
		printf ("Usage: gol WIDTH HEIGHT DEPTH ITERATIONS MODE GPUBLOCKS CPUTHREADS TILEHEIGHT TILEITERATIONS\n");
		exit (-1);
	}

	width = atoi (argv[1]);
	height = atoi (argv[2]);
	depth = atoi (argv[3]);
	iterations = atoi (argv[4]);
	mode = atoi(argv[5]);
	GPUBlockSize = atoi(argv[6]);
	numCPUThreads = atoi(argv[7]);
	tileHeight = atoi(argv[8]);
	tileIterations = atoi(argv[9]);
	
	Array3D<float> inputGrid(width, height, depth);
	Array3D<float> outputGrid(width, height, depth);
	Mask3D<float> mask(6);
	
	mask.set(0,1,0,0);
	mask.set(1,-1,0,0);
	mask.set(2,0,1,0);
	mask.set(3,0,-1,0);
	mask.set(4,0,0,1);
	mask.set(5,0,0,-1);

	Arguments args;
	args.alpha = 1.f / (float)width;
	args.beta = 2.f / (float)height;
	
	omp_set_num_threads(numCPUThreads);

	/* initialize the first timesteps */
	#pragma omp parallel for
	for(int h = 0; h<height; h++){
		for (int w = 0; w<width; w++){
			for (int d = 0; d<depth; d++){
				inputGrid(h,w,d) = 1.0 + w*0.1 + h*0.01 + d*0.001;
			}
		}
	}
	
	Stencil3D<Array3D<float>, Mask3D<float>, Arguments> stencil(inputGrid, outputGrid, mask, args);
	hr_timer_t timer;
	switch(mode){
	case 0:
		hrt_start(&timer);
		stencil.runIterativeSequential(iterations);
		hrt_stop(&timer);
		break;
	case 1:
		hrt_start(&timer);
		stencil.runIterativeCPU(iterations,numCPUThreads);
		hrt_stop(&timer);
		break;
	case 2:
		hrt_start(&timer);
		stencil.runIterativeGPU(iterations, GPUBlockSize);	
		hrt_stop(&timer);
		break;
	case 3:
		hrt_start(&timer);
		stencil.runIterativeTilingGPU(iterations, width, tileHeight, depth, tileIterations, GPUBlockSize);	
		hrt_stop(&timer);
		break;
	case 4:
		hrt_start(&timer);
		stencil.runIterativeAutoGPU(iterations, GPUBlockSize);	
		hrt_stop(&timer);
		break;
	}
	cout << hrt_elapsed_time(&timer);
	inputGrid.hostFree();
	outputGrid.hostFree();

	return 0;	
}
