+++
description = "Deploying Kubevirt with a CSI plugin can be tricky, there are multiple steps: setting Access Control of Kubelet, Kubernetes API, and the CSI plugin services, restarting of pods, and creating the manifests to properly deploy the controller and node CSI services.  This guide presents an easy way to try Kubevirt with Ember CSI."
thumbnail = "images/02-getstarted-thumb.jpg"
image = "images/02-getstarted.jpg"
title = "KubeVirt and Ember CSI"
slug = "getting-started-kubevirt"
author = "Gorka Eguileor"
draft = false
hidesidebar = true
publishDate=2018-08-02T19:05:52+02:00
lastmod=2019-03-03T22:30:57-06:00
weight = 2
+++
To use Ember-CSI plugin on Kubevirt, we will utilize the [Ember-CSI-Kubevirt repository](https://github.com/embercsi/ember-csi-kubevirt.git) which can deploy an all-in-one demo deployment. The all-in-one demo deployment comprises of either Kubernetes/OpenShift with Kubevirt, an ephemeral Ceph environment and finally an Ember-CSI deployment configured with the previously deployed ephemeral Ceph plugin.

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
The Ember-CSI-Kubevirt repo deploys OpenShift 3.11 as its default cluster. This can be changed by editing the `tools/env.sh` file and changing the `KUBEVIRT_PROVIDER` variable.

### Setup

First we need to clone the project and change into the repository's directory:

```shell
git clone https://github.com/embercsi/ember-csi-kubevirt.git
cd ember-csi-kubevirt/
```

Then we deploy the cluster along with Kubevirt.

```shell
make cluster-up
```

Next we deploy the Ember-CSI Operator.

```shell
make deploy
```

We then deploy an ephemeral Ceph cluster and deploy an Ember-CSI Ceph plugin which utilizes the ephemeral Ceph cluster. After Ember-CSI and Ceph are deployed, a PVC and a dummy app is also created to showcase tha
t the Ceph plugin can be accessed via Ember-CSI.

```shell
make demo
```

To tear down the whole deployment:

```shell
make cluster-down
```
