#!/bin/bash

#IMAGE="hunhoffe/pkb-netperf"
IMAGE="hunhoffe/ubuntu-netperf"

INTRANODE_MODE="intranode"
INTERNODE_MODE="internode"
TPUT_TEST="tput"
LAT_TEST="lat"
USAGE_STR="<$INTRANODE_MODE|$INTERNODE_MODE> <$TPUT_TEST|$LAT_TEST> <num_pairs> <outdir>"
NUM_ARGS=4
SCRIPT_NAME=0
ARG_NUM_MODE=1
ARG_NUM_TEST=2
ARG_NUM_PAIRS=3
ARG_NUM_OUTDIR=4

MYDIR="$(dirname "$(realpath "$0")")"
PODSPEC_FILE="$MYDIR/podspec.yml"
TNA_NAMESPACE="tna-test"

#SERVER_CMD="/opt/pkb/netperf-netperf-2.7.0/src/netserver "\
#"-D "\
#"-p 20000 "\
#"-L \$MY_IP,4"

SERVER_CMD="netserver "\
"-D "\
"-L \$MY_IP,4"

#LAT_CMD="/opt/pkb/netperf-netperf-2.7.0/src/netperf "\
#"-p 20000 "\
#"-j "\
#"-v2 "\
#"-t TCP_RR "\
#"-H REPLACE_ME_WITH_SERVER_IP,4 "\
#"-l 60 "\
#"-L \$MY_IP,4 "\
#"-- "\
#"-P ,20001 "\
#"-o THROUGHPUT,THROUGHPUT_UNITS,P50_LATENCY,P90_LATENCY,P99_LATENCY,STDDEV_LATENCY,MIN_LATENCY,MAX_LATENCY,CONFIDENCE_ITERATION,THROUGHPUT_CONFID,LOCAL_TRANSPORT_RETRANS,REMOTE_TRANSPORT_RETRANS,TRANSPORT_MSS"

LAT_CMD="netperf "\
"-t TCP_RR "\
"-H REPLACE_ME_WITH_SERVER_IP,4 "\
"-l 60 "\
"-L \$MY_IP,4 "\
"-- "\
"-o P50_LATENCY,P90_LATENCY,P99_LATENCY,STDDEV_LATENCY,MIN_LATENCY,MAX_LATENCY,MEAN_LATENCY "\
"; echo NETPERF_DONE; sleep infinity"

# TODO: is -M and -m okay? Should be parsed from machine config, I think?
#TPUT_CMD="/opt/pkb/netperf-netperf-2.7.0/src/netperf "\
#"-p 20000 "\
#"-j "\
#"-t TCP_STREAM "\
#"-H REPLACE_ME_WITH_SERVER_IP,4 "\
#"-L \$MY_IP,4 "\
#"-l 60 "\
#"-- "\
#"-P ,20001 "\
#"-o THROUGHPUT,THROUGHPUT_UNITS,P50_LATENCY,P90_LATENCY,P99_LATENCY,STDDEV_LATENCY,MIN_LATENCY,MAX_LATENCY,CONFIDENCE_ITERATION,THROUGHPUT_CONFID,LOCAL_TRANSPORT_RETRANS,REMOTE_TRANSPORT_RETRANS,TRANSPORT_MSS "\
#"-m 131072 -M 131072 "\
#"; echo NETPERF_DONE; sleep infinity"

TPUT_CMD="netperf "\
"-t TCP_STREAM "\
"-H REPLACE_ME_WITH_SERVER_IP,4 "\
"-l 60 "\
"-L \$MY_IP,4 "\
"; echo NETPERF_DONE; sleep infinity"

################# Argument parsing #######################

