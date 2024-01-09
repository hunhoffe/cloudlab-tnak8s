#!/bin/bash

count=$1 #number of cpus
begin=1
i=0

IFNAME=myiface

echo "Killing irqbalance"
killall irqbalance

echo "Disabling HT"
./disable_ht

echo "Disabling CPUs"
./disable_cpus_no_ht

echo "Enabling CPUs"
while [[ $((i + begin)) -lt $count ]]
do
    #sudo ip route del 10.10.$((i + begin)).0/24 via 10.10.2.1
    echo 1 > /sys/devices/system/cpu/cpu$((i + begin))/online
    ((i = i + 1))
done

echo "Configuring HW queues"
ethtool -L $IFNAME combined $count

echo "Setting IRQ affinity"
i=1
cpu_list=0
while [[ $i -lt $count ]]
do
    cpu_list=$cpu_list,$i
	((i = i + 1)) 
done

./set_irq_affinity_cpulist.sh $cpu_list $IFNAME
