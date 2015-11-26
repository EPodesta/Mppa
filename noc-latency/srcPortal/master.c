#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <sched.h>
#include <unistd.h>

#include "interface_mppa.h"
#include "common.h"

#define ARGC_SLAVE 4

void 
spawn_slaves(const char slave_bin_name[], int nb_clusters, int nb_threads) 
{
	int i;
	int cluster_id;
	int pid;

	// Prepare arguments to send to slaves
	char **argv_slave = (char**) malloc(sizeof (char*) * ARGC_SLAVE);
	for (i = 0; i < ARGC_SLAVE - 1; i++)
		argv_slave[i] = (char*) malloc (sizeof (char) * 10);

	sprintf(argv_slave[0], "%d", nb_clusters);
	sprintf(argv_slave[1], "%d", nb_threads);
	argv_slave[3] = NULL;

	// Spawn slave processes
	for (cluster_id = 0; cluster_id < nb_clusters; cluster_id++) {
		sprintf(argv_slave[2], "%d", cluster_id);
		pid = mppa_spawn(cluster_id, NULL, slave_bin_name, (const char **)argv_slave, NULL);
		assert(pid >= 0);
		LOG("Spawned Cluster %d\n", cluster_id);
	}

	// Free arguments
	for (i = 0; i < ARGC_SLAVE; i++)
		free(argv_slave[i]);
	free(argv_slave);
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

	nb_clusters = atoi(argv[1]);

	int *comm_buffer = (int*) malloc(sizeof(int) * nb_clusters);
  	assert(comm_buffer != NULL);
	for(i = 0; i < nb_clusters; i++)
		comm_buffer[i] = -1;


	spawn_slaves("slave", nb_clusters, 1);
	barrier_t *global_barrier = mppa_create_master_barrier(BARRIER_SYNC_MASTER, BARRIER_SYNC_SLAVE, nb_clusters);

	int number_dmas = nb_clusters < 4 ? nb_clusters : 4;
	portal_t **read_portals = (portal_t **) malloc (sizeof(portal_t *) * number_dmas);

	// Each DMA will receive at least one message
	int nb_msgs_per_dma[4] = {1, 1, 1, 1};

	// Adjust the number of messages according to the number of clusters
	if (nb_clusters > 4) {
		int remaining_messages = nb_clusters - 4;
		while (remaining_messages > 0) {
			for (i = 0; i < number_dmas && remaining_messages > 0; i++) {
				nb_msgs_per_dma[i]++;
				remaining_messages--;
			}
		}
	}

	for (i = 0; i < number_dmas; i++) {
		sprintf(path, "/mppa/portal/%d:3", 128 + i);
		read_portals[i] = mppa_create_read_portal(path, comm_buffer, MAX_BUFFER_SIZE * nb_clusters, nb_msgs_per_dma[i], NULL);
	}


	// Initialize communication portals to send messages to clusters (one portal per cluster)
	portal_t **write_portals = (portal_t **) malloc (sizeof(portal_t *) * nb_clusters);
	for (i = 0; i < nb_clusters; i++) {
		sprintf(path, "/mppa/portal/%d:%d", i, 4 + i);
		write_portals[i] = mppa_create_write_portal(path, comm_buffer, MAX_BUFFER_SIZE, i);
	}
	// ----------- MASTER -> SLAVE ---------------	
	mppa_barrier_wait(global_barrier);
	// post asynchronous writes
	for (j = 0; j < nb_clusters; j++)
		mppa_async_write_portal(write_portals[j], comm_buffer, sizeof(int), 0);
	// block until all asynchronous writes have finished
	printf("MasterBlockedTillWrite!\n");
	for (j = 0; j < nb_clusters; j++)
		//printf("MasterWrote!\n");
		//sleep(5);
		mppa_async_write_wait_portal(write_portals[j]);

	printf("MasterWroteEveryThing!\n");
	// ----------- SLAVE -> MASTER ---------------	
   	mppa_barrier_wait(global_barrier);

	// Block until receive the asynchronous write FROM ALL CLUSTERS and prepare for next asynchronous writes
	// This is possible because we set the trigger = nb_clusters, so the IO waits for nb_cluster messages
	// mppa_async_read_wait_portal(read_portal);
	printf("MasterWaitAllClusters\n");
	for (j = 0; j < number_dmas; j++)
		mppa_async_read_wait_portal(read_portals[j]);
	printf("MasterWaitedAllClusters\n");
	for (i = 0; i < nb_clusters; ++i) {
		printf("Comm_bufferMaster:%d\n", comm_buffer[i]);
	}




	// Wait for all slave processes to finish
	for (pid = 0; pid < nb_clusters; pid++) {
		status = 0;
		if ((status = mppa_waitpid(pid, &status, 0)) < 0) {
		  printf("[I/O] Waitpid on cluster %d failed.\n", pid);
		  mppa_exit(status);
		}
	}

  	mppa_close_barrier(global_barrier);

	// mppa_close_portal(read_portal);
	for (i = 0; i < number_dmas; i++)
		mppa_close_portal(read_portals[i]);

	for (i = 0; i < nb_clusters; i++)
		mppa_close_portal(write_portals[i]);

	mppa_exit(0);

	return 0;
}
