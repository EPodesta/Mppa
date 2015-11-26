#include <stdio.h>
#include <omp.h>
#include <iostream>
#include <time.h>
#include <stdlib.h>
#include <math.h>
#include <fstream>
#include <string>
#include <sys/stat.h>
#include <algorithm>

#include "../../include/PSkel.h"

#include "../util/hr_time.h"

using namespace std;
using namespace PSkel;

#define WIND_X_BASE	15
#define WIND_Y_BASE	12
#define DISTURB		0.1
#define CELL_LENGTH	0.1
#define K           	0.0243
#define DELTAPO       	0.5
#define TAM_VETOR_FILENAME  200

int numThreads;
int count_write_step;
char dirname[TAM_VETOR_FILENAME];
char *typeSim;

struct Cloud{	
	Args2D<float> wind_x, wind_y;
	float deltaT;
	
	Cloud(){};
	
	Cloud(int linha, int coluna){		
		new (&wind_x) Args2D<float>(linha, coluna);
		new (&wind_y) Args2D<float>(linha, coluna);
	}
};

namespace PSkel{
/*
	__parallel__ void stencilKernel(Array2D<float> input,Array2D<float> output,Mask2D<float> mask,Cloud cloud,size_t i, size_t j){
		int numNeighbor = 0;

		float sum = 0;
		float temperatura_conducao = 0;
		for( int m = 0; m < 4 ; m++ )
		{
			float temperatura_vizinho = mask.get(m,input,i,j);
			if(temperatura_vizinho != 0){
				sum += input(i,j) - temperatura_vizinho;
				numNeighbor++;
			}				
		}			
		temperatura_conducao = -K*(sum / numNeighbor)*cloud.deltaT;

		output(i,j) = input(i,j) + temperatura_conducao;


		// Implementation the vertical wind
		if(numNeighbor == 4)
		{
			float componenteVentoX = 0;
			float componenteVentoY = 0;
			float temperaturaNeighborX = 0;
			float temperaturaNeighborY = 0;				

			if(cloud.wind_x(i,j) > 0)
			{
				temperaturaNeighborX = mask.get(3,input,i,j);
				componenteVentoX     = cloud.wind_x(i,j);
			}
			else
			{
				temperaturaNeighborX = mask.get(1,input,i,j);
				componenteVentoX     = -1*cloud.wind_x(i,j);
			}

			if(cloud.wind_y(i,j) > 0)
			{
				temperaturaNeighborY = mask.get(2,input,i,j);
				componenteVentoY     = cloud.wind_y(i,j);
			}
			else
			{
				temperaturaNeighborY = mask.get(0,input,i,j);
				componenteVentoY     = -1*cloud.wind_y(i,j);
			}

			float temp_wind = (-componenteVentoX * ((input(i,j) - temperaturaNeighborX)/CELL_LENGTH)) -(componenteVentoY * ((input(i,j) - temperaturaNeighborY)/CELL_LENGTH));
			output(i,j) = output(i,j) + (temp_wind * cloud.deltaT);
		}
	}
*/

	__parallel__ void stencilKernel(Array2D<float> input,Array2D<float> output,Mask2D<float> mask,Cloud cloud,size_t h,size_t w){
		int numNeighbor = 0;
		float sum = 0;
		float inValue = input(h,w);

		#pragma unroll
		for(int m=0; m<4; m++){
			float temperatura_vizinho = mask.get(m,input,h,w);
			int factor = (temperatura_vizinho==0)?0:1;
			sum += factor*(inValue - temperatura_vizinho);
			numNeighbor += factor;
		}			
		float temperatura_conducao = -K*(sum / numNeighbor)*cloud.deltaT;
		float result = inValue + temperatura_conducao;

		float xwind = cloud.wind_x(h,w);
		float ywind = cloud.wind_y(h,w);
		int xfactor = (xwind>0)?3:1;
		int yfactor = (ywind>0)?2:0;

		float temperaturaNeighborX = mask.get(xfactor,input,h,w);
		float componenteVentoX = (xfactor-2)*xwind;
		float temperaturaNeighborY = mask.get(yfactor,input,h,w);
		float componenteVentoY = (yfactor-1)*ywind;
		
		float temp_wind = (-componenteVentoX * ((inValue - temperaturaNeighborX)/CELL_LENGTH)) -(componenteVentoY * ((inValue - temperaturaNeighborY)/CELL_LENGTH));
		
		output(h,w) = result + ((numNeighbor==4)?(temp_wind*cloud.deltaT):0);
	}

}

/* Convert Celsius to Kelvin */
float Convert_Celsius_To_Kelvin(float number_celsius)
{
	float number_kelvin;
	number_kelvin = number_celsius + 273.15;
	return number_kelvin;
}

