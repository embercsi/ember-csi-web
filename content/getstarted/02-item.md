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
lastmod=2019-05-21T11:30:57-06:00
weight = 2
+++
[KubeVirt](https://kubevirt.io) is a virtual machine management add-on for [Kubernetes](https://kubernetes.io). It allows users to run VMs alongside containers in the their Kubernetes or [OpenShift](https://www.openshift.com) clusters. This document describes a quick way to deploy either Kubernetes or OpenShift, KubeVirt and [Ember-CSI](https://ember-csi.io).

The [Ember-CSI-KubeVirt](https://github.com/embercsi/ember-csi-kubevirt) repository provides a seamless wrapper integrating the deployments of OpenShift or Kubernetes, KubeVirt, [Containerized Data Importer (CDI)](https://github.com/kubevirt/containerized-data-importer), Ember-CSI and a Ceph demo cluster. 

Ember-CSI should always be deployed using the [Ember-CSI-Operator](https://github.com/embercsi/ember-csi-operator), like we do here. The operator ensures that all of Ember-CSI's Kubernetes objects such as StatefulSets, DaemonSets, StorageClasses, RBAC rules, etc. are properly configured and running. The Ceph-demo cluster deploys an empty directory backed Ceph cluster within a namespace called `ceph-demo`. We leverage KubeVirt's repository scripts that provide an easy way to deploy OpenShift or Kubernetes using the `make cluster-up` scripts. In addition, CDI is deployed, which provides a declarative way to build Virtual Machine Disks on PVCs for Kubevirt VMs. Finally the Ember-CSI-KubeVirt repository ties all these deployments together into an easy `make all` command. 

### Requirements

This demo requires QEMU-KVM, libvirt and Docker installed in the system. In the case where this demo is being deployed in a VM, nested virtualization support must be enabled before proceeding. Nested virtualization for Red Hat/CentOS/Fedora can be enabled using one of the guides [here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/nested_virt) or [here](https://www.linuxtechi.com/enable-nested-virtualization-kvm-centos-7-rhel-7/).

In Fedora/Red Hat/CentOS:

```shell
$ sudo dnf -y install qemu-kvm libvirt docker 
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
pod/importer-cirros-pvc-8lr4k   1/1       Running   0          36s
$ k logs pod/importer-cirros-pvc-8lr4k
I0412 15:30:01.911266       1 importer.go:45] Starting importer
I0412 15:30:01.920943       1 importer.go:58] begin import process
I0412 15:30:01.920993       1 importer.go:82] begin import process
I0412 15:30:01.921027       1 dataStream.go:293] copying "https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img" to "/data/disk.img"...
I0412 15:30:02.407774       1 prlimit.go:107] ExecWithLimits qemu-img, [info --output=json https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img]
I0412 15:30:03.310515       1 prlimit.go:107] ExecWithLimits qemu-img, [convert -p -f qcow2 -O raw json: {"file.driver": "https", "file.url": "https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img", "file.timeout": 3600} /data/disk.img]
I0412 15:30:03.320607       1 qemu.go:189] 0.00
I0412 15:30:04.207629       1 qemu.go:189] 1.19
I0412 15:30:04.208937       1 qemu.go:189] 2.38
I0412 15:30:04.265587       1 qemu.go:189] 3.57
...
I0412 15:30:09.946197       1 qemu.go:189] 99.21
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
cirros-vm   3s        true      
$ k get pod
NAME                            READY     STATUS    RESTARTS   AGE
virt-launcher-cirros-vm-rqwb6   0/1       Running   0          5m
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
