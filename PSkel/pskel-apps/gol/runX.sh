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

for dh in 2500 1000 500 250; do
#for dh in 20000 19000 17000 15000 12500 10000 7500 5000 3000 1000 500 250; do
#for dh in 1000 2000 4000 5000 6000 8000 10000 12000 14000 14500; do
printf "tilingTimeX2[$dh] = ["
for (( i=1; i<=$rep; i++ )); do
./gol $width $height $iterations $modeGPUTile $gpuBlocks $nThreads $dh 100
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

