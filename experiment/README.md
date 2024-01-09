# Pod-to-Pod Networking Test

On each node, first run the tuning script:
```
cd /local/repository/tuning-scripts
sudo ./set_cpus.sh 16
```
Where here ```16``` is the number of cores (not hyperthreads!)

To get usage information, run:
```bash
./run_test.sh
```

Generally, in intranode tests, all pods are run on node2.
In internode tests, servers run on node2 and clients run on node3.

Some commands of interest are:
```
./run_test.sh intranode lat 1 lat-out
./run_test.sh intranode tput 1 tput-out
```

If you run the TNA controller on node2, the tests should run successfully.
