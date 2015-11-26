CC 		= g++
CUDAC 		= nvcc
OPTIMUS         = optirun #remover este valor se não estiver em um sistema OPTIMUS (notebook)
CUDA_LIB_PATH   = /usr/local/cuda-5.5/lib64
#CUDAFLAGS = -O3 -Xcompiler -ftree-vectorize -Xcompiler -msse4 #-I/usr/local/cuda-5.5/extras/CUPTI/include -ccbin g++  -Xcompiler -Wall
CUDAFLAGS       = -O3 -arch=sm_21 -Xcompiler -ftree-vectorize #-ccbin g++ -g -O3 -w -m64 -Xcompiler -fopenmp -Xcompiler -ftree-vectorize -Xcompiler -msse4 #-Xcompiler -ftree-vectorizer-verbose=3
CXXFLAGS	= -O3 -w
OMPFLAGS        = -O3 -w
GENCODE		= -gencode arch=compute_20,code=sm_20 -gencode arch=compute_30,code=sm_30 -gencode arch=compute_35,code=\"sm_35,compute_35\"
OMP_TBB         = -fopenmp -lgomp -ltbb
OMP        	 = -fopenmp -lgomp
LIBS		= -Xcompiler -fopenmp -lgomp -ltbb -I../../lib/ -L../../lib/ga -lga -lm 
SRC_NAME        = cloudsim
BIN_DIR         = ./

all: clean pskel
	
pskel: ${SRC_NAME}.cu
	#${CUDAC} ${CUDAFLAGS} ${GENCODE} -o ${SRC_NAME}.o -c ${SRC_NAME}.cu
	${CUDAC} ${CUDAFLAGS} -o ${BIN_DIR}${SRC_NAME} ${SRC_NAME}.cu ${LIBS} -DPSKEL_TBB

testpskelgpu:
	time -p ${BIN_DIR}${SRC_NAME} 70 100 100  20 -3 5.0 700.0 0.001 1.0 32 12

clean:
	 rm -f *.o ${BIN_DIR}${SRC_NAME}
