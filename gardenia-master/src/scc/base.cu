// Copyright 2016, National University of Defense Technology
// Authors: Xuhao Chen <cxh@illinois.edu>
#define SCC_VARIANT "base"
#include "scc.h"
#include "cuda_launch_config.hpp"
#include "cutil_subset.h"
#include <thrust/reduce.h>
#include <thrust/execution_policy.h>
#include "timer.h"
#define debug 0
// find reachable vertices
__global__ void bfs_step(int m, int *row_offsets, int *column_indices, unsigned *colors, bool *mark, bool *visited, bool *expanded, bool *changed) {
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int src = tid;
	// if src is valid, visited but not expanded
	if(src < m && !mark[src] && visited[src] && !expanded[src]) {
		expanded[src] = 1;
		int row_begin = row_offsets[src];
		int row_end = row_offsets[src + 1]; 
		for (int offset = row_begin; offset < row_end; ++ offset) {
			int dst = column_indices[offset];
			// if dst is valid and has the same color as src
			if (!mark[dst] && !visited[dst] && (colors[dst] == colors[src])) {
				*changed = true;
				visited[dst] = 1;
			}
		}
	}
}

// trimming trivial SCCs
// Making sure self loops are removed before calling this routine
__global__ void trim_kernel(int m, int *in_row_offsets, int *in_column_indices, int *out_row_offsets, int *out_column_indices, unsigned *colors, bool *mark, bool *is_trimmed, bool *changed, int *num_trimmed) {
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int src = tid;
	if(src < m && !mark[src]) {
		int in_degree = 0;
		int out_degree = 0;
		// calculate the number of incoming neighbors
		int row_begin = in_row_offsets[src];
		int row_end = in_row_offsets[src + 1]; 
		for (int offset = row_begin; offset < row_end; ++ offset) {
			int dst = in_column_indices[offset];
			if(!mark[dst] && colors[dst] == colors[src]) { in_degree ++; break; }
		}
		if (in_degree != 0) {
			// calculate the number of outgoing neighbors
			row_begin = out_row_offsets[src];
			row_end = out_row_offsets[src + 1]; 
			for (int offset = row_begin; offset < row_end; ++ offset) {
				int dst = out_column_indices[offset];
				if(!mark[dst] && colors[dst] == colors[src]) { out_degree ++; break; }
			}
		}

		// remove (disable) the trival SCC
		if (in_degree == 0 || out_degree == 0) {
			mark[src] = 1;
			is_trimmed[src] = 1;
			if(debug) printf("found vertex %d trimmed\n", src);
			//atomicAdd(num_trimmed, 1);
			*changed = true;
		}
	}
}

