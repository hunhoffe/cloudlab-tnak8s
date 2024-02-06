# Instructions

## Configuration

Mitigations are already turned off, but we do want to tune.
For c6525-25g nodes, on each node configure the cores with:

```bash
cd /local/repository/tuning-scripts
```

```bash
sudo ./set_cpus.sh 16
```

Generalize this to the specific node by setting 16 to the number of cores (not hyperthreads).

## Build TNA

The dependencies are already configured on the image, so all you have to do is:
* Setup your github ssh key
* Fix permissions on /mydata:
  ```bash
  cd /mydata
  sudo chown -R $USER /mydata
  sudo chgrp -R <yourgroup> /mydata
  ```
* Clone the repo:
  ```bash
  git clone git@github.com:mcabranches/tna.git tna
  ```
* Build TNA:
  ```bash
  cd tna/src
  make
  ```

## Running an Experiment

If desired, start TNA on one or both worker nodes:
```bash
cd /mydata/tna
sudo ./build/tna --dp tc --ignore-ifaces eno33np0,lo,myiface
```

Create pairs:
```bash
./create_pair <internode|intranode>
```

Run iteration:
```bash
./run_iteration
```

# Clean

```bash
kubectl delete namespace tna-test
```
