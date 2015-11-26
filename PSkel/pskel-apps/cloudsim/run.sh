width=30000
height=30000
iterations=100
nThreads=24
gpuBlocks=16
modeSeq=0
modeCPU=1
modeGPU=2
modeGPUTile=3
modeGPUGen=4
modeGPUAdHoc=5
rep=3

printf "
import matplotlib.pyplot as plt
import numpy as np
"

printf "geneticTime = ["
for (( i=1; i<=$rep; i++ )); do
./cloudsim $width $height $iterations 20 -3 5.0 700.0 0.001 $modeGPUGen $gpuBlocks $nThreads 0 0
if [ $i -lt $rep ]; then
printf ","
fi
done
printf "]\n"

printf "gpuBestTime = ["
for (( i=1; i<=$rep; i++ )); do
./cloudsim $width $height $iterations 20 -3 5.0 700.0 0.001 $modeGPUTile $gpuBlocks $nThreads 20410 100
if [ $i -lt $rep ]; then
printf ","
fi
done
printf "]\n"

printf "cpuTime = ["
for (( i=1; i<=$rep; i++ )); do
./cloudsim $width $height $iterations 20 -3 5.0 700.0 0.001 $modeCPU $gpuBlocks $nThreads 0 0
if [ $i -lt $rep ]; then
printf ","
fi
done
printf "]\n"

printf "tilingTimeX1 = {}\n"
for dt in 100 75 50 25 10 5 2 1; do
#for dt in 300 250 200 150 100 50 10 5 2 1; do
#for dt in 1 2 5 10 50 100 150 200 250 300; do
printf "tilingTimeX1[$dt] = ["
for (( i=1; i<=$rep; i++ )); do
./cloudsim $width $height $iterations 20 -3 5.0 700.0 0.001 $modeGPUTile $gpuBlocks $nThreads 20410 $dt
if [ $i -lt $rep ]; then
printf ","
fi
done
printf "]\n"
done

printf "tilingTimeX2 = {}\n"
for dh in 20400 20000 15000 10000 5000 2500 1000 500 250; do
#for dh in 20000 19000 17000 15000 12500 10000 7500 5000 3000 1000 500 250; do
#for dh in 1000 2000 4000 5000 6000 8000 10000 12000 14000 14500; do
printf "tilingTimeX2[$dh] = ["
for (( i=1; i<=$rep; i++ )); do
./cloudsim $width $height $iterations 20 -3 5.0 700.0 0.001 $modeGPUTile $gpuBlocks $nThreads $dh 100
if [ $i -lt $rep ]; then
printf ","
fi
done
printf "]\n"
done


printf "
plt.plot(tilingTime.keys(), [np.mean(tilingTime[key]) for key in tilingTime.keys()])
plt.plot(tilingTime.keys(), [np.mean(cpuTime)]*len(tilingTime.keys()))
plt.plot(tilingTime.keys(), [np.mean(geneticTime)]*len(tilingTime.keys()))
plt.show()
"