/*
__global__ void pivot_gen_kernel(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *is_pivot, unsigned *locks, bool *has_pivot) {
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int src = tid;
	if (src < m && !mark[src]) {   
		unsigned c = colors[src];
		if (locks[c & PIVOT_HASH_CONST] == 0) {
			if (atomicCAS(&locks[c & PIVOT_HASH_CONST], 0, src) == 0) {
				*has_pivot = true;
				fw_visited[src] = 1;
				bw_visited[src] = 1;
				is_pivot[src] = 1;
				if(debug) printf("\tselect %d (color %d) as a pivot\n", src, c);
			}
		}
	}
}

__global__ void update_colors_kernel(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *fw_expanded, bool *bw_expanded, bool *is_pivot) {
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int src = tid;
	if (src < m && !mark[src]) {   
		unsigned new_subgraph = (fw_visited[src] ? 1 : 0) + (bw_visited[src] ? 2 : 0);   // F intersec B == 3, F/B == 1 B/F == 2 (V/F)/B == 0
		if (new_subgraph == 3) {
			mark[src] = 1;
			if(debug) printf("\tfind %d (color %d) in the SCC\n", src, colors[src]);
			//atomicAdd(scc_size, 1);
			return;
		}
		unsigned par_subgraph = colors[src];
		unsigned new_color = 3 * par_subgraph + new_subgraph;
		colors[src] = new_color;
		fw_visited[src] = 0;
		bw_visited[src] = 0;
		fw_expanded[src] = 0;
		bw_expanded[src] = 0;
		is_pivot[src] = 0;
	}
}	
//*/
__global__ void update_kernel(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *fw_expanded, bool *bw_expanded, bool *is_pivot, unsigned *locks, bool *has_pivot, int *scc_size) {
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int src = tid;
	if (src < m && !mark[src]) {   
		unsigned new_subgraph = (fw_visited[src] ? 1 : 0) + (bw_visited[src] ? 2 : 0);   // F intersec B == 3, F/B == 1 B/F == 2 (V/F)/B == 0
		if (new_subgraph == 3) {
			mark[src] = 1;
			if(debug) printf("\tfind %d (color %d) in the SCC\n", src, colors[src]);
			//atomicAdd(scc_size, 1);
			return;
		}
		unsigned par_subgraph = colors[src];
		unsigned new_color = 3 * par_subgraph + new_subgraph;
		colors[src] = new_color;
		fw_visited[src] = 0;
		bw_visited[src] = 0;
		fw_expanded[src] = 0;
		bw_expanded[src] = 0;
		is_pivot[src] = 0;
		//pivots generation
		if (locks[new_color & PIVOT_HASH_CONST] == 0) {
			if (atomicCAS(&locks[new_color & PIVOT_HASH_CONST], 0, src) == 0) {
				*has_pivot = true;
				fw_visited[src] = 1;
				bw_visited[src] = 1;
				is_pivot[src] = 1;
				if(debug) printf("\tselect %d (color %d) as a pivot\n", src, colors[src]);
			}
		}
	}
}

// find forward reachable set
void fw_reach(int m, int *out_row_offsets, int *out_column_indices, unsigned *colors, bool *mark, bool *fw_visited, bool *fw_expanded) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	bool h_changed, *d_changed;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_changed, sizeof(bool)));
	do {
		h_changed = false;
		CUDA_SAFE_CALL(cudaMemcpy(d_changed, &h_changed, sizeof(bool), cudaMemcpyHostToDevice));
		bfs_step<<<nblocks, nthreads>>>(m, out_row_offsets, out_column_indices, colors, mark, fw_visited, fw_expanded, d_changed);
		CudaTest("solving kernel fw_step failed");
		CUDA_SAFE_CALL(cudaMemcpy(&h_changed, d_changed, sizeof(h_changed), cudaMemcpyDeviceToHost));
	} while (h_changed);
	CUDA_SAFE_CALL(cudaFree(d_changed));
}

// find backward reachable set
void bw_reach(int m, int *in_row_offsets, int *in_column_indices, unsigned *colors, bool *mark, bool *bw_visited, bool *bw_expanded) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	bool h_changed, *d_changed;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_changed, sizeof(bool)));
	do {
		h_changed = false;
		CUDA_SAFE_CALL(cudaMemcpy(d_changed, &h_changed, sizeof(bool), cudaMemcpyHostToDevice));
		bfs_step<<<nblocks, nthreads>>>(m, in_row_offsets, in_column_indices, colors, mark, bw_visited, bw_expanded, d_changed);
		CudaTest("solving kernel bw_step failed");
		CUDA_SAFE_CALL(cudaMemcpy(&h_changed, d_changed, sizeof(bool), cudaMemcpyDeviceToHost));
	} while (h_changed);
	CUDA_SAFE_CALL(cudaFree(d_changed));
}

