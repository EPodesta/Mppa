#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <sched.h>
#include <unistd.h>

#include "interface_mppa.h"
#include "common.h"

#define ARGC_SLAVE 4

void 
spawn_slaves(const char slave_bin_name[], int nb_threads) 
{
	int i;
	int cluster_id;
	int pid;
	char arg0[4];
	char* args[2];
	// Spawn slave processes
	for (cluster_id = 0; cluster_id < 16; cluster_id++) {
		sprintf(arg0, "%d", i);
		args[0] = arg0;
		pid = mppa_spawn(cluster_id, NULL, slave_bin_name, (const char**)args, NULL);
		assert(pid >= 0);
	}

}

int
main(int argc, char **argv) 
{
	int status;
	int pid;
	int i, j;
	int nb_clusters;
	char path[256];
	uint64_t start_time, exec_time;

	// Spawn slave processes
	spawn_slaves("slave", 1);
	nb_clusters = 16;
	// Initialize global barrier
	barrier_t *global_barrier = mppa_create_master_barrier(BARRIER_SYNC_MASTER, BARRIER_SYNC_SLAVE, nb_clusters);

	for(i = 0; i < 2; i++) {
		printf("MestreGotIn:%d\n", i);
		mppa_barrier_wait(global_barrier);
		printf("MestreGotOut:%d\n", i);
	}
	int nb_exec;
	
	// Wait for all slave processes to finish
	printf("MestreEspera\n");
	for (pid = 0; pid < nb_clusters; pid++) {
		status = 0;
		printf("Pid:%d\n", pid);
		if ((status = mppa_waitpid(pid, &status, 0)) < 0) {
		  printf("[I/O] Waitpid on cluster %d failed.\n", pid);
		  mppa_exit(status);
		}
	}
	printf("MestreTerminouDeEsperar\n");

	mppa_close_barrier(global_barrier);


	mppa_exit(0);

	return 0;
}
