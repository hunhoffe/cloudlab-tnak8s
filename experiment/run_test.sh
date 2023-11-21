#!/bin/bash

INTRANODE_MODE="intranode"
INTERNODE_MODE="internode"
USAGE_STR="<$INTRANODE_MODE|$INTERNODE_MODE> <num_pairs>"
NUM_ARGS=2
SCRIPT_NAME=0
ARG_NUM_MODE=1
ARG_NUM_PAIRS=2

MYDIR="$(dirname "$(realpath "$0")")"
SERVERSPEC_FILE="$MYDIR/serverspec.yml"
CLIENTSPEC_FILE="$MYDIR/clientspec.yml"
TNA_NAMESPACE="tna-test"

################# Argument parsing #######################

# Check the min number of arguments
if [ $# != $NUM_ARGS ]; then
    echo "***Error: Expected $NUM_ARGS arguments."
    echo "$0: $USAGE_STR"
    exit -1
fi

mode=${!ARG_NUM_MODE}
npairs=${!ARG_NUM_PAIRS}

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

# Check number of pairs is valid
if [ "${!ARG_NUM_PAIRS}" -eq "${!ARG_NUM_PAIRS}" ] 2>/dev/null
then
    :
else
    echo "ERROR: first parameter must be an integer."
    echo $USAGE
    exit 1
fi

if [ ${!ARG_NUM_PAIRS} -lt 1 ] ; then
    echo "***Error: Pairs to small, should be  >= 1 but is ${!ARG_NUM_PAIRS}"
    echo "$0: $USAGE_STR"
    exit -1
else
    echo "==== Running $npairs pair(s) of pods"
fi

############### Parse k8s nodes #########################

# use node 2
serverNode=$(kubectl get no -o name | sed -n '2p' | cut -c6-)
if [ $mode == $INTRANODE_MODE ] ; then
    clientNode=$serverNode
else
    # use node 3
    clientNode=$(kubectl get no -o name | sed -n '3p' | cut -c6-)
fi
echo "==== Using node $serverNode for servers"
echo "==== Using node $clientNode for clients"

############### Set up files ############################
ymlDir=$(mktemp -d)
echo "==== Using temporary directory $ymlDir"

for ((i=1; i<=$npairs; i++)); do
    serverFile=$ymlDir/server$i.yml
    cp $SERVERSPEC_FILE $serverFile
    escapedServerNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$serverNode")
    sed -i "s/REPLACE_ME_WITH_NODE/$escapedServerNode/g" $serverFile
    sed -i "s/REPLACE_ME_WITH_SERVER_NUM/$i/g" $serverFile
    sed -i "s/REPLACE_ME_WITH_NAMESPACE/$TNA_NAMESPACE/g" $serverFile
    echo "==== Created server file: $serverFile"
    cat $serverFile
    echo ""

    clientFile=$ymlDir/client$i.yml
    cp $CLIENTSPEC_FILE $clientFile
    escapedClientNode=$(sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//' <<<"$clientNode")
    sed -i "s/REPLACE_ME_WITH_NODE/$escapedClientNode/g" $clientFile
    sed -i "s/REPLACE_ME_WITH_CLIENT_NUM/$i/g" $clientFile
    sed -i "s/REPLACE_ME_WITH_NAMESPACE/$TNA_NAMESPACE/g" $clientFile
    echo "==== Created client file: $clientFile"
    cat $clientFile
    echo ""
done

################ Set up namespace #######################
printf "==== Deleting and creating namespace $TNA_NAMESPACE...\n"
kubectl delete namespace $TNA_NAMESPACE > /dev/null 2>&1
kubectl create namespace $TNA_NAMESPACE
echo "Done!"

############### Start Server(s) #########################
for ((i=1; i<=$npairs; i++)); do
    kubectl apply -f $ymlDir/server$i.yml
done

echo "==== Waiting for server pods to have status of 'Running': "
NUM_NOT_RUNNING=$(kubectl get pods -n $TNA_NAMESPACE | grep " Running" | wc -l)
NUM_NOT_RUNNING=$((npairs-NUM_NOT_RUNNING))
while [ "$NUM_NOT_RUNNING" -ne 0 ]
do
    sleep 1
    printf "."
    NUM_NOT_RUNNING=$(kubectl get pods -n $TNA_NAMESPACE | grep " Running" | wc -l)
    NUM_NOT_RUNNING=$((NUM_PODS-NUM_NOT_RUNNING))
done
echo ""
echo "==== Server pods running! Waiting an extra 5 seconds before starting clients..."
sleep 5

############### Start Clients ############################
for ((i=1; i<=$npairs; i++)); do
    # Get server ip (we had to wait for the server to start running to get this)
    server_ip=$(kubectl get pod server-$i -n $TNA_NAMESPACE --template '{{.status.podIP}}')
    echo "==== server-$i ip is: $server_ip"
    sed -i "s/REPLACE_ME_WITH_SERVER_IP/$server_ip/g" $ymlDir/client$i.yml
    cat $ymlDir/client$i.yml
    kubectl apply -f $ymlDir/client$i.yml
done

############### Cleanup #################################
echo "==== Cleanup: deleting directory and contents of $ymlDir"
rm -rf $ymlDir
echo "==== Deleting tna-test namespace"
#kubectl delete namespace $TNA_NAMESPACE
