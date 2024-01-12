#!/bin/bash

PAIRS=$1
echo "Running with $PAIRS pairs"

mkdir baseline-intranode-$PAIRS
mkdir baseline-internode-$PAIRS
mkdir tna-intranode-$PAIRS
mkdir tna-internode-$PAIRS

for i in $(seq 1 10);
do
    echo "==== Running iteration $i"

    # Run baseline tests: throughput
    #./run_test.sh intranode tput $PAIRS "baseline-intranode-tput$PAIRS/iteration$i"

    # Run baseline tests: latency
    ./run_test.sh intranode lat $PAIRS "baseline-intranode-$PAIRS/iteration$i"
    ./run_test.sh internode lat $PAIRS "baseline-internode-$PAIRS/iteration$i"

    echo "==== START TNA on both nodes and then type something to continue."
    read -p "Ready to continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

    # Run tna tests: throughput
    #./run_test.sh intranode tput $PAIRS "tna-intranode-tput$PAIRS/iteration$i"

    #echo "==== Start TNA on both nodes and then type something to continue."
    #read -p "Ready to continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

    # Run tna tests: latency
    ./run_test.sh intranode lat $PAIRS "tna-intranode-$PAIRS/iteration$i"

    echo "==== RESTART TNA on both nodes and then type something to continue."
    read -p "Ready to continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

    ./run_test.sh internode lat $PAIRS "tna-internode-$PAIRS/iteration$i"

    echo "==== QUIT TNA on both nodes and then type something to continue."
    read -p "Ready to continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1
done
echo "==== Finished running tests for $PAIRS pairs!"

