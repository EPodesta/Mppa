#include "common.h"
#include <stdio.h>

void
init_buffer(char *buffer, int size)
{	
	int i;
	for(i = 0; i < size; i++)
		buffer[i] = -1;
}

void
fill_buffer(char *buffer, int size, int cluster_id) 
{
	int i;
	for (i=0; i < size; i++)
		buffer[i] = cluster_id + 1;
}

void
print_buffer(char *buffer, int size) 
{
	int i;
	LOG("Master buffer:\n");
	for (i=0; i < size; i++)
		LOG("%d ", buffer[i]);
	LOG("\n");
}