/* Convert Pressure(hPa) to Pressure(mmHg) */
float Convert_hPa_To_mmHg(float number_hpa)
{
	float number_mmHg;
	number_mmHg = number_hpa * 0.750062;

	return number_mmHg;
}

/* Convert Pressure Millibars to mmHg */
float Convert_milibars_To_mmHg(float number_milibars)
{
	float number_mmHg;
	number_mmHg = number_milibars * 0.750062;

	return number_mmHg;
}

/* Calculate RPV */
float CalculateRPV(float temperature_Kelvin, float pressure_mmHg)
{
	float realPressureVapor; //e
	float PsychrometricConstant = 6.7 * powf(10,-4); //A
	float PsychrometricDepression = 1.2; //(t - tu) in ºC
	float esu = pow(10, ((-2937.4 / temperature_Kelvin) - 4.9283 * log10(temperature_Kelvin) + 23.5470)); //10 ^ (-2937,4 / t - 4,9283 log t + 23,5470)
	realPressureVapor = Convert_milibars_To_mmHg(esu) - (PsychrometricConstant * pressure_mmHg * PsychrometricDepression);

	return realPressureVapor;
}

/* Calculate Dew Point */
float CalculateDewPoint(float temperature_Kelvin, float pressure_mmHg)
{
	float dewPoint; //TD
	float realPressureVapor = CalculateRPV(temperature_Kelvin, pressure_mmHg); //e
	dewPoint = (186.4905 - 237.3 * log10(realPressureVapor)) / (log10(realPressureVapor) -8.2859);

	return dewPoint;
}

/*Calculate temperature grid standard deviation */
void StandardDeviation(Array2D<float> grid, int linha, int coluna, int iteracao, char *dirname, int numThreads, char *typeSim, float average)
{
	FILE *file;
	char filename[TAM_VETOR_FILENAME];
	double desviopadrao = 0;
	double variancia = 0;	

	if(numThreads > 1)		
		sprintf(filename,"%s//%s-desviopadrao-temperature-simulation-%d-thread.txt",dirname, typeSim,numThreads);
	else		
		sprintf(filename,"%s//%s-desviopadrao-temperature-simulation.txt",dirname, typeSim);
	file = fopen(filename, "a");	
	
	#pragma omp parallel for reduction (+:variancia)
	for(int i = 0; i < linha; i++)
	{
		for(int j = 0; j < coluna; j++)
		{			
			variancia+=pow((grid(i,j)-average),2);
		}		
	 }	
	 desviopadrao = sqrt(variancia/(linha*coluna-1));
	 fprintf(file,"%d\t%lf\n",iteracao, desviopadrao);
	 fclose(file);
}

/*Calculate temperature grid average */
void CalculateAverage(Array2D<float> grid, int linha, int coluna, int iteracao, char *dirname, int numThreads, char *typeSim)
{
	FILE *file;
	char filename[TAM_VETOR_FILENAME];
	double sum = 0;
	double average = 0;	

	if(numThreads > 1)		
		sprintf(filename,"%s//%s-average-temperature-simulation-%d-thread.txt",dirname, typeSim,numThreads);		
	else		
		sprintf(filename,"%s//%s-average-temperature-simulation.txt",dirname, typeSim);
	file = fopen(filename, "a");	
	
	#pragma omp parallel for reduction (+:sum)
	for(int i = 0; i < linha; i++)
	{		
		for(int j = 0; j < coluna; j++)
		{			
			sum+=grid(i,j);
		}		
	 }	
	 average = sum/(linha*coluna);
	 //fprintf(file,"%d\t%lf\n",iteracao, average);
	 fprintf(file,"%lf\n", average);
	 printf("Media:%d\t%lf\n",iteracao, average);
	 fclose(file);
	 
	// StandardDeviation(grid, linha, coluna, iteracao, dirname, numThreads, typeSim, average);
	 
}

/* Calculate statistics of temperature grid */
void CalculateStatistics(Array2D<float> grid, int linha, int coluna, int iteracao, char *dirname, int numThreads, char *typeSim)
{
	CalculateAverage(grid, linha, coluna, iteracao, dirname, numThreads, typeSim);	
}


/* Write grid temperature in text file */
void WriteGridTemp(Array2D<float> grid, int linha, int coluna, int iteracao, int numThreads, char *dirname, char *typeSim)
{
	FILE *file;
	char filename[TAM_VETOR_FILENAME];
	
	if(numThreads > 1)
		sprintf(filename,"%s//%s-temp_%d-thread_iteration#_%d.txt",dirname, typeSim, numThreads, iteracao);
	else
		sprintf(filename,"%s//%s-temp_iteration#_%d.txt",dirname, typeSim, iteracao);
		
	file = fopen(filename, "w");		

	fprintf(file, "Iteração: %d\n", iteracao);
	for(int i = 0; i < linha; i++)
	{
		for(int j = 0; j < coluna; j++)
		{
			fprintf(file, "%.4f  ", grid(i,j));
		}
		fprintf(file, "\n");
	 }		
	fclose(file);
}