void iterative_trim(int m, int *in_row_offsets, int *in_column_indices, int *out_row_offsets, int *out_column_indices, unsigned *colors, bool *mark, bool *is_trimmed) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	//printf("triming, nblocks=%d, nthreads=%d\n", nblocks, nthreads);
	bool h_changed, *d_changed;
	//int h_num_trimmed = 0, *d_num_trimmed;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_changed, sizeof(bool)));
	//CUDA_SAFE_CALL(cudaMalloc((void **)&d_num_trimmed, sizeof(int)));
	//CUDA_SAFE_CALL(cudaMemcpy(d_num_trimmed, &h_num_trimmed, sizeof(int), cudaMemcpyHostToDevice));
	int iter = 0;
	do {
		iter ++;
		//printf("\ttrimming iteration=%d\n", iter);
		h_changed = false;
		CUDA_SAFE_CALL(cudaMemcpy(d_changed, &h_changed, sizeof(bool), cudaMemcpyHostToDevice));
		trim_kernel<<<nblocks, nthreads>>>(m, in_row_offsets, in_column_indices, out_row_offsets, out_column_indices, colors, mark, is_trimmed, d_changed, NULL);
		CudaTest("solving kernel trim failed");
		CUDA_SAFE_CALL(cudaMemcpy(&h_changed, d_changed, sizeof(bool), cudaMemcpyDeviceToHost));
	} while (h_changed);
	//CUDA_SAFE_CALL(cudaMemcpy(&h_num_trimmed, d_num_trimmed, sizeof(int), cudaMemcpyDeviceToHost));
	CUDA_SAFE_CALL(cudaFree(d_changed));
	//CUDA_SAFE_CALL(cudaFree(d_num_trimmed));
	//return h_num_trimmed;
}
/*
bool pivot_gen(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *is_pivot, unsigned *locks) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	bool h_has_pivot, *d_has_pivot;
	h_has_pivot = false;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_has_pivot, sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemcpy(d_has_pivot, &h_has_pivot, sizeof(h_has_pivot), cudaMemcpyHostToDevice));
	// if the vertex is selected as a pivot, set it visited
	pivot_gen_kernel<<<nblocks, nthreads>>>(m, colors, mark, fw_visited, bw_visited, is_pivot, locks, d_has_pivot);
	CudaTest("solving kernel pivot_gen failed");
	CUDA_SAFE_CALL(cudaMemcpy(&h_has_pivot, d_has_pivot, sizeof(h_has_pivot), cudaMemcpyDeviceToHost));
	return h_has_pivot;
}

void update_colors(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *fw_expanded, bool *bw_expanded, bool *is_pivot) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	update_colors_kernel<<<nblocks, nthreads>>>(m, colors, mark, fw_visited, bw_visited, fw_expanded, bw_expanded, is_pivot);
	CudaTest("solving kernel update_colors failed");
}
//*/
bool update(int m, unsigned *colors, bool *mark, bool *fw_visited, bool *bw_visited, bool *fw_expanded, bool *bw_expanded, bool *is_pivot, unsigned *locks) {
	int nthreads = BLOCK_SIZE;
	int nblocks = (m - 1) / nthreads + 1;
	bool h_has_pivot, *d_has_pivot;
	//int h_scc_size = 0, *d_scc_size;
	h_has_pivot = false;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_has_pivot, sizeof(bool)));
	//CUDA_SAFE_CALL(cudaMalloc((void **)&d_scc_size, sizeof(int)));
	CUDA_SAFE_CALL(cudaMemcpy(d_has_pivot, &h_has_pivot, sizeof(h_has_pivot), cudaMemcpyHostToDevice));
	//CUDA_SAFE_CALL(cudaMemcpy(d_scc_size, &h_scc_size, sizeof(h_scc_size), cudaMemcpyHostToDevice));
	update_kernel<<<nblocks, nthreads>>>(m, colors, mark, fw_visited, bw_visited, fw_expanded, bw_expanded, is_pivot, locks, d_has_pivot, NULL);
	CudaTest("solving kernel update failed");
	CUDA_SAFE_CALL(cudaMemcpy(&h_has_pivot, d_has_pivot, sizeof(h_has_pivot), cudaMemcpyDeviceToHost));
	//CUDA_SAFE_CALL(cudaMemcpy(&h_scc_size, d_scc_size, sizeof(h_scc_size), cudaMemcpyDeviceToHost));
	//printf("scc_size=%d\n", h_scc_size);
	return h_has_pivot;
}

