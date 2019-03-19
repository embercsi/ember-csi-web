+++
description = "Deploying KubeVirt with a CSI plugin can be tricky, there are multiple steps: setting Access Control of Kubelet, Kubernetes API, and the CSI plugin services, restarting of pods, and creating the manifests to properly deploy the controller and node CSI services.  This guide presents an easy way to try KubeVirt with Ember-CSI."
thumbnail = "images/02-getstarted-thumb.jpg"
image = "images/02-getstarted.jpg"
title = "KubeVirt and Ember-CSI"
slug = "ember-kubevirt"
author = "Kiran Thyagaraja"
draft = false
hidesidebar = true
publishDate=2018-08-02T19:05:52+02:00
lastmod=2019-03-18T22:30:57-06:00
weight = 2
+++
[KubeVirt](https://kubevirt.io) is a virtual machine management add-on for [Kubernetes](https://kubernetes.io). It allows users to run VMs alongside containers in the their Kubernetes or [OpenShift](https://www.openshift.com) clusters. This document describes a quick way to deploy either Kubernetes or OpenShift, KubeVirt and [Ember-CSI](https://ember-csi.io).

The [Ember-CSI-Kubevirt](https://github.com/embercsi/ember-csi-kubevirt.git) repository provides a wrapper on the normal KubeVirt workflow and it aims to provide a seamless integration with it while taking care of the Ember-CSI deployment.

To use Ember-CSI plugin on KubeVirt, we will utilize the [Ember-CSI-KubeVirt repository](https://github.com/embercsi/ember-csi-kubevirt.git) which can deploy an all-in-one demo deployment. The all-in-one demo deployment comprises of either Kubernetes/OpenShift with KubeVirt, an ephemeral Ceph environment and finally an Ember-CSI deployment configured with the previously deployed ephemeral Ceph plugin.

### Requirements

This demo requires QEMU-KVM, libvirt, Vagrant, vagrant-libvirt and ansible installed in the system.

In Fedora:

```shell
$ sudo dnf -y install qemu-kvm libvirt vagrant vagrant-libvirt ansible
```

Then we have to make sure the libvirt daemon is up and running.

In Fedora:

```shell
$ sudo systemctl start libvirtd
```

### Configuration
The Ember-CSI-KubeVirt repo deploys OpenShift 3.11 as its default cluster. This can be changed by editing the `tools/env.sh` file and changing the `KUBEVIRT_PROVIDER` variable.

### Setup

First we need to clone the project and change into the repository's directory and deploy the cluster, which, by default, is OpenShift 3.11. Running `make all` deploys an OpenShift cluster along with KubeVirt, Ember-CSI and an ephemeral Ceph cluster.

```shell
$ git clone https://github.com/embercsi/ember-csi-kubevirt.git
$ cd ember-csi-kubevirt/
$ sudo make all
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

namespace/kubevirt created
customresourcedefinition.apiextensions.k8s.io/kubevirts.kubevirt.io created
clusterrole.rbac.authorization.k8s.io/kubevirt.io:operator created
serviceaccount/kubevirt-operator created
clusterrolebinding.rbac.authorization.k8s.io/kubevirt-operator created
deployment.apps/virt-operator created
kubevirt.kubevirt.io/kubevirt created
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   617    0   617    0     0   2508      0 --:--:-- --:--:-- --:--:--  2508
100 35.9M  100 35.9M    0     0  23.6M      0  0:00:01  0:00:01 --:--:-- 42.6M
$
```

At this point, we have a fully functioning OpenShift cluster with KubeVirt along side Ember-CSI backed by a Ceph backend. We have also created a namespace/project called `sample-projct` which we will use to deploy a VM using KubeVirt.

Creating a virtual machine
```shell
$ ./cluster/kubectl.sh -n sample-project apply -f https://raw.githubusercontent.com/kubevirt/demo/master/manifests/vm.yaml
virtualmachine.kubevirt.io/testvm created
$
```

After the VM manifest is deployed, you can manage the VMs using the usual verbs.
```shell
$ ./cluster/kubectl.sh -n sample-project get vms
NAME      AGE       RUNNING   VOLUME
testvm    1m        false     
$
```

At this point, we have a definition of a VM but not an actual instance. To create a VM instance type:
```shell
$ ./cluster/virtctl.sh -n sample-project start testvm
VM testvm was scheduled to start
$
```

Afterwards you can inspect the VM instance.
```shell
$ ./cluster/kubectl.sh -n sample-project get vmis
NAME      AGE       PHASE        IP        NODENAME
testvm    43s       Scheduling             
```

The VM can be accessed using the console using the command:
```shell
$ ./cluster/virtctl.sh -n sample-project console testvm
Successfully connected to testvm console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
testvm login: 
```

To shut down the VM instance. 
```shell
$ ./cluster/virtctl.sh -n sample-project stop testvm
VM testvm was scheduled to stop
$
```

And finally, delete the VM definition.
```shell
$ kubectl delete vms testvm
```

### Tear Down
Tear down the whole deployment by using:

```shell
$ make cluster-down
source ./tools/env.sh && ./cluster/down.sh
$
```