/* Write time simulation */
void WriteTimeSimulation(float time, int numThreads, char *dirname, char *typeSim)
{
	FILE *file;
	char filename[TAM_VETOR_FILENAME];
	
	if(numThreads > 1)
		sprintf(filename,"%s//%stime-sim_%d-thread.txt",dirname, typeSim, numThreads);
	else
		sprintf(filename,"%s//%stime-sim.txt",dirname, typeSim);

	file = fopen(filename,"r");
	if (file==NULL)
	{
		file = fopen(filename, "w");
		//fprintf(file,"Time %s-simulation", typeSim);
		fprintf(file,"\nUpdate Time: %f segundos", time);
	}
	else
	{
		file = fopen(filename, "a");
		fprintf(file,"\nUpdate Time: %f segundos", time);
	}
	
	fclose(file);
}

/* Write Simulation info all parameters */
void WriteSimulationInfo(int numero_iteracoes, int linha, int coluna, int raio_nuvem, float temperaturaAtmosferica, float alturaNuvem, float pressaoAtmosferica, float deltaT, float pontoOrvalho, int menu_option, int write_step, int numThreads, float GPUTime, char *dirname, char *typeSim)
{	
	FILE *file;
	char filename[TAM_VETOR_FILENAME];
	sprintf(filename,"%s//%s-simulationinfo.txt",dirname, typeSim);
	
	file = fopen(filename,"r");
	if (file==NULL)
	{		
		file = fopen(filename, "w");
		fprintf(file,"***Experimento %s***", typeSim);
		fprintf(file,"\nData_%s",__DATE__);
		if(numThreads > 1){
		fprintf(file,"\nNúmero de Threads:%d", numThreads);
		fprintf(file,"\nProporção GPU:%.0f%", GPUTime*100);
		fprintf(file,"\nProporção CPU:%.0f%", (1.0-GPUTime)*100);
		}
		fprintf(file,"\nTemperatura Atmosférica:%.1f", temperaturaAtmosferica);
		fprintf(file,"\nAltura da Nuvem:%.1f", alturaNuvem);
		fprintf(file,"\nPonto de Orvalho:%f", pontoOrvalho);
		fprintf(file,"\nPressao:%.1f", pressaoAtmosferica);
		fprintf(file,"\nCondutividade térmica:%f", K);
		fprintf(file,"\nDeltaT:%f", deltaT);		
		fprintf(file,"\nNúmero de Iterações:%d", numero_iteracoes);
		fprintf(file,"\nTamanho da Grid:%dX%d", linha, coluna);
		fprintf(file,"\nRaio da nuvem:%d", raio_nuvem);
		fprintf(file,"\nNúmero de Processadores do Computador:%d", omp_get_num_procs());
		fprintf(file,"\nDelta Ponto de Orvalho:%f", DELTAPO);
		fprintf(file,"\nLimite Inferior Ponto de Orvalho:%lf", (pontoOrvalho - DELTAPO));
		fprintf(file,"\nLimite Superior Ponto de Orvalho:%lf", (pontoOrvalho + DELTAPO));
		fprintf(file,"\nMenu Option:%d", menu_option);
		fprintf(file,"\nWrite Step:%d", write_step);
		
		fclose(file);
	}
	else
	{
		char filename_old[TAM_VETOR_FILENAME];
		string line;
		int posicao;
		char buffer [33];

		sprintf(filename_old,"%s//file_temp.txt",dirname);
		ofstream outFile(filename_old, ios::out);
		ifstream fileread(filename);

	    	while(!fileread.eof())
		{
			getline(fileread, line);
			posicao = line.find("Threads:");
			if (posicao!= string::npos)
			{
				string line_temp = line.substr(posicao+1, line.size());
				sprintf (buffer, "%d", numThreads);
				posicao = line_temp.find(buffer);
				if (posicao!= string::npos)
				{
					outFile << line << '\n';
				}
				else
				{
					sprintf (buffer, ",%d", numThreads);
					line.append(buffer);
					outFile << line << '\n';
				}
			}
			else
				outFile << line << '\n';
		}
		remove(filename);
		rename(filename_old, filename);
		outFile.close();
		fileread.close();
	}	
}

