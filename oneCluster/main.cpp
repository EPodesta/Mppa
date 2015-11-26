#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <mppaipc.h>
#include <mppa/osconfig.h>
int main(int argc, char **argv){
	char *args[1];
	args[0] = NULL;
	int pid = mppa_spawn(0, NULL, "slave", (const char**)args, NULL);
	mppa_waitpid(pid, NULL, 0);
	return 0;
}
