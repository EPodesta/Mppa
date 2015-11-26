#!/bin/bash

make clean &> /dev/null
make all &> /dev/null

printf "Running benchmark with PORTAL communication...\n"
for i in 1 2 4 8 16; do
	printf "\t Number of clusters = $i\n"
	./run.sh $i
	mv result/data.csv result/portal-1-$i.csv
done

