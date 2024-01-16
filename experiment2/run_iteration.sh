#!/bin/bash

IMAGE="hunhoffe/ubuntu-netperf"

USAGE_STR="<outdir>"
NUM_ARGS=1
SCRIPT_NAME=0
ARG_NUM_OUTDIR=1

MYDIR="$(dirname "$(realpath "$0")")"
TNA_NAMESPACE="tna-test"

# 60 seconds
WAIT_IN_NANOSECONDS=10000000000

TEST_CMD="current_time=\$(date +%s%N) "\
"; target_time=REPLACE_ME_WITH_CLIENT_START "\
"; echo \\\"Current: \$current_time, Target: \$target_time\\\" > outfile.txt "\
"; while [[ current_time -lt target_time ]]; do current_time=\$(date +%s%N); done "\
"; netperf "\
"-t TCP_RR "\
"-H REPLACE_ME_WITH_SERVER_IP,4 "\
"-l 60 "\
"-L REPLACE_ME_WITH_CLIENT_IP,4 "\
"-D 1 "\
"-- "\
"-o P50_LATENCY,P90_LATENCY,P99_LATENCY,STDDEV_LATENCY,MIN_LATENCY,MAX_LATENCY,MEAN_LATENCY >> outfile.txt "\
"; echo TEST_DONE >> outfile.txt"

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

############### Parse number of pairs ####################
num_pairs=$(kubectl get pods -n $TNA_NAMESPACE -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep client | wc -l)
echo "==== Detected $num_pairs pairs of pods"

############### Decide what time the commands should all run #################
current_time=$(date +%s%N)
test_wait=$((WAIT_IN_NANOSECONDS * num_pairs))
test_start=$((current_time + test_wait))
echo "==== Waiting $test_wait nanoseconds... Current time is $current_time, clients will run netperf at $test_start"

############### Iterate over each pod, trigger pod to run netperf ############
client_pods=$(kubectl get pods -n $TNA_NAMESPACE -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep client)
for client_pod in $client_pods;
do
    # Construct server pod name and get IP addresses
    server_pod=$(echo $client_pod | sed -e 's/.\{6\}//')
    server_pod=server$server_pod
    echo "==== Setting pair ($client_pod, $server_pod) to run"
    server_ip=$(kubectl get pod $server_pod -n $TNA_NAMESPACE --template '{{.status.podIP}}')
    client_ip=$(kubectl get pod $client_pod -n $TNA_NAMESPACE --template '{{.status.podIP}}')
    echo "==== Updating command for $client_pod ($client_ip), using $server_pod IP ($server_ip) and start time ($test_start)"

    # Update command with start time and IPs
    client_cmd=$(echo "${TEST_CMD/REPLACE_ME_WITH_CLIENT_START/"$test_start"}")
    client_cmd=$(echo "${client_cmd/REPLACE_ME_WITH_SERVER_IP/"$server_ip"}")
    client_cmd=$(echo "${client_cmd/REPLACE_ME_WITH_CLIENT_IP/"$client_ip"}")
    echo "==== client command is: $client_cmd"

    # Run the command in the background and remember the pid
    kubectl exec client1 -n tna-test -- /bin/bash -c "current_time=$client_cmd" &
    pod_cmd_pid=$!
    echo "==== Pid of command is: $!"
done

# Wait for test to run
test_done=$((WAIT_IN_NANOSECONDS * 6)) # wait test duration aka 1 minute
test_done=$((test_start + test_done))

# Iterate over each pod and wait until done, then copy file to output director and delete pod file.
#kubectl cp tna-test/client1:netperf_out.txt mypod.txt -n tna-test
