#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "common.h"
#include "interface_mppa.h"


int main(int argc,char **argv) {
	char path[25];
	int i;

	// Global data
	int *comm_buffer = (int *) malloc(MAX_BUFFER_SIZE);
	assert(comm_buffer != NULL);

  	// Set initial parameters
	// int nb_clusters = atoi(argv[0]);
	// int nb_threads  = atoi(argv[1]);
	int cluster_id  = atoi(argv[2]);

	// Initialize communication portals
	// portal_t *write_portal = mppa_create_write_portal("/mppa/portal/128:3", comm_buffer, MAX_BUFFER_SIZE, 128);
	sprintf(path, "/mppa/portal/%d:3", 128 + (cluster_id % 4));
	portal_t *write_portal = mppa_create_write_portal(path, comm_buffer, MAX_BUFFER_SIZE, 128 + (cluster_id % 4));

	// Initialize communication portal to receive messages from IO-node
	sprintf(path, "/mppa/portal/%d:%d", cluster_id, 4 + cluster_id);
	portal_t *read_portal = mppa_create_read_portal(path, comm_buffer, MAX_BUFFER_SIZE, 1, NULL);
	



 		barrier_t *global_barrier = mppa_create_slave_barrier (BARRIER_SYNC_MASTER, BARRIER_SYNC_SLAVE);

		// ----------- MASTER -> SLAVE ---------------
		    mppa_barrier_wait(global_barrier);
			// Block until receive the asynchronous write and prepare for next asynchronous writes	
			printf("Slave:%dWaitingForMasterWrite\n", cluster_id);
			sleep(5);	
			mppa_async_read_wait_portal(read_portal);
			printf("Slave:%dWaited!\n", cluster_id);

			printf("Comm_bufferSlave:%d,%d\n", cluster_id, *comm_buffer);
			*comm_buffer += cluster_id;
		// ----------- SLAVE -> MASTER ---------------
			mppa_barrier_wait(global_barrier);
			// post asynchronous write
			printf("Slave:%dWrote!\n", cluster_id);
			mppa_async_write_portal(write_portal, comm_buffer, sizeof(int), cluster_id * MAX_BUFFER_SIZE);
			
			// wait for the end of the transfer
			mppa_async_write_wait_portal(write_portal);
			printf("Slave:%dEndedTransfer\n", cluster_id);

 	mppa_close_barrier(global_barrier);
	mppa_close_portal(write_portal);
	mppa_close_portal(read_portal);


	mppa_exit(0);

	return 0;
}
