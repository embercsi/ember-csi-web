+++
description = "Deploying Kubevirt with a CSI plugin can be tricky, there are multiple steps: setting Access Control of Kubelet, Kubernetes API, and the CSI plugin services, restarting of pods, and creating the manifests to properly deploy the controller and node CSI services.  This guide presents an easy way to try Kubevirt with Ember CSI."
thumbnail = "images/02-getstarted-thumb.jpg"
image = "images/02-getstarted.jpg"
title = "KubeVirt and Ember CSI"
slug = "kubevirt"
author = "Gorka Eguileor"
draft = false
hidesidebar = true
publishDate=2018-08-02T19:05:52+02:00
lastmod=2019-03-04T22:30:57-06:00
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

First we need to clone the project and change into the repository's directory and deploy the cluster, which, by default, is OpenShift 3.11

```shell
$ git clone https://github.com/embercsi/ember-csi-kubevirt.git
$ cd ember-csi-kubevirt/
$ sudo make cluster-up
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
$

```

Next we deploy the Ember-CSI Operator.

```shell
$ make deploy
source ./tools/env.sh
./tools/deploy.sh
namespace/ember-csi created
serviceaccount/ember-csi-operator created
role.rbac.authorization.k8s.io/ember-csi-operator created
rolebinding.rbac.authorization.k8s.io/ember-csi-operator created
clusterrole.rbac.authorization.k8s.io/ember-csi-operator created
clusterrolebinding.rbac.authorization.k8s.io/ember-csi-operator created
customresourcedefinition.apiextensions.k8s.io/embercsis.ember-csi.io created
deployment.apps/ember-csi-operator created
securitycontextconstraints.security.openshift.io/ember-csi-scc created
Wait until the deployment is ready...
deployment.extensions/ember-csi-operator condition met
$

```

Source the environment file and check whether the Operator pods are properly deployed:

```shell
$ source tools/env.sh
$ k get all -n ember-csi
NAME                                      READY     STATUS    RESTARTS   AGE
pod/ember-csi-operator-68844f4988-vkfqk   1/1       Running   0          23s

NAME                                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ember-csi-operator   1         1         1            1           23s

NAME                                            DESIRED   CURRENT   READY     AGE
replicaset.apps/ember-csi-operator-68844f4988   1         1         1         23s
$

```

We then deploy an ephemeral Ceph cluster and deploy an Ember-CSI Ceph plugin which utilizes the ephemeral Ceph cluster. After Ember-CSI and Ceph are deployed, a PVC and a dummy app is also created to showcase tha
t the Ceph plugin can be accessed via Ember-CSI.

```shell
$ make demo
source ./tools/env.sh
./tools/demo.sh
namespace/ceph-demo created
serviceaccount/ceph-demo-sa created
pod/ceph-demo-pod created
Wait until the pod is ready...
pod/ceph-demo-pod condition met
tar: Removing leading `/' from member names
secret/system-files created
embercsi.ember-csi.io/external-ceph created
Wait until the pod is ready...
pod/external-ceph-controller-0 condition met
namespace/sample-project created
persistentvolumeclaim/ember-csi-aio-pvc created
pod/busybox-sleep created
pod/busybox-sleep condition met
Events:
  Type     Reason                  Age                From                     Message
  ----     ------                  ----               ----                     -------
  Warning  FailedScheduling        22s (x5 over 25s)  default-scheduler        pod has unbound PersistentVolumeClaims
  Normal   Scheduled               22s                default-scheduler        Successfully assigned sample-project/busybox-sleep to node01
  Normal   SuccessfulAttachVolume  21s                attachdetach-controller  AttachVolume.Attach succeeded for volume "pvc-0f6649b03ebf11e9"
  Normal   Pulling                 3s                 kubelet, node01          pulling image "busybox"
  Normal   Pulled                  1s                 kubelet, node01          Successfully pulled image "busybox"
  Normal   Created                 1s                 kubelet, node01          Created container
  Normal   Started                 1s                 kubelet, node01          Started container
/var/lib/ember-csi/vols/a3259ae3-6c63-4193-8ae5-9f59e8399fbe
                        975.9M      2.5M    906.2M   0% /data

$

```

### Tear Down
Tear down the whole deployment by using:

```shell
$ make cluster-down
source ./tools/env.sh && ./cluster/down.sh
$

```
