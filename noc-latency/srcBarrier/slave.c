#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "common.h"
#include "interface_mppa.h"


int main(int argc,char **argv) {
	char path[25];
	int i;
	// Initialize global barrier
	barrier_t *global_barrier = mppa_create_slave_barrier (BARRIER_SYNC_MASTER, BARRIER_SYNC_SLAVE);
	int rank = atoi(argv[0]);
	for(i = 0; i < 2; i++){
		sleep(5);
		printf("SlaveArrivied:%d\n", i);
		mppa_barrier_wait(global_barrier);
		printf("SlaveGotOut:%d \n", i);
	}

	int nb_exec;

	mppa_close_barrier(global_barrier);

	mppa_exit(0);

	return 0;
}
