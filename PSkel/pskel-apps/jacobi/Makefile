CC 				=  g++
CUDAC 			= nvcc
#OPTIMUS         = optirun #remover este valor se não estiver em um sistema OPTIMUS (notebook)
CUDA_LIB_PATH   = /usr/local/cuda-5.5/lib64
CUDAFLAGS = --compiler-bindir /usr/bin/gcc-4.4.7 -O3 -Xcompiler -ftree-vectorize -Xcompiler -msse4 #-I/usr/local/cuda-5.5/extras/CUPTI/include -ccbin g++  -Xcompiler -Wall
#CUDAFLAGS       = -O3 -arch=sm_21 -m64 -Xcompiler -ftree-vectorize -Xcompiler -msse4 #-I/usr/local/cuda-5.5/extras/CUPTI/include -ccbin g++  -Xcompiler -Wall
CXXFLAGS		= -O3 -w
GENCODE = -gencode arch=compute_20,code=sm_20 -gencode arch=compute_30,code=sm_30 -gencode arch=compute_35,code=\"sm_35,compute_35\"
OMP_TBB = -fopenmp -lgomp -ltbb
LIBS = -Xcompiler -fopenmp -lgomp -ltbb -lcuda -I../../lib/ -L../../lib/ga -lga -lm #-L /usr/local/cuda-5.5/extras/CUPTI/lib -L /usr/local/cuda-5.5/extras/CUPTI/lib64 -lcupti
SRC_NAME = jacobi
BIN_DIR = ./

all: clean pskel

pskel:  ${SRC_NAME}.cu
	${CUDAC} ${CUDAFLAGS} -o ${BIN_DIR}${SRC_NAME} ${SRC_NAME}.cu ${LIBS} -DPSKEL_TBB

clean:
	 rm -f *.o ${BIN_DIR}${SRC_NAME}
