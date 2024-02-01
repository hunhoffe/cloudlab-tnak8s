#!/bin/bash

IMAGE="hunhoffe/ubuntu-netperf"

INTRANODE_MODE="intranode"
INTERNODE_MODE="internode"

USAGE_STR="<$INTRANODE_MODE|$INTERNODE_MODE>"
NUM_ARGS=1
SCRIPT_NAME=0
ARG_NUM_MODE=1

MYDIR="$(dirname "$(realpath "$0")")"
PODSPEC_FILE="$MYDIR/podspec.yml"
TNA_NAMESPACE="tna-test"

# 60 seconds
WAIT_IN_NANOSECONDS=60000000000

SERVER_CMD="netserver "\
"-D "\
"-L \$MY_IP,4"

CLIENT_CMD="netperf "\
"-t TCP_RR "\
"-H REPLACE_ME_WITH_SERVER_IP,4 "\
"-l 5 "\
"-L \$MY_IP,4 "\
"-D 1 "\
"; echo \\\"NETPERF_SETUP_DONE\\\"; sleep infinity"

################# Argument parsing #######################

# Check the min number of arguments
if [ $# != $NUM_ARGS ]; then
    echo "***Error: Expected $NUM_ARGS arguments."
    echo "$0: $USAGE_STR"
    exit -1
fi

mode=${!ARG_NUM_MODE}

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

############### Parse k8s nodes #########################
serverNode=$(kubectl get no -o name | sed -n '2p' | cut -c6-)
if [ $mode == $INTRANODE_MODE ] ; then
    # use node 2
    clientNode=$serverNode
else
    # use node 3
    clientNode=$(kubectl get no -o name | sed -n '3p' | cut -c6-)
fi
echo "==== Using node $serverNode for server(s), using node $clientNode for client(s)"

############### Discern which number pair this is ###############33
num_pairs_already_running=$(kubectl get pods -n $TNA_NAMESPACE | grep -i server | wc -l)
echo "==== Detected $num_pairs_already_running pairs already running."
pair_num=$((num_pairs_already_running + 1))
echo "==== Calling this pair $pair_num"

############### Set up files ############################
serverFile=$MYDIR/server$pair_num.yml
cp $PODSPEC_FILE $serverFile
escapedServerNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$serverNode")
sed -i "s/REPLACE_ME_WITH_NODE/$escapedServerNode/g" $serverFile
sed -i "s/REPLACE_ME_WITH_NAME/server$pair_num/g" $serverFile
sed -i "s/REPLACE_ME_WITH_NS/$TNA_NAMESPACE/g" $serverFile
sanitizedCmd=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$SERVER_CMD")
sed -i "s/REPLACE_ME_WITH_CMD/$sanitizedCmd/g" $serverFile
sanitizedImage=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$IMAGE")
sed -i "s/REPLACE_ME_WITH_IMAGE/$sanitizedImage/g" $serverFile
echo "==== Created server file: $serverFile"

clientFile=$MYDIR/client$pair_num.yml
cp $PODSPEC_FILE $clientFile
escapedClientNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$clientNode")
sed -i "s/REPLACE_ME_WITH_NODE/$escapedClientNode/g" $clientFile
sed -i "s/REPLACE_ME_WITH_NAME/client$pair_num/g" $clientFile
sed -i "s/REPLACE_ME_WITH_NS/$TNA_NAMESPACE/g" $clientFile
sanitizedCmd=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$CLIENT_CMD")
sed -i "s/REPLACE_ME_WITH_CMD/$sanitizedCmd/g" $clientFile
sanitizedImage=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$IMAGE")
sed -i "s/REPLACE_ME_WITH_IMAGE/$sanitizedImage/g" $clientFile
echo "==== Created client file: $clientFile"

################ Set up namespace #######################
printf "==== Deleting and creating namespace $TNA_NAMESPACE...\n"
kubectl create namespace $TNA_NAMESPACE 

############### Start Server #########################
echo "==== Starting server..."
kubectl apply -f $serverFile

echo "==== Waiting for server pod to have status of 'Running': "
SERVER_STATUS=$(kubectl get pod server$pair_num -n $TNA_NAMESPACE --template '{{.status.phase}}')
while [ "$SERVER_STATUS" != "Running" ]
do
    sleep 1
    printf "."
    SERVER_STATUS=$(kubectl get pod server$pair_num -n $TNA_NAMESPACE --template '{{.status.phase}}')
done
echo ""
echo "==== Server pod running! Waiting an extra 30 seconds before starting client..."
sleep 30

############### Start Clients ############################
echo "==== Starting client..."
# Get server ip (we had to wait for the server to start running to get this)
serverIp=$(kubectl get pod server$pair_num -n $TNA_NAMESPACE --template '{{.status.podIP}}')
sed -i "s/REPLACE_ME_WITH_SERVER_IP/$serverIp/g" $clientFile
kubectl apply -f $clientFile

echo "==== Waiting for client pod to have status of 'Running': "
CLIENT_STATUS=$(kubectl get pod client$pair_num -n $TNA_NAMESPACE --template '{{.status.phase}}')
while [ "$CLIENT_STATUS" != "Running" ]
do
    sleep 1
    printf "."
    CLIENT_STATUS=$(kubectl get pod client$pair_num -n $TNA_NAMESPACE --template '{{.status.phase}}')
done
echo ""
echo "==== Client pod running!"

echo "=== Waiting for netperf warm up to run in client"
clientDone=0
while [ "$clientDone" -ne 1 ]
do
    if kubectl logs -n $TNA_NAMESPACE client$pair_num | grep "NETPERF_SETUP_DONE"; then
        clientDone=1
        echo "==== Client ready! ======================"
    fi
    sleep 1
done
