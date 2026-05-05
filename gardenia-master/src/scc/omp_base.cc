// Copyright 2016, National University of Defense Technology
// Authors: Xuhao Chen <cxh@illinois.edu>
#include "scc.h"
#include <omp.h>
#include <stack>
#include <vector>
#include <utility>
#include <algorithm>
#include "timer.h"
#define SCC_VARIANT "openmp"

using namespace std;

void print_statistics(int m, int nnz, int *scc_root, int *in_row_offsets, int *out_row_offsets) {
	int *scc_sizes = (int *)calloc(m, sizeof(int));
	for (int i = 0; i < m; i++) {
		if (scc_root[i] >= 0 && scc_root[i] < m) {
			scc_sizes[scc_root[i]]++;
		}
	}

	int total_scc = 0;
	int num_trivial_scc = 0;
	int num_nontrivial_scc = 0;
	int biggest_scc_size = 0;

	for (int i = 0; i < m; i++) {
		if (scc_sizes[i] > 0) {
			total_scc++;
			if (scc_sizes[i] == 1) {
				num_trivial_scc++;
			} else {
				num_nontrivial_scc++;
			}
			if (scc_sizes[i] > biggest_scc_size) {
				biggest_scc_size = scc_sizes[i];
			}
		}
	}

	printf("\tnum_trivial_scc=%d, num_nontrivial=%d, total_num_scc=%d, biggest_scc_size=%d\n", 
		num_trivial_scc, num_nontrivial_scc, total_scc, biggest_scc_size);

	free(scc_sizes);
}

void SCCSolver(int m, int nnz, int *in_row_offsets, int *in_column_indices, int *out_row_offsets, int *out_column_indices, int *scc_root) {
	printf("Launching SCC solver (Kosaraju algorithm)...\n");

	Timer t;
	t.Start();

	char *visited = (char *)malloc(m * sizeof(char));
	for (int i = 0; i < m; i++) {
		visited[i] = 0;
		scc_root[i] = -1;
	}

	vector<int> order;
	order.reserve(m);

	for (int i = 0; i < m; i++) {
		if (visited[i] == 0) {
			stack<pair<int, int> > st;
			st.push(make_pair(i, out_row_offsets[i]));
			
			while (!st.empty()) {
				pair<int, int> top_pair = st.top();
				st.pop();
				int u = top_pair.first;
				int idx = top_pair.second;
				
				if (idx == out_row_offsets[u]) {
					if (visited[u] == 1) continue;
					if (visited[u] == 2) continue;
					
					visited[u] = 1;
					st.push(make_pair(u, -1));
					
					for (int j = out_row_offsets[u+1] - 1; j >= out_row_offsets[u]; j--) {
						int w = out_column_indices[j];
						if (visited[w] == 0) {
							st.push(make_pair(w, out_row_offsets[w]));
						}
					}
				} else {
					visited[u] = 2;
					order.push_back(u);
				}
			}
		}
	}

	for (int i = 0; i < m; i++) {
		visited[i] = 0;
	}

	reverse(order.begin(), order.end());

	for (size_t idx = 0; idx < order.size(); idx++) {
		int start = order[idx];
		if (visited[start] == 0) {
			stack<int> st;
			st.push(start);
			
			while (!st.empty()) {
				int u = st.top();
				st.pop();
				
				if (visited[u] == 1) continue;
				visited[u] = 1;
				scc_root[u] = start;
				
				for (int j = in_row_offsets[u]; j < in_row_offsets[u+1]; j++) {
					int w = in_column_indices[j];
					if (visited[w] == 0) {
						st.push(w);
					}
				}
			}
		}
	}

	t.Stop();
	print_statistics(m, nnz, scc_root, in_row_offsets, out_row_offsets);
	printf("\titerations = 2.\n");
	printf("\truntime [%s] = %f ms.\n", SCC_VARIANT, t.Millisecs());
	
	free(visited);
	return;
}