# Check the min number of arguments
if [ $# != $NUM_ARGS ]; then
    echo "***Error: Expected $NUM_ARGS arguments."
    echo "$0: $USAGE_STR"
    exit -1
fi

mode=${!ARG_NUM_MODE}
netperfTest=${!ARG_NUM_TEST}
npairs=${!ARG_NUM_PAIRS}
outdir=${!ARG_NUM_OUTDIR}

# Check mode is either internode or intranode
if [ $mode == $INTRANODE_MODE ] ; then
    echo "==== Running intranode mode"
elif [ $mode == $INTERNODE_MODE ] ; then
    echo "==== Running internode mode"
else
    echo "***Error: Expected $INTRANODE_MODE or $INTERNODE_MODE for mode but is $mode"
    echo "$0: $USAGE_STR"
    exit -1
fi

# Check test is either throughput or latency
if [ $netperfTest == $TPUT_TEST ] ; then
    echo "==== Running throughput (TCP_STREAM) test"
elif [ $netperfTest == $LAT_TEST ] ; then
    echo "==== Running latency (TCP_RR) test"
else
    echo "***Error: Expected $TPUT_TEST or $LAT_TEST for test but is $netperfTest"
    echo "$0: $USAGE_STR"
    exit -1
fi

# Check number of pairs is valid
if [ "$npairs" -eq "$npairs" ] 2>/dev/null ; then
    :
else
    echo "ERROR: Number of pairs must be an integer but is \"$npairs\"."
    echo $USAGE
    exit 1
fi

if [ $npairs -lt 1 ] ; then
    echo "***Error: Pairs to small, should be  >= 1 but is $npairs"
    echo "$0: $USAGE_STR"
    exit -1
else
    echo "==== Running $npairs pair(s) of pods"
fi

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

############### Parse k8s nodes #########################

# use node 2
serverNode=$(kubectl get no -o name | sed -n '2p' | cut -c6-)
if [ $mode == $INTRANODE_MODE ] ; then
    clientNode=$serverNode
else
    # use node 3
    clientNode=$(kubectl get no -o name | sed -n '3p' | cut -c6-)
fi
echo "==== Using node $serverNode for server(s)"
echo "==== Using node $clientNode for client(s)"

############### Set up files ############################
for ((i=1; i<=$npairs; i++)); do
    serverFile=$outdir/server$i.yml
    cp $PODSPEC_FILE $serverFile
    escapedServerNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$serverNode")
    sed -i "s/REPLACE_ME_WITH_NODE/$escapedServerNode/g" $serverFile
    sed -i "s/REPLACE_ME_WITH_NAME/server$i/g" $serverFile
    sed -i "s/REPLACE_ME_WITH_NS/$TNA_NAMESPACE/g" $serverFile
    sanitizedCmd=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$SERVER_CMD")
    sed -i "s/REPLACE_ME_WITH_CMD/$sanitizedCmd/g" $serverFile
    sanitizedImage=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$IMAGE") 
    sed -i "s/REPLACE_ME_WITH_IMAGE/$sanitizedImage/g" $serverFile
 
    echo "==== Created server file: $serverFile"

    clientFile=$outdir/client$i.yml
    cp $PODSPEC_FILE $clientFile
    escapedClientNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$clientNode")
    sed -i "s/REPLACE_ME_WITH_NODE/$escapedClientNode/g" $clientFile
    sed -i "s/REPLACE_ME_WITH_NAME/client$i/g" $clientFile
    sed -i "s/REPLACE_ME_WITH_NS/$TNA_NAMESPACE/g" $clientFile
    if [ $netperfTest == $TPUT_TEST ] ; then
        sanitizedCmd=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$TPUT_CMD")
    else
        sanitizedCmd=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$LAT_CMD")
    fi
    sed -i "s/REPLACE_ME_WITH_CMD/$sanitizedCmd/g" $clientFile
    sanitizedImage=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$IMAGE") 
    sed -i "s/REPLACE_ME_WITH_IMAGE/$sanitizedImage/g" $clientFile

    echo "==== Created client file: $clientFile"
done

################ Set up namespace #######################
printf "==== Deleting and creating namespace $TNA_NAMESPACE...\n"
kubectl delete namespace $TNA_NAMESPACE > /dev/null 2>&1
kubectl create namespace $TNA_NAMESPACE
echo "Done!"

############### Start Server(s) #########################
echo "==== Starting server(s)..."
for ((i=1; i<=$npairs; i++)); do
    kubectl apply -f $outdir/server$i.yml
done

echo "==== Waiting for server pods to have status of 'Running': "
NUM_NOT_RUNNING=$(kubectl get pods -n $TNA_NAMESPACE | grep " Running" | wc -l)
NUM_NOT_RUNNING=$((npairs-NUM_NOT_RUNNING))
while [ "$NUM_NOT_RUNNING" -ne 0 ]
do
    sleep 1
    printf "."
    NUM_NOT_RUNNING=$(kubectl get pods -n $TNA_NAMESPACE | grep " Running" | wc -l)
    NUM_NOT_RUNNING=$((npairs-NUM_NOT_RUNNING))
done
echo ""
echo "==== Server pod(s) running! Waiting an extra 5 seconds before starting client(s)..."
sleep 5

############### Start Clients ############################
echo "==== Starting client(s)..."
for ((i=1; i<=$npairs; i++)); do
    # Get server ip (we had to wait for the server to start running to get this)
    serverIp=$(kubectl get pod server$i -n $TNA_NAMESPACE --template '{{.status.podIP}}')
    sed -i "s/REPLACE_ME_WITH_SERVER_IP/$serverIp/g" $outdir/client$i.yml
    kubectl apply -f $outdir/client$i.yml
done

echo "=== Waiting for netperf to run"
for ((i = 1; i<=$npairs; i++)); do
    clientDone=0
    while [ "$clientDone" -ne 1 ]
    do
        if kubectl logs -n $TNA_NAMESPACE client$i | grep "NETPERF_DONE"; then
            clientDone=1
            kubectl logs -n $TNA_NAMESPACE client$i > $outdir/client$i.log
            kubectl logs -n $TNA_NAMESPACE server$i > $outdir/server$i.log
            echo "==== Client $i results start ======================"
            cat $outdir/client$i.log
            echo "==== Client $i results finish ====================="
            echo "==== Server $i output start ======================"
            cat $outdir/server$i.log
            echo "==== Server $i output finish ====================="
        fi
    sleep 1
    done
    echo "=== Logged results .log file(s) in $outdir"
done

############### Cleanup #################################
echo "==== Deleting tna-test namespace"
kubectl delete namespace $TNA_NAMESPACE
