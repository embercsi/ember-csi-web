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
weight = 2
+++
To use the Ember-CSI plugin on Kubevirt we need to make changes to our deployment.

The easiest way to make the changes is to copy this kubevirt directory into a directory of the kubevirt repository, and run the `csi_up.sh` script from there after the cluster is up and running.

For now the example only supports single node deployments, and for convenience we are using a pod instead of a StatefulSet and DaemonSets and the permissions are too broad.

Given the following assumptions:

- This `kubevirt` directory is in `$cl_example`.
- We have modified `X_CSI_BACKEND_CONFIG` environmental variable in the `csi.yml` (example is for XtremIO).
- Our current working directory is `kubevirt` repository's root directory.
- We haven't created a kubevirt cluster yet.

The following commands will create the cluster, make changes to the cluster to support CSI plugins, deploy the CSI plugin, create a PVC, and an app that uses the PVC:


```shell
make cluster-up
make cluster-sync

# Modify the cluster for CSI
csi/csi_up.sh

# Setup RBAC
cluster/kubectl.sh create -f csi/rbac.yml

# Setup the CSI driver
cluster/kubectl.sh create -f csi/csi.yml

# Create a PVC (creates a volume on the storage via the CSI plugin)
cluster/kubectl.sh create -f csi/pvc.yml

# Create an APP that uses the created volume
cluster/kubectl.sh create -f csi/app.yml
```

We can send GRPC commands to the CSI driver using the deployed csc container.

For example to list volumes you can do:

```shell
cluster/kubectl.sh exec -c csc -it csi-xtremio-pod csc controller list-volumes
```

