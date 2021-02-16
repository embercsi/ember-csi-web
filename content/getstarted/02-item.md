+++
description = "Deploying KubeVirt with a CSI plugin can be tricky, there are multiple steps: setting Access Control of Kubelet, Kubernetes API, and the CSI plugin services, restarting of pods, and creating the manifests to properly deploy the controller and node CSI services.  This guide presents an easy way to try KubeVirt with Ember-CSI."
thumbnail = "images/02-getstarted-thumb.jpg"
image = "images/02-getstarted.jpg"
title = "KubeVirt and Ember-CSI"
slug = "kubevirt"
author = "Kiran Thyagaraja"
draft = false
hidesidebar = true
publishDate=2018-08-02T19:05:52+02:00
lastmod=2019-06-03T14:30:57-05:00
weight = 3
+++
[KubeVirt](https://kubevirt.io) is a virtual machine management add-on for [Kubernetes](https://kubernetes.io). It allows users to run VMs alongside containers in the their Kubernetes or [OpenShift](https://www.openshift.com) clusters. This document describes a quick way to deploy either Kubernetes or OpenShift, KubeVirt and [Ember-CSI](https://ember-csi.io).

The [Ember-CSI-KubeVirt](https://github.com/embercsi/ember-csi-kubevirt) repository provides a seamless wrapper integrating the deployments of OpenShift or Kubernetes, KubeVirt, [Containerized Data Importer (CDI)](https://github.com/kubevirt/containerized-data-importer), Ember-CSI and a Ceph demo cluster. 

Ember-CSI should always be deployed using the [Ember-CSI-Operator](https://github.com/embercsi/ember-csi-operator), like we do here. The operator ensures that all of Ember-CSI's Kubernetes objects such as StatefulSets, DaemonSets, StorageClasses, RBAC rules, etc. are properly configured and running. The Ceph-demo cluster deploys an empty directory backed Ceph cluster within a namespace called `ceph-demo`. We leverage KubeVirt's repository scripts that provide an easy way to deploy OpenShift or Kubernetes using the `make cluster-up` scripts. In addition, CDI is deployed, which provides a declarative way to build Virtual Machine Disks on PVCs for Kubevirt VMs. Finally the Ember-CSI-KubeVirt repository ties all these deployments together into an easy `make all` command. 

### Requirements

This demo requires QEMU-KVM, libvirt and Docker installed in the system. In the case where this demo is being deployed in a VM, nested virtualization support must be enabled before proceeding. Nested virtualization for Red Hat/CentOS/Fedora can be enabled using one of the guides [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/nested_virt) or [here](https://www.linuxtechi.com/enable-nested-virtualization-kvm-centos-7-rhel-7/).

In Fedora/RHEL/CentOS:

```shell
$ sudo yum -y install qemu-kvm libvirt docker 
```

Add `docker` group and add your username into the `docker` group.
```shell
$ sudo groupadd docker
$ sudo gpasswd -a $USER docker
Adding user kiran to group docker
$ newgrp docker
```
Then we have to make sure the `libvirtd` and `docker` daemons are up and running and that we can successfully use the `docker` command.

```shell
$ sudo systemctl start libvirtd docker
$ docker ps
CONTAINER ID        IMAGE                    COMMAND                  CREATED             STATUS              PORTS                NAMES 
$
```

We also need to change the permissions of the `docker.sock` file in CentOS, Fedora, and RHEL after the `docker` service is running.

```shell
$ sudo chown root:docker /var/run/docker.sock
$
```

### Configuration
The Ember-CSI-KubeVirt repo deploys OpenShift 3.11 as its default cluster. This can be customized by setting the `KUBEVIRT_PROVIDER` environment variable whose valid values can be obtained [here](https://github.com/kubevirt/kubevirt/tree/master/cluster). Note that the default value of `KUBEVIRT_PROVIDER` used in the Ember-CSI-KubeVirt repo is `os-3.11.0`.

### Setup

First we need to clone the project and change into the repository's directory and deploy the cluster, which, by default, is OpenShift 3.11. Running `make all` deploys an OpenShift cluster along with KubeVirt, Ember-CSI and an ephemeral Ceph cluster.

```shell
$ git clone https://github.com/embercsi/ember-csi-kubevirt.git
$ cd ember-csi-kubevirt/
$ make all
git submodule init && git submodule update
ln -sf kubevirt/cluster && ln -sf kubevirt/hack
source ./tools/env.sh && ./cluster/up.sh
Unable to find image 'kubevirtci/gocli@sha256:df958c060ca8d90701a1b592400b33852029979ad6d5c1d9b79683033704b690' locally
Trying to pull repository docker.io/kubevirtci/gocli ... 
sha256:df958c060ca8d90701a1b592400b33852029979ad6d5c1d9b79683033704b690: Pulling from docker.io/kubevirtci/gocli
ca1df8c2ad92: Pull complete 
132134b5fbe0: Pull complete 
Digest: sha256:df958c060ca8d90701a1b592400b33852029979ad6d5c1d9b79683033704b690
Status: Downloaded newer image for docker.io/kubevirtci/gocli@sha256:df958c060ca8d90701a1b592400b33852029979ad6d5c1d9b79683033704b690

[. . .]

+ set -e
+ /usr/bin/oc create -f /tmp/local-volume.yaml
storageclass.storage.k8s.io/local created
configmap/local-storage-config created
clusterrolebinding.rbac.authorization.k8s.io/local-storage-provisioner-pv-binding created
clusterrole.rbac.authorization.k8s.io/local-storage-provisioner-node-clusterrole created
clusterrolebinding.rbac.authorization.k8s.io/local-storage-provisioner-node-binding created
role.rbac.authorization.k8s.io/local-storage-provisioner-jobs-role created
rolebinding.rbac.authorization.k8s.io/local-storage-provisioner-jobs-rolebinding created
serviceaccount/local-storage-admin created
daemonset.extensions/local-volume-provisioner created
Sending file modes: C0755 120419488 oc
Sending file modes: C0600 5649 admin.kubeconfig
Cluster "node01:8443" set.
Cluster "node01:8443" set.

[. . .]

kubevirt.kubevirt.io/kubevirt created
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   617    0   617    0     0   2497      0 --:--:-- --:--:-- --:--:--  2497
100 35.9M  100 35.9M    0     0  22.7M      0  0:00:01  0:00:01 --:--:-- 35.2M
customresourcedefinition.apiextensions.k8s.io/datavolumes.cdi.kubevirt.io created
clusterrolebinding.rbac.authorization.k8s.io/cdi-sa created
clusterrole.rbac.authorization.k8s.io/cdi created
clusterrolebinding.rbac.authorization.k8s.io/cdi-apiserver created
clusterrole.rbac.authorization.k8s.io/cdi-apiserver created
clusterrolebinding.rbac.authorization.k8s.io/cdi-apiserver-auth-delegator created
serviceaccount/cdi-apiserver created
rolebinding.rbac.authorization.k8s.io/cdi-apiserver created
role.rbac.authorization.k8s.io/cdi-apiserver created
rolebinding.rbac.authorization.k8s.io/cdi-extension-apiserver-authentication created
role.rbac.authorization.k8s.io/cdi-extension-apiserver-authentication created
service/cdi-api created
deployment.apps/cdi-apiserver created
serviceaccount/cdi-sa created
deployment.apps/cdi-deployment created
service/cdi-uploadproxy created
deployment.apps/cdi-uploadproxy created
$
```

At this point, we have a fully functioning OpenShift cluster with KubeVirt alongside Ember-CSI backed by a Ceph backend. We have also created a namespace/project called `sample-project` which we will use to deploy a VM using KubeVirt. Before we proceed further, source the `env.sh` file which helps create useful aliases for us to use.

```shell
$ source tools/env.sh
$ k create -f examples/cirros-pvc.yml
persistentvolumeclaim/cirros-pvc created
$ k get pvc
NAME         STATUS    VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS                    AGE
cirros-pvc   Bound     pvc-b19271605d2611e9   3Gi        RWO            io.ember-csi.external-ceph-sc   3s
$
```


If the `status` above says `BOUND`, we will then check to see if the CDI Importer pod has finished importing. We can tell that the import operation has been completed because the pod (job) vanishes on completion, so we'll only see the imported pod for a minute or so. When the pod is no longer alive we can proceed to create the VM.

```shell
$ k get pod
NAME                            READY     STATUS    RESTARTS   AGE
pod/importer-cirros-pvc-7fggz   1/1       Running   0          36s
$ k logs importer-cirros-pvc-7fggz -f
I0603 17:02:43.330267       1 importer.go:45] Starting importer
I0603 17:02:43.331765       1 importer.go:58] begin import process
I0603 17:02:43.331776       1 importer.go:82] begin import process
I0603 17:02:43.331782       1 dataStream.go:293] copying "https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img" to "/data/disk.img"...
I0603 17:02:43.750839       1 prlimit.go:107] ExecWithLimits qemu-img, [info --output=json https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img]
I0603 17:02:44.608621       1 prlimit.go:107] ExecWithLimits qemu-img, [convert -p -f qcow2 -O raw json: {"file.driver": "https", "file.url": "https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img", "file.timeout": 3600} /data/disk.img]
I0603 17:02:44.629043       1 qemu.go:189] 0.00
I0603 17:02:45.523126       1 qemu.go:189] 1.19
I0603 17:02:45.524781       1 qemu.go:189] 2.38
I0603 17:02:45.526762       1 qemu.go:189] 3.57
I0603 17:02:45.584362       1 qemu.go:189] 4.76
I0603 17:02:45.943055       1 qemu.go:189] 5.95
I0603 17:02:46.007784       1 qemu.go:189] 7.14
I0603 17:02:46.009710       1 qemu.go:189] 8.33
I0603 17:02:46.132837       1 qemu.go:189] 9.52
I0603 17:02:46.136531       1 qemu.go:189] 10.71
I0603 17:02:46.265449       1 qemu.go:189] 11.90
I0603 17:02:46.331481       1 qemu.go:189] 13.10
I0603 17:02:46.405348       1 qemu.go:189] 14.29
I0603 17:02:46.407621       1 qemu.go:189] 16.67
I0603 17:02:46.800378       1 qemu.go:189] 17.86
I0603 17:02:46.926435       1 qemu.go:189] 19.05
I0603 17:02:46.997326       1 qemu.go:189] 20.24
I0603 17:02:47.066298       1 qemu.go:189] 21.43
I0603 17:02:47.204769       1 qemu.go:189] 22.62
I0603 17:02:47.208013       1 qemu.go:189] 23.81
I0603 17:02:47.277740       1 qemu.go:189] 26.19
I0603 17:02:47.347230       1 qemu.go:189] 27.38
I0603 17:02:47.351255       1 qemu.go:189] 28.57
I0603 17:02:47.352152       1 qemu.go:189] 29.76
I0603 17:02:47.423172       1 qemu.go:189] 30.95
I0603 17:02:47.427168       1 qemu.go:189] 32.94
I0603 17:02:47.499725       1 qemu.go:189] 36.51
I0603 17:02:47.854468       1 qemu.go:189] 37.70
I0603 17:02:47.855162       1 qemu.go:189] 38.89
I0603 17:02:47.855533       1 qemu.go:189] 40.08
I0603 17:02:47.856050       1 qemu.go:189] 41.27
I0603 17:02:48.107792       1 qemu.go:189] 42.46
I0603 17:02:48.110893       1 qemu.go:189] 43.65
I0603 17:02:48.113279       1 qemu.go:189] 44.84
I0603 17:02:48.115777       1 qemu.go:189] 46.03
I0603 17:02:48.118525       1 qemu.go:189] 47.22
I0603 17:02:48.120897       1 qemu.go:189] 53.17
I0603 17:02:48.316169       1 qemu.go:189] 66.27
I0603 17:02:48.326010       1 qemu.go:189] 67.46
I0603 17:02:48.531847       1 qemu.go:189] 68.65
I0603 17:02:48.534070       1 qemu.go:189] 70.24
I0603 17:02:48.614171       1 qemu.go:189] 71.43
I0603 17:02:48.616393       1 qemu.go:189] 74.21
I0603 17:02:48.684632       1 qemu.go:189] 75.40
I0603 17:02:48.735547       1 qemu.go:189] 76.59
I0603 17:02:48.805687       1 qemu.go:189] 80.56
I0603 17:02:48.875171       1 qemu.go:189] 81.75
I0603 17:02:48.902321       1 qemu.go:189] 82.94
I0603 17:02:48.975726       1 qemu.go:189] 84.92
I0603 17:02:49.091149       1 qemu.go:189] 86.11
I0603 17:02:49.094110       1 qemu.go:189] 87.30
I0603 17:02:49.164136       1 qemu.go:189] 88.49
I0603 17:02:49.171284       1 qemu.go:189] 89.68
I0603 17:02:49.242742       1 qemu.go:189] 90.87
I0603 17:02:49.245652       1 qemu.go:189] 92.46
I0603 17:02:49.312736       1 qemu.go:189] 94.05
I0603 17:02:49.392508       1 qemu.go:189] 95.63
I0603 17:02:49.397972       1 qemu.go:189] 96.83
I0603 17:02:49.472402       1 qemu.go:189] 98.02
I0603 17:02:49.473218       1 qemu.go:189] 99.21
I0603 17:02:49.483436       1 prlimit.go:107] ExecWithLimits qemu-img, [info --output=json /data/disk.img]
W0603 17:02:49.493882       1 dataStream.go:343] Available space less than requested size, resizing image to available space 2902560768.
I0603 17:02:49.494231       1 dataStream.go:349] Expanding image size to: 2902560768
I0603 17:02:49.494277       1 prlimit.go:107] ExecWithLimits qemu-img, [resize -f raw /data/disk.img 2902560768]
I0603 17:02:49.516719       1 importer.go:89] import complete
$ k get pod
No resources found.
$ 
```

### Creating and Managing a Virtual Machine

Lets begin by creating a VM template.

```shell
$ k create -f examples/cirros-vm.yml
virtualmachine.kubevirt.io/cirros-vm created
$
```

Inspect whether the VM is created and running successfully

```shell
$ k get vms
NAME        AGE       RUNNING   VOLUME
cirros-vm   8s        true      
$ k get pod
NAME                            READY     STATUS    RESTARTS   AGE
virt-launcher-cirros-vm-rqwb6   1/1       Running   0          5m
$
```
Wait for the `STATUS` to become `Running` before connecting to the VM's console.

The running VM can be accessed using the console using the `v console ...` command. Note that the `request failed` errors are safe to ignore for this example Cirros VM.

```shell
$ v console cirros-vm
Successfully connected to cirros-vm console. The escape sequence is ^]
[    0.000000] Initializing cgroup subsys cpuset
[    0.000000] Initializing cgroup subsys cpu

[...] 

udhcpc (v1.23.2) started
Sending discover...
Sending select for 10.128.0.67...
Lease of 10.128.0.67 obtained, lease time 86313600
route: SIOCADDRT: File exists
WARN: failed: route add -net "0.0.0.0/0" gw "10.128.0.1"
checking http://169.254.169.254/2009-04-04/instance-id
failed 1/20: up 60.13. request failed
failed 2/20: up 72.24. request failed

[ ... ]

failed to read iid from metadata. tried 20
failed to get instance-id of datasource

[ ... ]
  ____               ____  ____
 / __/ __ ____ ____ / __ \/ __/
/ /__ / // __// __// /_/ /\ \ 
\___//_//_/  /_/   \____/___/ 
   http://cirros-cloud.net


login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
cirros-vm login: 
```
And the VM's console can be exited using the `Control+]` sequence, which will return control back to your shell.

To shut down the VM instance. 
```shell
$ v stop cirros-vm
VM cirros-vm was scheduled to stop
$
```

And finally, delete the VM definition and remove the previously created PVC.
```shell
$ k delete vms cirros-vm
virtualmachine.kubevirt.io "cirros-vm" deleted
$ k delete -f examples/cirros-pvc.yml
persistentvolumeclaim "cirros-pvc" deleted
$ 
```

### Tear Down
Tear down the whole deployment by using:

```shell
$ make cluster-down
source ./tools/env.sh && ./cluster/down.sh
$
```
