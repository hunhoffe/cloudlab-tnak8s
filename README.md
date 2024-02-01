# CloudLab profile for deploying Kubernetes in the TNA Environment

General information for what on CloudLab profiles created via GitHub repo can be found in the example repo [here](https://github.com/emulab/my-profile) or in the CloudLab [manual](https://docs.cloudlab.us/cloudlab-manual.html)

Specifically, the goal of this repo is to create a CloudLab profile that allows for one-click creation of a Kubernetes deployment for academic research on top of a kernel custom to the research project.

## User Information

Create a CloudLab experiment using the tnak8s profile. It's recommended to use at least 3 nodes for the cluster. It has been testsed on c6525-25g nodes. 

On each node, a copy of this repo is available at:
```
    /local/repository
```
Docker images are store in additional ephemeral cloudlab storage, mounted on each node at:
```
    /mydata
```

To get information on the cluster, use kubectl as expected:
```
    $ kubectl get nodes
```

## Image Creation

The process to create the underlying image is documented in [```create_image.md```](create_image.md)
