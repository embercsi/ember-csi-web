+++
description = "Setting Kubernetes to use CSI plugins is non trivial: Access Control of Kubelet, Kubernetes API, and CSI plugin services, and the manifests to properly deploy the controller and node CSI services are some of the required steps.  This guide presents an easy way to try Kubernetes with Ember CSI."
thumbnail = "images/01-getstarted-thumb.jpg"
image = "images/01-getstarted.jpg"
title = "Kubernetes and Ember CSI"
slug = "01-getting-started-k8s"
author = "Gorka Eguileor"
draft = false
hidesidebar = true
+++
Many things need to be considered when deploying a CSI plugin in Kubernetes, making it a painful experience for many first time users.  To ease this first contact with Kubernetes and CSI, the Ember repository comes with a [Kubernetes example that automates the deployment of Kubernetes with Ember CSI](https://github.com/Akrog/ember-csi/tree/master/examples/kubernetes).

This article covers how to run the demo to deploy a Kubernetes single master cluster on CentOS 7 with 2 additional nodes using [kubeadm](http://kubernetes.io/docs/admin/kubeadm/) and Ember-CSI as the storage provider with an LVM loopback device as the backend.

Ember CSI plugin is set as the default storage class, running 1 service (`StatefulSet`) with the CSI plugin running as *Controller* to manage the provisioning on *node0*, and a service (`DaemonSet`) running the plugin as *Node* mode on each of the nodes to manage local attachments.

Specific Kubernetes configuration changes are carried out by the demo's Ansible playbook, and won't be covered in this article.

### Requirements

The automated script relies on Vagrant, libvirt, KVM, and Ansible for the creation and provisioning of the 3 VMs. So we'll need to have the required packages.

In fedora these packages can be installed with:

```shell
$ sudo dnf -y install qemu-kvm libvirt vagrant-libvirt ansible
```


### Configuration

The demo doesn't require any configuration changes to run, and the `Vagranfile` defines 2 nodes and a master, each with 4GB and 2 cores.  Which can be changed using variables `NODES`, `MEMORY`, and `CPUS` in the file.


### Setup

The demo supports local and remote libvirt, for those that use an external box to run their VMs.

To do a local setup of the demo we must run the `up.sh` script, be aware that this will take a while:

```shell
$ ./up.sh
Bringing machine 'master' up with 'libvirt' provider...
Bringing machine 'node0' up with 'libvirt' provider...
Bringing machine 'node1' up with 'libvirt' provider...
==> master: Checking if box 'centos/7' is up to date...
==> node1: Checking if box 'centos/7' is up to date...
==> node0: Checking if box 'centos/7' is up to date...

[ . . . ]

PLAY RECAP *********************************************************************
master                     : ok=35   changed=31   unreachable=0    failed=0
node0                      : ok=33   changed=27   unreachable=0    failed=0
node1                      : ok=25   changed=23   unreachable=0    failed=0
```

Remote configuration requires defining our remote libvirt system using `LIBVIRT_HOST` and `LIBVIRT_USER` environmental variables before calling the `up.sh` script.  `LIBVIRT_USER` defaults to `root`, so we don't need to set it up if that's what we want to use:

```shell
$ export LIBVIRT_HOST=192.168.1.11
$ ./up.sh
Bringing machine 'master' up with 'libvirt' provider...
Bringing machine 'node0' up with 'libvirt' provider...
Bringing machine 'node1' up with 'libvirt' provider...
==> master: Checking if box 'centos/7' is up to date...
==> node1: Checking if box 'centos/7' is up to date...
==> node0: Checking if box 'centos/7' is up to date...

[ . . . ]

PLAY RECAP *********************************************************************
master                     : ok=35   changed=31   unreachable=0    failed=0
node0                      : ok=33   changed=27   unreachable=0    failed=0
node1                      : ok=25   changed=23   unreachable=0    failed=0
```

### Usage

During the setup the Kubernetes configuration is copied from the master VM to the host, so on completion we can use it locally as follows:

```shell
$ kubectl --kubeconfig=kubeconfig.conf get nodes
master    Ready     master    21m       v1.11.1
node0     Ready     <none>    21m       v1.11.1
node1     Ready     <none>    21m       v1.11.1
```

If we don't have `kubectl` installed in our system we can SSH into the master and run commands from there:
```shell
$ vagrant ssh master
Last login: Tue Jul 24 10:12:40 2018 from 192.168.121.1
[vagrant@master ~]$ kubectl get nodes
NAME      STATUS    ROLES     AGE       VERSION
master    Ready     master    21m       v1.11.1
node0     Ready     <none>    21m       v1.11.1
node1     Ready     <none>    21m       v1.11.1
```

Unless stated otherwise all the following commands are run assuming we are in the *master* node.

We can check that the CSI *controller* service is running:

```shell
[vagrant@master ~]$ kubectl get pod csi-controller-0
NAME               READY     STATUS    RESTARTS   AGE
csi-controller-0   4/4       Running   0          22m
```

Check the logs of the CSI *controller*:

```shell
[vagrant@master ~]$ kubectl logs csi-controller-0 -c csi-driver
Starting Ember CSI v0.0.2 in controller only mode (cinderlib: v0.2.2.dev0, cinder: v11.1.1, CSI spec: v0.2.0)
Supported filesystems are: cramfs, minix, btrfs, ext2, ext3, ext4, xfs
Running as controller with backend LVMVolumeDriver v3.0.0
Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
Now serving on unix:///csi-data/csi.sock...
=> 2018-07-24 10:14:28.981718 GRPC [126562384]: GetPluginInfo without params
<= 2018-07-24 10:14:28.981747 GRPC in 0s [126562384]: GetPluginInfo returns
        name: "io.ember-csi"
        vendor_version: "0.0.2"
        manifest {
          key: "cinder-driver"
          value: "LVMVolumeDriver"
        }
        manifest {
          key: "cinder-driver-supported"
          value: "True"
        }
        manifest {
          key: "cinder-driver-version"
          value: "3.0.0"
        }
        manifest {
          key: "cinder-version"
          value: "11.1.1"
        }
        manifest {
          key: "cinderlib-version"
          value: "0.2.2.dev0"
        }
        manifest {
          key: "mode"
          value: "controller"
        }
        manifest {
          key: "persistence"
          value: "CRDPersistence"
        }
=> 2018-07-24 10:14:28.984271 GRPC [126562624]: Probe without params
<= 2018-07-24 10:14:28.984289 GRPC in 0s [126562624]: Probe returns nothing
=> 2018-07-24 10:14:28.986625 GRPC [126562744]: GetPluginCapabilities without params
<= 2018-07-24 10:14:28.986645 GRPC in 0s [126562744]: GetPluginCapabilities returns
        capabilities {
          service {
            type: CONTROLLER_SERVICE
          }
        }
=> 2018-07-24 10:14:28.988548 GRPC [126562864]: ControllerGetCapabilities without params
<= 2018-07-24 10:14:28.988654 GRPC in 0s [126562864]: ControllerGetCapabilities returns
        capabilities {
          rpc {
            type: CREATE_DELETE_VOLUME
          }
        }
        capabilities {
          rpc {
            type: PUBLISH_UNPUBLISH_VOLUME
          }
        }
        capabilities {
          rpc {
            type: LIST_VOLUMES
          }
        }
        capabilities {
          rpc {
            type: GET_CAPACITY
          }
        }
```

Check that the CSI *node* services are also running:

```shell
[vagrant@master ~]$ kubectl get pod --selector=app=csi-node
NAME             READY     STATUS    RESTARTS   AGE
csi-node-29sls   3/3       Running   0          29m
csi-node-p7r9r   3/3       Running   1          29m
```

Check the CSI logs for both *node* services:

```shell
[vagrant@master ~]$ kubectl logs csi-node-29sls -c csi-driver
Starting Ember CSI v0.0.2 in node only mode (cinderlib: v0.2.2.dev0, cinder: v11.1.1, CSI spec: v0.2.0)
Supported filesystems are: cramfs, minix, btrfs, ext2, ext3, ext4, xfs
Running as node
Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
Now serving on unix:///csi-data/csi.sock...
=> 2018-07-24 10:14:04.339319 GRPC [123797944]: GetPluginInfo without params
<= 2018-07-24 10:14:04.339360 GRPC in 0s [123797944]: GetPluginInfo returns
        name: "io.ember-csi"
        vendor_version: "0.0.2"
        manifest {
          key: "cinder-version"
          value: "11.1.1"
        }
        manifest {
          key: "cinderlib-version"
          value: "0.2.2.dev0"
        }
        manifest {
          key: "mode"
          value: "node"
        }
        manifest {
          key: "persistence"
          value: "CRDPersistence"
        }
=> 2018-07-24 10:14:04.340763 GRPC [123797584]: NodeGetId without params
<= 2018-07-24 10:14:04.340781 GRPC in 0s [123797584]: NodeGetId returns
        node_id: "node1"


[vagrant@master ~]$ kubectl logs csi-node-p7r9r -c csi-driver
Starting Ember CSI v0.0.2 in node only mode (cinderlib: v0.2.2.dev0, cinder: v11.1.1, CSI spec: v0.2.0)
Supported filesystems are: cramfs, minix, btrfs, ext2, ext3, ext4, xfs
Running as node
Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
Now serving on unix:///csi-data/csi.sock...
=> 2018-07-24 10:14:24.686979 GRPC [126448056]: GetPluginInfo without params
<= 2018-07-24 10:14:24.687173 GRPC in 0s [126448056]: GetPluginInfo returns
        name: "io.ember-csi"
        vendor_version: "0.0.2"
        manifest {
          key: "cinder-version"
          value: "11.1.1"
        }
        manifest {
          key: "cinderlib-version"
          value: "0.2.2.dev0"
        }
        manifest {
          key: "mode"
          value: "node"
        }
        manifest {
          key: "persistence"
          value: "CRDPersistence"
        }
=> 2018-07-24 10:14:24.691020 GRPC [126447696]: NodeGetId without params
<= 2018-07-24 10:14:24.691048 GRPC in 0s [126447696]: NodeGetId returns
        node_id: "node0"
```

Ember CSI plugin stores connection information in Kubernetes as CRDs when running as a *node* service. This information is used by the *controller* Ember service to map the volume to the host curing the connection of a volume to a container.  We can check what information is stored in Kubernetes checking `keyvalue`:


```shell
[vagrant@master ~]$ kubectl get keyvalue
NAME      AGE
node0     30m
node1     30m

[vagrant@master ~]$ kubectl describe kv
Name:         node0
Namespace:    default
Labels:       <none>
Annotations:  value={"platform":"x86_64","host":"node0","do_local_attach":false,"ip":"192.168.10.100","os_type":"linux2","multipath":true,"initiator":"iqn.1994
-05.com.redhat:6cf4bf7fddc0"}                                                                                                                                  API Version:  ember-csi.io/v1
Kind:         KeyValue
Metadata:
  Creation Timestamp:  2018-07-24T10:14:16Z
  Generation:          1
  Resource Version:    760
  Self Link:           /apis/ember-csi.io/v1/namespaces/default/keyvalues/node0
  UID:                 525d03cf-8f2a-11e8-847c-525400059da0
Events:                <none>


Name:         node1
Namespace:    default
Labels:       <none>
Annotations:  value={"platform":"x86_64","host":"node1","do_local_attach":false,"ip":"192.168.10.101","os_type":"linux2","multipath":true,"initiator":"iqn.1994
-05.com.redhat:1ad738f0b4e"}                                                                                                                                   API Version:  ember-csi.io/v1
Kind:         KeyValue
Metadata:
  Creation Timestamp:  2018-07-24T10:14:03Z
  Generation:          1
  Resource Version:    735
  Self Link:           /apis/ember-csi.io/v1/namespaces/default/keyvalues/node1
  UID:                 4a4481dc-8f2a-11e8-847c-525400059da0
Events:                <none>
```

Now we can create a 1GB volume using provided PVC manifest:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/pvc.yml
persistentvolumeclaim/csi-pvc created
```

The volume creation will not only result in a new Kubernetes PVC, but also in a new Ember `volume` CRD with the volume's metadata. We now can check the PVC and the CRD:

```shell
[vagrant@master ~]$ kubectl get pvc
NAME      STATUS    VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS   AGE
csi-pvc   Pending                                                    csi-sc         1s


[vagrant@master ~]$ kubectl get pvc
NAME      STATUS    VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS   AGE
csi-pvc   Bound     pvc-c24d470e8f2e11e8   1Gi        RWO            csi-sc         25s


[vagrant@master ~]$ kubectl get vol
NAME                                   AGE
4c1b19f4-7336-4d97-b4ab-5ea70efd39d5   1m


[vagrant@master ~]$ kubectl describe vol
Name:         4c1b19f4-7336-4d97-b4ab-5ea70efd39d5
Namespace:    default
Labels:       backend_name=lvm
              volume_id=4c1b19f4-7336-4d97-b4ab-5ea70efd39d5
              volume_name=pvc-c24d470e8f2e11e8
Annotations:  json={"ovo":{"versioned_object.version":"1.6","versioned_object.name":"Volume","versioned_object.data":{"migration_status":null,"provider_id":null,"availability_zone":"lvm","terminated_at":null,"updat...
API Version:  ember-csi.io/v1
Kind:         Volume
Metadata:
  Creation Timestamp:  2018-07-24T10:46:02Z
  Generation:          1
  Resource Version:    3459
  Self Link:           /apis/ember-csi.io/v1/namespaces/default/volumes/4c1b19f4-7336-4d97-b4ab-5ea70efd39d5
  UID:                 c2791ec8-8f2e-11e8-847c-525400059da0
Events:                <none>
```

Each one of the CSI plugin services is running the `akrog/csc` container with the service's CSI configuration, allowing us to easily send commands directly to that specific CSI plugin using the [Container Storage Client](https://github.com/rexray/gocsi/tree/master/csc).

For example, we can request the CSI *controller* plugin to list volumes with:

```shell
[vagrant@master ~]$ kubectl exec -c csc csi-controller-0 csc controller list-volumes
"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"  1073741824
```

Now we are going to create a container on *node1*, where neither the CSI *controller* nor the LVM reside, using the `app.yml` manifest that mounts the EXT4 PVC we just created into the `/data` directory:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/app.yml
pod/my-csi-app created

```

This process will take some time, as it needs to create the volume, attach it, format it, and mount it.  We can start tailing the CSI *controller* plugin logs to see that the plugin exports the volume:

```shell
[vagrant@master ~]$ kubectl logs csi-controller-0 -fc csi-driver
Starting Ember CSI v0.0.2 in controller only mode (cinderlib: v0.2.2.dev0, cinder: v11.1.1, CSI spec: v0.2.0)

[ . . .]

=> 2018-07-24 10:54:50.036959 GRPC [126565024]: ControllerPublishVolume with params
        volume_id: "4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"
        node_id: "node1"
        volume_capability {
          mount {
            fs_type: "ext4"
          }
          access_mode {
            mode: SINGLE_NODE_WRITER
          }
        }
        volume_attributes {
          key: "storage.kubernetes.io/csiProvisionerIdentity"
          value: "1532427201926-8081-io.ember-csi"
        }
<= 2018-07-24 10:54:51.735242 GRPC in 2s [126565024]: ControllerPublishVolume returns
        publish_info {
          key: "connection_info"
          value: "{\"connector\": {\"initiator\": \"iqn.1994-05.com.redhat:1ad738f0b4e\", \"ip\": \"192.168.10.101\", \"platform\": \"x86_64\", \"host\": \"node1\", \"do_local_attach\": false, \"os_type\": \"linux2\", \"multipath\": true}, \"conn\": {\"driver_volume_type\": \"iscsi\", \"data\": {\"target_luns\": [0], \"target_iqns\": [\"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\"], \"target_discovered\": false, \"encrypted\": false, \"target_iqn\": \"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_portal\": \"192.168.10.100:3260\", \"volume_id\": \"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_lun\": 0, \"auth_password\": \"xtZUGSxeoH7uQ34z\", \"auth_username\": \"DcL6r8st8MLzuVBapWhZ\", \"auth_method\": \"CHAP\", \"target_portals\": [\"192.168.10.100:3260\"]}}}"
        }
^C
```

Then, once we see that the `ControllerPublishVolume` call has completed we go and tail the CSI *node* plugin logs to see that the plugin attaches the volume to the container:

```shell
[vagrant@master ~]$ kubectl logs csi-node-29sls -c csi-driver
Starting Ember CSI v0.0.2 in node only mode (cinderlib: v0.2.2.dev0, cinder: v11.1.1, CSI spec: v0.2.0)

[ . . . ]

=> 2018-07-24 10:54:53.780587 GRPC [123798064]: NodeGetCapabilities without params
<= 2018-07-24 10:54:53.781102 GRPC in 0s [123798064]: NodeGetCapabilities returns
        capabilities {
          rpc {
            type: STAGE_UNSTAGE_VOLUME
          }
        }
=> 2018-07-24 10:54:53.784211 GRPC [123797944]: NodeStageVolume with params
        volume_id: "4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"
        publish_info {
          key: "connection_info"
          value: "{\"connector\": {\"initiator\": \"iqn.1994-05.com.redhat:1ad738f0b4e\", \"ip\": \"192.168.10.101\", \"platform\": \"x86_64\", \"host\": \"node1\", \"do_local_attach\": false, \"os_type\": \"linux2\", \"multipath\": true}, \"conn\": {\"driver_volume_type\": \"iscsi\", \"data\": {\"target_luns\": [0], \"target_iqns\": [\"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\"], \"target_discovered\": false, \"encrypted\": false, \"target_iqn\": \"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_portal\": \"192.168.10.100:3260\", \"volume_id\": \"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_lun\": 0, \"auth_password\": \"xtZUGSxeoH7uQ34z\", \"auth_username\": \"DcL6r8st8MLzuVBapWhZ\", \"auth_method\": \"CHAP\", \"target_portals\": [\"192.168.10.100:3260\"]}}}"
        }
        staging_target_path: "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-c24d470e8f2e11e8/globalmount"
        volume_capability {
          mount {
          }
          access_mode {
            mode: SINGLE_NODE_WRITER
          }
        }
        volume_attributes {
          key: "storage.kubernetes.io/csiProvisionerIdentity"
          value: "1532427201926-8081-io.ember-csi"
        }
=> 2018-07-24 10:55:09.380330 GRPC [123799384]: NodeGetCapabilities without params
<= 2018-07-24 10:55:09.380891 GRPC in 0s [123799384]: NodeGetCapabilities returns
        capabilities {
          rpc {
            type: STAGE_UNSTAGE_VOLUME
          }
        }
=> 2018-07-24 10:55:09.383998 GRPC [123798784]: NodeStageVolume with params
        volume_id: "4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"
        publish_info {
          key: "connection_info"
          value: "{\"connector\": {\"initiator\": \"iqn.1994-05.com.redhat:1ad738f0b4e\", \"ip\": \"192.168.10.101\", \"platform\": \"x86_64\", \"host\": \"node1\", \"do_local_attach\": false, \"os_type\": \"linux2\", \"multipath\": true}, \"conn\": {\"driver_volume_type\": \"iscsi\", \"data\": {\"target_luns\": [0], \"target_iqns\": [\"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\"], \"target_discovered\": false, \"encrypted\": false, \"target_iqn\": \"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_portal\": \"192.168.10.100:3260\", \"volume_id\": \"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_lun\": 0, \"auth_password\": \"xtZUGSxeoH7uQ34z\", \"auth_username\": \"DcL6r8st8MLzuVBapWhZ\", \"auth_method\": \"CHAP\", \"target_portals\": [\"192.168.10.100:3260\"]}}}"
        }
        staging_target_path: "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-c24d470e8f2e11e8/globalmount"
        volume_capability {
          mount {
          }
          access_mode {
            mode: SINGLE_NODE_WRITER
          }
        }
        volume_attributes {
          key: "storage.kubernetes.io/csiProvisionerIdentity"
          value: "1532427201926-8081-io.ember-csi"
        }
Retrying to get a multipathRetrying to get a multipath=> 2018-07-24 10:55:25.546019 GRPC [124162248]: NodeGetCapabilities without params
<= 2018-07-24 10:55:25.546121 GRPC in 0s [124162248]: NodeGetCapabilities returns
        capabilities {
          rpc {
            type: STAGE_UNSTAGE_VOLUME
          }
        }
=> 2018-07-24 10:55:25.557262 GRPC [123800704]: NodeStageVolume with params
        volume_id: "4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"
        publish_info {
          key: "connection_info"
          value: "{\"connector\": {\"initiator\": \"iqn.1994-05.com.redhat:1ad738f0b4e\", \"ip\": \"192.168.10.101\", \"platform\": \"x86_64\", \"host\": \"node1\", \"do_local_attach\": false, \"os_type\": \"linux2\", \"multipath\": true}, \"conn\": {\"driver_volume_type\": \"iscsi\", \"data\": {\"target_luns\": [0], \"target_iqns\": [\"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\"], \"target_discovered\": false, \"encrypted\": false, \"target_iqn\": \"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_portal\": \"192.168.10.100:3260\", \"volume_id\": \"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_lun\": 0, \"auth_password\": \"xtZUGSxeoH7uQ34z\", \"auth_username\": \"DcL6r8st8MLzuVBapWhZ\", \"auth_method\": \"CHAP\", \"target_portals\": [\"192.168.10.100:3260\"]}}}"
        }
        staging_target_path: "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-c24d470e8f2e11e8/globalmount"
        volume_capability {
          mount {
          }
          access_mode {
            mode: SINGLE_NODE_WRITER
          }
        }
        volume_attributes {
          key: "storage.kubernetes.io/csiProvisionerIdentity"
          value: "1532427201926-8081-io.ember-csi"
        }
Retrying to get a multipath<= 2018-07-24 10:55:34.895940 GRPC in 41s [123797944]: NodeStageVolume returns nothing
<= 2018-07-24 10:55:34.900178 GRPC in 26s [123798784]: NodeStageVolume returns nothing
<= 2018-07-24 10:55:34.903827 GRPC in 9s [123800704]: NodeStageVolume returns nothing
=> 2018-07-24 10:55:34.905635 GRPC [123801424]: NodeGetCapabilities without params
<= 2018-07-24 10:55:34.905701 GRPC in 0s [123801424]: NodeGetCapabilities returns
        capabilities {
          rpc {
            type: STAGE_UNSTAGE_VOLUME
          }
        }
=> 2018-07-24 10:55:34.909208 GRPC [123800944]: NodePublishVolume with params
        volume_id: "4c1b19f4-7336-4d97-b4ab-5ea70efd39d5"
        publish_info {
          key: "connection_info"
          value: "{\"connector\": {\"initiator\": \"iqn.1994-05.com.redhat:1ad738f0b4e\", \"ip\": \"192.168.10.101\", \"platform\": \"x86_64\", \"host\": \"node1\", \"do_local_attach\": false, \"os_type\": \"linux2\", \"multipath\": true}, \"conn\": {\"driver_volume_type\": \"iscsi\", \"data\": {\"target_luns\": [0], \"target_iqns\": [\"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\"], \"target_discovered\": false, \"encrypted\": false, \"target_iqn\": \"iqn.2010-10.org.openstack:volume-4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_portal\": \"192.168.10.100:3260\", \"volume_id\": \"4c1b19f4-7336-4d97-b4ab-5ea70efd39d5\", \"target_lun\": 0, \"auth_password\": \"xtZUGSxeoH7uQ34z\", \"auth_username\": \"DcL6r8st8MLzuVBapWhZ\", \"auth_method\": \"CHAP\", \"target_portals\": [\"192.168.10.100:3260\"]}}}"
        }
        staging_target_path: "/var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-c24d470e8f2e11e8/globalmount"
        target_path: "/var/lib/kubelet/pods/fca47cf0-8f2f-11e8-847c-525400059da0/volumes/kubernetes.io~csi/pvc-c24d470e8f2e11e8/mount"
        volume_capability {
          mount {
          }
          access_mode {
            mode: SINGLE_NODE_WRITER
          }
        }
        volume_attributes {
          key: "storage.kubernetes.io/csiProvisionerIdentity"
          value: "1532427201926-8081-io.ember-csi"
        }
<= 2018-07-24 10:55:34.995042 GRPC in 0s [123800944]: NodePublishVolume returns nothing
^C
```

Now that the volume has been attached to the container we can check that the pod has been successfully created:

```shell
[vagrant@master ~]$ kubectl get pod my-csi-app
NAME         READY     STATUS    RESTARTS   AGE
my-csi-app   1/1       Running   0          7m
```

When a volume is attached to a container the Ember plugin create a `connection` CRD that we can check:

```shell
[vagrant@master ~]$ kubectl get conn
NAME                                   AGE
b58dceb8-e793-4b11-b5a5-aaf1ca56d9e2   7m


[vagrant@master ~]$ kubectl describe conn
Name:         b58dceb8-e793-4b11-b5a5-aaf1ca56d9e2
Namespace:    default
Labels:       connection_id=b58dceb8-e793-4b11-b5a5-aaf1ca56d9e2
              volume_id=4c1b19f4-7336-4d97-b4ab-5ea70efd39d5
Annotations:  json={"ovo":{"versioned_object.version":"1.2","versioned_object.name":"VolumeAttachment","versioned_object.data":{"instance_uuid":null,"detach_time":null,"attach_time":null,"connection_info":{"connect...
API Version:  ember-csi.io/v1
Kind:         Connection
Metadata:
  Creation Timestamp:  2018-07-24T10:54:51Z
  Generation:          1
  Resource Version:    4284
  Self Link:           /apis/ember-csi.io/v1/namespaces/default/connections/b58dceb8-e793-4b11-b5a5-aaf1ca56d9e2
  UID:                 fdb065e5-8f2f-11e8-847c-525400059da0
Events:                <none>
```

All the different Ember CRDs, `keyvalue`, `volume`, `connection`, are grouped under the `ember` name that we can use to get all the Ember-CSI related metadata:

```shell
[vagrant@master ~]$ kubectl get ember
NAME      AGE
node0     49m
node1     49m

NAME                                   AGE
4c1b19f4-7336-4d97-b4ab-5ea70efd39d5   17m

NAME                                   AGE
b58dceb8-e793-4b11-b5a5-aaf1ca56d9e2   8m
```

The Ember CSI plugin the demo deploys has the debugging feature enabled, which allows us to get a Python console on GRPC requests.  The debugging is enabled but is turned off at start, and can be toggled using signal `USR1`.  Once the debug is on we can connect to the Ember CSI container and connect to port 4444.  Toggling debug mode on the controller node is as simple as:


```shell
[vagrant@master ~]$ kubectl exec csi-controller-0 -c csi-driver -- kill -USR1 1
```