void print_statistics(int m, int nnz, unsigned *d_colors, bool *d_is_trimmed, bool *d_is_pivot, int *in_row_offsets, int *out_row_offsets) {
	unsigned *h_colors = (unsigned *)malloc(m * sizeof(unsigned));
	bool *h_is_trimmed = (bool *)malloc(m * sizeof(bool));
	bool *h_is_pivot = (bool *)malloc(m * sizeof(bool));
	CUDA_SAFE_CALL(cudaMemcpy(h_colors, d_colors, sizeof(int) * m, cudaMemcpyDeviceToHost));
	CUDA_SAFE_CALL(cudaMemcpy(h_is_trimmed, d_is_trimmed, sizeof(bool) * m, cudaMemcpyDeviceToHost));
	CUDA_SAFE_CALL(cudaMemcpy(h_is_pivot, d_is_pivot, sizeof(bool) * m, cudaMemcpyDeviceToHost));
	
	// 1. 基本统计信息
	printf("\n=== 图基本统计信息 ===\n");
	printf("\t顶点数 (|V|): %d\n", m);
	printf("\t边数 (|E|): %d\n", nnz);
	printf("\t图密度: %.6f\n", (double)nnz / (m * (m - 1)));
	
	// 2. 度分布统计
	int *in_degrees = (int *)malloc(m * sizeof(int));
	int *out_degrees = (int *)malloc(m * sizeof(int));
	int min_in_degree = m, max_in_degree = 0, min_out_degree = m, max_out_degree = 0;
	long long sum_in_degree = 0, sum_out_degree = 0;
	
	for (int i = 0; i < m; i++) {
		in_degrees[i] = in_row_offsets[i+1] - in_row_offsets[i];
		out_degrees[i] = out_row_offsets[i+1] - out_row_offsets[i];
		sum_in_degree += in_degrees[i];
		sum_out_degree += out_degrees[i];
		min_in_degree = min(min_in_degree, in_degrees[i]);
		max_in_degree = max(max_in_degree, in_degrees[i]);
		min_out_degree = min(min_out_degree, out_degrees[i]);
		max_out_degree = max(max_out_degree, out_degrees[i]);
	}
	
	printf("\n=== 度分布统计 ===\n");
	printf("\t平均入度: %.2f\n", (double)sum_in_degree / m);
	printf("\t最小入度: %d\n", min_in_degree);
	printf("\t最大入度: %d\n", max_in_degree);
	printf("\t平均出度: %.2f\n", (double)sum_out_degree / m);
	printf("\t最小出度: %d\n", min_out_degree);
	printf("\t最大出度: %d\n", max_out_degree);
	
	// 3. SCC 统计
	int total_num_trimmed = 0;
	int total_num_pivots = 0;
	int num_trivial_scc = 0;
	int num_nontrivial_scc = 0;
	for (int i = 0; i < m; i ++) {
		if (h_is_trimmed[i]) {
			h_colors[i] = INIT_COLOR-1;
			total_num_trimmed ++;
		}
		else if (h_is_pivot[i]) total_num_pivots ++;
		if(debug) printf("color[%d]=%d(trimmed=%d, pivot=%d)\n", i, h_colors[i], h_is_trimmed[i], h_is_pivot[i]);
	}
	num_trivial_scc = total_num_trimmed;
	thrust::sort(h_colors, h_colors + m);
	int k = INIT_COLOR-1;
	bool non_trivial_found = false;
	for (int i = 0; i < m; i ++) if(h_colors[i]>=INIT_COLOR) { k = i; non_trivial_found = true; break; }
	if(debug) printf("k=%d, ", k);
	if (non_trivial_found) {//there is at least one non-trivial SCC
		assert(k==total_num_trimmed);
		num_nontrivial_scc= 1;
		for(int i = k+1; i < m; i ++) {
			if(h_colors[i] > INIT_COLOR && h_colors[i] != h_colors[i-1]) {
				num_nontrivial_scc ++;
			}
		}
	}
	
	// 4. SCC 大小分布
	int *scc_size = (int *)malloc(m * sizeof(int));
	for (int i = 0; i < m; i ++) scc_size[i] = 1;
	int count = 0;
	for (int i = 1; i < m; i ++)
		if (h_colors[i] >= INIT_COLOR) //ignore trivial SCCs
			if (h_colors[i] == h_colors[i-1])
				scc_size[count] ++;
			else if (h_colors[i] > INIT_COLOR)
				count ++;
	for(int i = 0; i < count+1; i++)
		if(scc_size[i] == 1) { num_trivial_scc ++; num_nontrivial_scc --; }
	
	// 统计不同大小的 SCC 分布
	int scc_size_1 = 0, scc_size_2_10 = 0, scc_size_11_100 = 0, scc_size_101_1000 = 0, scc_size_1001_plus = 0;
	for(int i = 0; i < count+1; i++) {
		if(scc_size[i] == 1) scc_size_1++;
		else if(scc_size[i] <= 10) scc_size_2_10++;
		else if(scc_size[i] <= 100) scc_size_11_100++;
		else if(scc_size[i] <= 1000) scc_size_101_1000++;
		else scc_size_1001_plus++;
	}
	
	int biggest_scc_size = thrust::reduce(scc_size, scc_size + m, 0, thrust::maximum<int>());
	int total_scc = num_trivial_scc + num_nontrivial_scc;
	
	// 5. 边路径图统计信息
	printf("\n=== 边路径图统计信息 ===\n");
	printf("\t总边数: %d\n", nnz);
	printf("\t平均路径长度: %.2f\n", (double)nnz / m);
	
	// 6. 循环检测统计
	int num_loops = 0;
	int num_cycles = num_nontrivial_scc; // 非平凡SCC通常包含循环
	printf("\n=== 循环检测统计 ===\n");
	printf("\t平凡 SCC (无循环): %d\n", num_trivial_scc);
	printf("\t非平凡 SCC (含循环): %d\n", num_nontrivial_scc);
	printf("\t总循环数: %d\n", num_cycles);
	
	// 7. SCC 详细统计
	printf("\n=== SCC 统计信息 ===\n");
	printf("\t被修剪的顶点数: %d\n", total_num_trimmed);
	printf("\t枢轴点数量: %d\n", total_num_pivots);
	printf("\t平凡 SCC 数量: %d\n", num_trivial_scc);
	printf("\t非平凡 SCC 数量: %d\n", num_nontrivial_scc);
	printf("\t总 SCC 数量: %d\n", total_scc);
	printf("\t最大 SCC 大小: %d\n", biggest_scc_size);
	printf("\tSCC 密度: %.6f\n", (double)total_scc / m);
	
	// 8. SCC 大小分布（详细）
	printf("\n=== SCC 大小分布 ===\n");
	printf("\t大小为 1: %d (%.2f%%)\n", scc_size_1, (double)scc_size_1 / total_scc * 100);
	printf("\t大小 2-10: %d (%.2f%%)\n", scc_size_2_10, (double)scc_size_2_10 / total_scc * 100);
	printf("\t大小 11-100: %d (%.2f%%)\n", scc_size_11_100, (double)scc_size_11_100 / total_scc * 100);
	printf("\t大小 101-1000: %d (%.2f%%)\n", scc_size_101_1000, (double)scc_size_101_1000 / total_scc * 100);
	printf("\t大小 1001+: %d (%.2f%%)\n", scc_size_1001_plus, (double)scc_size_1001_plus / total_scc * 100);
	
	// 9. 状态空间图特性分析
	printf("\n=== 状态空间图特性 ===\n");
	printf("\t连通性: %s\n", (num_nontrivial_scc > 0 || num_trivial_scc == m) ? "弱连通" : "不连通");
	printf("\t死锁状态: %d (平凡 SCC 数量)\n", num_trivial_scc);
	printf("\t活性状态: %d (非平凡 SCC 数量)\n", num_nontrivial_scc);
	printf("\t状态空间复杂度: %.6f\n", (double)total_scc / m);
	
	// 10. 算法验证信息
	printf("\n=== 算法验证信息 ===\n");
	printf("\tnum_trivial_scc=%d, num_nontrivial=%d, total_num_scc=%d, biggest_scc_size=%d\n", 
		num_trivial_scc, num_nontrivial_scc, total_scc, biggest_scc_size);
	
	free(h_colors);
	free(h_is_trimmed);
	free(in_degrees);
	free(out_degrees);
	free(scc_size);
}

