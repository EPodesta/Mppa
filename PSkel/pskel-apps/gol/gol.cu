#include <omp.h>
#include <fstream>
#include <string>
#include <stdio.h>
#include <iostream>
#include <sstream>

#include <unistd.h>

#include <cassert>

//#define PSKEL_SHARED_MASK
#include "../include/PSkel.h"

#include "../util/hr_time.h"

using namespace std;
using namespace PSkel;

namespace PSkel{
	__parallel__ void stencilKernel(Array2D<int> input,Array2D<int> output,Mask2D<int> mask,int null, size_t h, size_t w){
		int neighbors=0;
		for(int z=0;z<mask.size;z++){
			neighbors += mask.get(z,input,h,w);
		}	
		output(h,w) = ((neighbors==3 || (input(h,w)==1 && neighbors==2))?1:0);
	}
}

int main(int argc, char **argv){
	int width,height,iterations,GPUBlockSize,numCPUThreads,mode,tileHeight,tileIterations;
	if (argc != 9){
		printf ("Wrong number of parameters.\n", argv[0]);
		printf ("Usage: gol WIDTH HEIGHT ITERATIONS MODE GPUBLOCKS CPUTHREADS TILEHEIGHT TILEITERATIONS\n");
		exit (-1);
	}

	width = atoi (argv[1]);
	height = atoi (argv[2]);
	iterations = atoi (argv[3]);
	mode = atoi(argv[4]);
	GPUBlockSize = atoi(argv[5]);
	numCPUThreads = atoi(argv[6]);
	tileHeight = atoi(argv[7]);
	tileIterations = atoi(argv[8]);
	
	Array2D<int> inputGrid(width,height);
	Array2D<int> outputGrid(width,height);
	
	Mask2D<int> mask(8);
	mask.set(0,-1,-1);	mask.set(1,-1,0);	mask.set(2,-1,1);
	mask.set(3,0,-1);				mask.set(4,0,1);
	mask.set(5,1,-1);	mask.set(6,1,0);	mask.set(7,1,1);
	
	srand(123456789);
	for(int h=0;h<height;h++) {
		for(int w=0;w<width;w++) {
			inputGrid(h,w) = rand()%2;
		}
	}
	
	Stencil2D<Array2D<int>, Mask2D<int>, int> stencil(inputGrid, outputGrid, mask, 0);
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
		stencil.runIterativeTilingGPU(iterations, width, tileHeight, 1, tileIterations, GPUBlockSize);	
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