/* Write grid wind in text file */
void WriteGridWind(Cloud cloud, int linha, int coluna, char *dirname_windx, char *dirname_windy)
{
	FILE *file_windx, *file_windy;
	char filename_windx[TAM_VETOR_FILENAME];
	char filename_windy[TAM_VETOR_FILENAME];

	sprintf(filename_windx,"%s//windX.txt",dirname_windx);
	sprintf(filename_windy,"%s//windY.txt",dirname_windy);
	file_windx = fopen(filename_windx,"r");
	file_windy = fopen(filename_windy, "r");

        if (file_windx == NULL && file_windy == NULL)
	{
		file_windx = fopen(filename_windx, "w");
        	file_windy = fopen(filename_windy, "w");
		for(int i = 0; i < linha; i++)
		{
			for(int j = 0; j < coluna; j++)
			{
			fprintf(file_windx, "%.4f  ", cloud.wind_x(i,j));
			fprintf(file_windy, "%.4f  ", cloud.wind_y(i,j));
			}
		fprintf(file_windx, "\n");
		fprintf(file_windy, "\n");
	 	}
	}
	fclose(file_windx);
        fclose(file_windy);
}


int main(int argc, char **argv){
	int width,height,iterations, raio_nuvem, GPUBlockSize, numCPUThreads;
	float temperaturaAtmosferica, alturaNuvem, pressaoAtmosferica, pontoOrvalho, limInfPO, limSupPO, deltaT;
	int mode, tileHeight, tileIterations;
	if (argc != 14){
		printf ("Wrong number of parameters.\n", argv[0]);
		printf ("Usage: cloudsim Numero_Iteraoes Linha Coluna Raio_Nuvem Temperatura_Atmosferica Altura_Nuvem Pressao_Atmosferica Delta_T GPUTIME GPUBLOCKS CPUTHREADS\n");
		exit (-1);
	}
	width = atoi(argv[1]);
	height = atoi(argv[2]);
	iterations = atoi(argv[3]);
	raio_nuvem = atoi(argv[4]);
	temperaturaAtmosferica = atof(argv[5]);
	alturaNuvem = atof(argv[6]);
	pressaoAtmosferica = atof(argv[7]);
	deltaT = atof(argv[8]);
	mode = atoi(argv[9]);
	GPUBlockSize = atoi(argv[10]);
	numCPUThreads = atoi(argv[11]);
	tileHeight = atoi(argv[12]);
	tileIterations = atoi(argv[13]);
	numThreads = numCPUThreads;
	pontoOrvalho = CalculateDewPoint(Convert_Celsius_To_Kelvin(temperaturaAtmosferica), Convert_hPa_To_mmHg(pressaoAtmosferica));
	limInfPO = pontoOrvalho - DELTAPO;
	limSupPO = pontoOrvalho + DELTAPO;
	
	Array2D<float> inputGrid(width, height);
	Array2D<float> outputGrid(width, height);
	Mask2D<float> mask(4);
	
	mask.set(0,0,1);
	mask.set(1,1,0);
	mask.set(2,0,-1);
	mask.set(3,-1,0);
	
	Cloud cloud(height,width);
	cloud.deltaT = deltaT;
	
	omp_set_num_threads(numCPUThreads);

	/* Inicialização da matriz de entrada com a temperatura ambiente */
	#pragma omp parallel for
	for(int h=0; h<height; h++){		
		for (int w=0; w<width; w++){
			inputGrid(h,w) = temperaturaAtmosferica;
		}
	}	
	/* Inicialização dos ventos Latitudinal(Wind_X) e Longitudinal(Wind_Y) */
	for(int h=0; h<height; h++){
		for(int w=0; w<width; w++){			
			cloud.wind_x(h,w) = (WIND_X_BASE - DISTURB) + (float)rand()/RAND_MAX * 2 * DISTURB;
			cloud.wind_y(h,w) = (WIND_Y_BASE - DISTURB) + (float)rand()/RAND_MAX * 2 * DISTURB;
		}
	}

	/* Inicialização de uma nuvem no centro da matriz de entrada */
	int y, x0 = height/2, y0 = width/2;
	srand(1);
	for(int i = x0 - raio_nuvem; i < x0 + raio_nuvem; i++){
		 // Equação da circunferencia: (x0 - x)² + (y0 - y)² = r²
		y = (int)((floor(sqrt(pow((float)raio_nuvem, 2.0) - pow(((float)x0 - (float)i), 2)) - y0) * -1));

		for(int j = y0 + (y0 - y); j >= y; j--){
			inputGrid(i,j) = limInfPO + (float)rand()/RAND_MAX * (limSupPO - limInfPO);
			//outputGrid(i,j) = limInfPO + (float)rand()/RAND_MAX * (limSupPO - limInfPO);
		}
	}
	
	Stencil2D<Array2D<float>, Mask2D<float>, Cloud> stencil(inputGrid, outputGrid, mask, cloud);
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