void SCCSolver(int m, int nnz, int source, int *in_row_offsets, int *in_column_indices, int *out_row_offsets, int *out_column_indices, unsigned *h_colors) {
	print_device_info(0);
	Timer t;
	int iter = 0;
	int *d_in_row_offsets, *d_in_column_indices, *d_out_row_offsets, *d_out_column_indices;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_in_row_offsets, (m + 1) * sizeof(int)));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_in_column_indices, nnz * sizeof(int)));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_out_row_offsets, (m + 1) * sizeof(int)));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_out_column_indices, nnz * sizeof(int)));
	//CUDA_SAFE_CALL(cudaMalloc((void **)&d_degree, m * sizeof(int)));
	CUDA_SAFE_CALL(cudaMemcpy(d_in_row_offsets, in_row_offsets, (m + 1) * sizeof(int), cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(d_in_column_indices, in_column_indices, nnz * sizeof(int), cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(d_out_row_offsets, out_row_offsets, (m + 1) * sizeof(int), cudaMemcpyHostToDevice));
	CUDA_SAFE_CALL(cudaMemcpy(d_out_column_indices, out_column_indices, nnz * sizeof(int), cudaMemcpyHostToDevice));
	unsigned *d_colors, *d_locks;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_colors, m * sizeof(unsigned)));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_locks, (PIVOT_HASH_CONST+1) * sizeof(unsigned)));
	//CUDA_SAFE_CALL(cudaMemset(d_locks, 0, (PIVOT_HASH_CONST+1) * sizeof(unsigned)));
	thrust::fill(thrust::device, d_colors, d_colors + m, INIT_COLOR);
	//CUDA_SAFE_CALL(cudaMemcpy(d_colors, h_colors, m * sizeof(unsigned), cudaMemcpyHostToDevice));

	bool *d_mark, *d_fw_visited, *d_bw_visited, *d_fw_expanded, *d_bw_expanded, *d_is_pivot, *d_is_trimmed;
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_mark, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_fw_visited, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_bw_visited, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_fw_expanded, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_bw_expanded, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_is_pivot, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMalloc((void **)&d_is_trimmed, sizeof(bool) * m));
	CUDA_SAFE_CALL(cudaMemset(d_mark, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_fw_visited, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_bw_visited, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_fw_expanded, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_bw_expanded, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_is_pivot, 0, m * sizeof(bool)));
	CUDA_SAFE_CALL(cudaMemset(d_is_trimmed, 0, m * sizeof(bool)));
	bool has_pivot;
	//bool mask = 1;
	//CUDA_SAFE_CALL(cudaMemcpy(&d_is_pivot[source], &mask, sizeof(bool), cudaMemcpyHostToDevice));
	//CUDA_SAFE_CALL(cudaMemcpy(&d_fw_visited[source], &mask, sizeof(bool), cudaMemcpyHostToDevice));
	//CUDA_SAFE_CALL(cudaMemcpy(&d_bw_visited[source], &mask, sizeof(bool), cudaMemcpyHostToDevice));
	printf("Start solving SCC detection...");
	CUDA_SAFE_CALL(cudaDeviceSynchronize());

	t.Start();
	iterative_trim(m, d_in_row_offsets, d_in_column_indices, d_out_row_offsets, d_out_column_indices, d_colors, d_mark, d_is_trimmed);
	//printf("Trim before main loop: num_trimmed=%d\n", num_trimmed);
	bool *h_mark = (bool *)malloc(m * sizeof(bool));
	//bool *h_is_trimmed = (bool *)malloc(m * sizeof(bool));
	CUDA_SAFE_CALL(cudaMemcpy(h_mark, d_mark, m * sizeof(bool), cudaMemcpyDeviceToHost));
	//CUDA_SAFE_CALL(cudaMemcpy(h_is_trimmed, d_is_trimmed, m * sizeof(bool), cudaMemcpyDeviceToHost));
	for (int i = 0; i < m; i++) { 
		if(!h_mark[i]) {
			printf("vertex %d not eliminated, set as the first pivot\n", i);
			source = i;
			break;
		}
	}
	CUDA_SAFE_CALL(cudaMemset(&d_is_pivot[source], 1, 1));
	CUDA_SAFE_CALL(cudaMemset(&d_fw_visited[source], 1, 1));
	CUDA_SAFE_CALL(cudaMemset(&d_bw_visited[source], 1, 1));
	do {
		++ iter;
		has_pivot = false;
		if(debug) printf("iteration=%d\n", iter);
		fw_reach(m, d_out_row_offsets, d_out_column_indices, d_colors, d_mark, d_fw_visited, d_fw_expanded);
		bw_reach(m, d_in_row_offsets, d_in_column_indices, d_colors, d_mark, d_bw_visited, d_bw_expanded);
		//update_colors(m, d_colors, d_mark, d_fw_visited, d_bw_visited, d_fw_expanded, d_bw_expanded, d_is_pivot);
		iterative_trim(m, d_in_row_offsets, d_in_column_indices, d_out_row_offsets, d_out_column_indices, d_colors, d_mark, d_is_trimmed);
		CUDA_SAFE_CALL(cudaMemset(d_locks, 0, (PIVOT_HASH_CONST+1) * sizeof(unsigned)));
		//has_pivot = pivot_gen(m, d_colors, d_mark, d_fw_visited, d_bw_visited, d_is_pivot, d_locks);
		has_pivot = update(m, d_colors, d_mark, d_fw_visited, d_bw_visited, d_fw_expanded, d_bw_expanded, d_is_pivot, d_locks);
		CUDA_SAFE_CALL(cudaDeviceSynchronize());
	} while (has_pivot);
	CUDA_SAFE_CALL(cudaDeviceSynchronize());
	t.Stop();

	printf("Done\n");
	print_statistics(m, nnz, d_colors, d_is_trimmed, d_is_pivot, in_row_offsets, out_row_offsets);
	printf("\titerations = %d.\n", iter);
	printf("\truntime [%s] = %f ms.\n", SCC_VARIANT, t.Millisecs());
	CUDA_SAFE_CALL(cudaMemcpy(h_colors, d_colors, sizeof(unsigned) * m, cudaMemcpyDeviceToHost));
	CUDA_SAFE_CALL(cudaFree(d_in_row_offsets));
	CUDA_SAFE_CALL(cudaFree(d_in_column_indices));
	CUDA_SAFE_CALL(cudaFree(d_out_row_offsets));
	CUDA_SAFE_CALL(cudaFree(d_out_column_indices));
	CUDA_SAFE_CALL(cudaFree(d_colors));
	CUDA_SAFE_CALL(cudaFree(d_locks));
	CUDA_SAFE_CALL(cudaFree(d_mark));
	CUDA_SAFE_CALL(cudaFree(d_fw_visited));
	CUDA_SAFE_CALL(cudaFree(d_bw_visited));
	CUDA_SAFE_CALL(cudaFree(d_fw_expanded));
	CUDA_SAFE_CALL(cudaFree(d_bw_expanded));
	CUDA_SAFE_CALL(cudaFree(d_is_pivot));
	CUDA_SAFE_CALL(cudaFree(d_is_trimmed));
}

