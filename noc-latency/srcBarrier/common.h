#define USE_CHANNEL 1

#define KB 1024
#define MB 1024 * KB

#define MAX_BUFFER_SIZE 1 * MB + MB / 2
#define NB_EXEC 30

#ifdef DEBUG
#define LOG(...) printf(__VA_ARGS__); fflush(stdout)
#else
#define LOG(...) 
#endif //DEBUG

typedef struct {
	int cluster_id;
} rqueue_msg_t;

void init_buffer(char *buffer, int size);
void fill_buffer(char *buffer, int size, int cluster_id);
void print_buffer(char *buffer, int size);
