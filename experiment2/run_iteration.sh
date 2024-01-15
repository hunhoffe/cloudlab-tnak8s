#!/bin/bash

IMAGE="hunhoffe/ubuntu-netperf"

USAGE_STR="<outdir>"
NUM_ARGS=1
SCRIPT_NAME=0
ARG_NUM_OUTDIR=1

MYDIR="$(dirname "$(realpath "$0")")"
TNA_NAMESPACE="tna-test"

# 60 seconds
WAIT_IN_NANOSECONDS=60000000000

TEST_CMD="current_time=\$(date +%s%N) "\
"; target_time=REPLACE_ME_WITH_CLIENT_START "\
"; echo \\\"Current: \$current_time, Target: \$target_time\\\" "\
"; while [[ current_time -lt target_time ]]; do current_time=\$(date +%s%N); done "\
"; netperf "\
"-t TCP_RR "\
"-H REPLACE_ME_WITH_SERVER_IP,4 "\
"-l 60 "\
"-L \$MY_IP,4 "\
"-D 1 "\
"-- "\
"-o P50_LATENCY,P90_LATENCY,P99_LATENCY,STDDEV_LATENCY,MIN_LATENCY,MAX_LATENCY,MEAN_LATENCY "\
"; echo TEST_DONE"

################# Argument parsing #######################

# Check the min number of arguments
if [ $# != $NUM_ARGS ]; then
    echo "***Error: Expected $NUM_ARGS arguments."
    echo "$0: $USAGE_STR"
    exit -1
fi

outdir=${!ARG_NUM_OUTDIR}

# Check that output dir does not exist
if test -f $outdir; then
    echo "***Error: Output directory $outdir already exists, and is a file."
    echo "$0: $USAGE_STR"
    exit -1
fi
if test -d $outdir; then
    echo "***Error: Output directory $outdir already exists."
    echo "$0: $USAGE_STR"
    exit -1
fi

############### Create output directory ##################
mkdir -p $outdir
echo "==== Created output directory: $outdir"

############### Iterate over client pods #################
num_pairs=$(kubectl get pods -n tna-test -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep client | wc -l)
echo "==== Detected $num_pairs pairs of pods"

client_pods=$(kubectl get pods -n tna-test -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep client)
for client_pod in $client_pods;
do
    echo "==== FOUND CLIENT $client_pod"
    server_pod=$(echo $client_pod | sed -e 's/.\{6\}//')
    server_pod=server$server_pod
    echo "==== CONSTRUCTED SERVER $server_pod"
done
