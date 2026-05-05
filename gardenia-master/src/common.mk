CUDA_HOME=/home/dbh/miniconda3/envs/cugraph_env
CUB_DIR=../../cub
BIN=../../bin
HOST=X86
CC=gcc
CXX=g++
NVCC=/home/dbh/miniconda3/pkgs/cuda-nvcc-tools-12.0.76-h59595ed_1/bin/nvcc
COMPUTECAPABILITY=sm_60
CUDA_ARCH := \
	-gencode arch=compute_61,code=sm_61 \
	-gencode arch=compute_70,code=sm_70 \
	-gencode arch=compute_86,code=sm_86
CXXFLAGS=-Wall -fopenmp -std=c++11 -g -O3 -DCUDA_FORCE_MIXED_MODE_GCC_SUPPORT
NVFLAGS=$(CUDA_ARCH)
NVFLAGS+=-O3 -w -Xcompiler -fno-canonical-system-headers
NVFLAGS+=-allow-unsupported-compiler
INCLUDES = -I../../include -I/home/dbh/miniconda3/pkgs/cuda-cudart-dev-12.0.107-hd3aeb46_8/include -I/home/dbh/miniconda3/pkgs/cuda-cccl_linux-64-12.0.90-ha770c72_1/targets/x86_64-linux/include -I/home/dbh/miniconda3/pkgs/cuda-cudart-dev_linux-64-12.0.107-h59595ed_8/targets/x86_64-linux/include -I/home/dbh/miniconda3/pkgs/cuda-cccl_linux-64-12.0.90-ha770c72_1/targets/x86_64-linux/include/thrust
LIBS = -L/home/dbh/miniconda3/pkgs/cuda-cudart_linux-64-12.0.107-h59595ed_8/targets/x86_64-linux/lib -L/home/dbh/miniconda3/pkgs/cuda-runtime-12.0.107-h59595ed_8/targets/x86_64-linux/lib -lgomp -lcudart -lcuda -L/usr/lib/wsl/lib -lcuda