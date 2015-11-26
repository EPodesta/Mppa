#ifndef __INTERFACE_MPPA_H
#define __INTERFACE_MPPA_H

#include <mppaipc.h>
#include <inttypes.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/*
 * GLOBAL CONSTANTS
 */

#define BARRIER_SYNC_MASTER "/mppa/sync/128:1"
#define BARRIER_SYNC_SLAVE "/mppa/sync/[0..15]:2"

#define TRUE 1
#define FALSE 0

#define IO_NODE_RANK 128
#define MAX_CLUSTERS 16
#define MAX_THREADS_PER_CLUSTER 16
#define MPPA_FREQUENCY 400


/*
 * INTERNAL STRUCTURES
 */

typedef enum {
	BARRIER_MASTER,
	BARRIER_SLAVE
} barrier_mode_t;

typedef struct {
	int file_descriptor;
	mppa_aiocb_t aiocb;
} portal_t;

typedef struct {
	int file_descriptor;
} channel_t;

typedef struct {
	int sync_fd_master;
	int sync_fd_slave;
	barrier_mode_t mode;
	int nb_clusters;
} barrier_t;

typedef struct {
	int file_descriptor;
} rqueue_t;

/*
 * FUNCTIONS
 */

void set_path_name(char *path, char *template_path, int rx, int tag);

portal_t *mppa_create_read_portal (char *path, void* buffer, unsigned long buffer_size, int trigger, void (*function)(mppa_sigval_t));
portal_t *mppa_create_write_portal (char *path, void* buffer, unsigned long buffer_size, int receiver_rank);
void mppa_write_portal (portal_t *portal, void *buffer, int buffer_size, int offset);
void mppa_async_write_portal (portal_t *portal, void *buffer, int buffer_size, int offset);
void mppa_async_write_wait_portal(portal_t *portal);
void mppa_async_read_wait_portal(portal_t *portal);

void mppa_close_portal (portal_t *portal);

channel_t *mppa_create_read_channel (char *path);
channel_t *mppa_create_write_channel (char *path);
void mppa_write_channel (channel_t *channel, void *buffer, int buffer_size);
void mppa_read_channel (channel_t *channel, void *buffer, int buffer_size);
void mppa_close_channel (channel_t *channel);

barrier_t *mppa_create_master_barrier (char *path_master, char *path_slave, int clusters);
barrier_t *mppa_create_slave_barrier (char *path_master, char *path_slave);
void mppa_barrier_wait (barrier_t *barrier);
void mppa_close_barrier (barrier_t *barrier);

rqueue_t *mppa_create_read_rqueue (int message_size, int rx_id, int rx_tag, char *tx_ids, int tx_tag);
void mppa_init_read_rqueue(rqueue_t *rqueue, int credit);
rqueue_t *mppa_create_write_rqueue (int message_size, int rx_id, int rx_tag, char *tx_ids, int tx_tag);
void mppa_read_rqueue (rqueue_t *rqueue, void *buffer, int buffer_size);
void mppa_write_rqueue (rqueue_t *rqueue, void *buffer, int buffer_size);
void mppa_close_rqueue(rqueue_t *rqueue);

void mppa_init_time(void);
inline uint64_t mppa_get_time(void);
inline uint64_t mppa_diff_time(uint64_t t1, uint64_t t2);


#endif // __INTERFACE_MPPA_H