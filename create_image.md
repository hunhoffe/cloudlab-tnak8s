# Create the Image

## Build the Linux Kernel

As an example, create a single node experiment on CloudLab using the small-lan profile
* Use machine type d430
* Use image Ubuntu 20.04
* In Advanced options, change temporary filesystem size to max (or 100 GB)

```uname -a``` should give you something like this:
```
Linux <hostname> 5.4.0-164-generic #181-Ubuntu SMP Fri Sep 1 13:41:22 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
```
Use the temporary file system (as it’s bigger than your home dir) to build the kernel

Clone the custom kernel:
```bash
git clone https://github.com/mcabranches/linux_tna linux
```

Install the following packages:
```bash
sudo apt update
sudo apt-get install -y git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison dwarves
```

Then I copied the existing Linux config file using the cp command:
```bash
cd linux
cp -v /boot/config-$(uname -r) .config
```
I made changes to the configuration file using the command: 
```bash
make menuconfig
```

* Networking support >> networking options >> network packet filtering framework (netfilter) >> IP : Netfilter configuration >> IP Tables support (required for masq / filtering / NAT) [built in (*)]
* Networking support >> Networking options >> Network packet filtering framework (Netfilter) >> Core Netfilter Configuration >> Netfilter connection tracking support
* Networking support >> Networking options >> Network packet filtering framework (Netfilter) >>IP virtual server support

Then to build and install, run:
```bash
scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
```

Then build kernel (note you will have to press enter a few times):
```bash
sudo make -j 20
```
Then install kernel:
```bash
sudo make -j 20 modules_install
sudo make install
sudo update-grub
```
Finally rebooted my system:
```bash
sudo reboot
```

You can also check if the custom kernel with version 5.16.0 (or new version, 6.6) was installed using ```uname -a```.

Output should look something like this:
```
Linux node0.tna-image-update.cudevopsfall2018.emulab.net 5.16.0+
```
Add TNA build dependencies
```
sudo apt install -y clang llvm libelf-dev libpcap-dev gcc-multilib build-essential libnl-3-200 libnl-3-dev libnl-route-3-200 libnl-route-3-dev libiptc-dev libxtables-dev libboost-all-dev pkg-config python3-jinja2
```

Reference: https://phoenixnap.com/kb/build-linux-kernel

Do some cleanup:
```bash
sudo apt-get clean
sudo apt-get autoclean
sudo apt-get autoremove
```

Remove older kernels, get list with:
```bash
dpkg --get-selections | grep linux-image
```

And remove with:
```bash
sudo apt-get remove --purge linux-image-X.X.XX-XX-generic
```

Then remove associated header files, etc. by rerunning:
```bash
sudo apt-get autoremove
sudo apt-get clean
```

Reference: https://askubuntu.com/questions/5980/how-do-i-free-up-disk-space

Remove mitigations. Check for mitigations with:
```bash
lscpu
```

Then remove them by appending ```mitigations=off``` to the kernel parameter in ```/etc/default/grub```:
```
GRUB_CMDLINE_LINUX_DEFAULT="mitigations=off"
```

Then update grub and reboot:
```
sudo update-grub
sudo reboot
```

Reference: https://sleeplessbeastie.eu/2020/03/27/how-to-disable-mitigations-for-cpu-vulnerabilities/

## Install K8s setup
Install dependencies:
```
./image_setup.sh
```

Use /mydata for kubelet ephemeral storage by changing the kubelet config. Specifically, add the KUBELET_EXTRA_ARGS environment line, similar to below:
```
hunhoffe@node3:~$ sudo cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf 
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/mydata/kubelet/config.yaml --node-ip=10.10.1.3"
Environment="KUBELET_EXTRA_ARGS=--root-dir=/mydata/kubelet"

# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/mydata/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

Resource: https://stackoverflow.com/questions/46045943/how-to-change-kubelet-working-dir-to-somewhere-else
Resource: https://stackoverflow.com/questions/34113476/where-are-the-kubernetes-kubelet-logs-located

Increase Kubelet Thresholds, also by changing the kubelet config (```/etc/systemd/system/kubelet.service.d/10-kubeadm.conf```) so it resembles below.
Use ```KUBELET_KUBECONFIG_ARGS```, and add the eviction hard argument:
```
Environment="KUBELET_KUBECONFIG_ARGS=--eviction-hard imagefs.available<2%,memory.available<100Mi,nodefs.available<2% --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc
```
