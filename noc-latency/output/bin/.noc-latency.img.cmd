cmd_output/bin/noc-latency.img := pushd output/build > /dev/null; /usr/local/k1tools/bin/k1-create-multibinary  --clusters slave  --clusters-names slave       --boot master  -T noc-latency.img -f  ; popd > /dev/null ; mv output/build/noc-latency.img output/bin/noc-latency.img