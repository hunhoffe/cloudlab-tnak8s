#!/bin/bash

count=$1 #number of cpus
begin=0
i=0

if1_name=ens1f1np1
if2_name=ens1f0np0

echo "Enabling HT"
./enable_ht

echo "Enable CPUs"
./enable_cpus

# echo "Enabling CPUs"
# while [[ $i -lt $count ]]
# do
#     #sudo ip route del 10.10.$((i + begin)).0/24 via 10.10.2.1
#     echo "sudo echo 1 > /sys/devices/system/cpu/cpu$((i + begin))/online"
# 	((i = i + 1)) 
# done

echo "Configuring HW queues"
ethtool -L ens1f1np1 combined 32
ethtool -L ens1f0np0 combined 32

echo "Setting IRQ affinity"
i=1
cpu_list=0
while [[ $i -lt 32 ]]
do
    cpu_list=$cpu_list,$i
	((i = i + 1)) 
done

./set_irq_affinity_cpulist.sh $cpu_list ens1f0np0
./set_irq_affinity_cpulist.sh $cpu_list ens1f1np1
