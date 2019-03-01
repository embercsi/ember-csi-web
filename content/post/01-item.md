+++
description = "Are you interested in Ember-CSI and want to know if your storage backend works with it? Then this article is for you. We present a step by step guide to validate a backend in Ember-CSI. From getting the right configuration to creating and using volumes in containers on a Kubernetes cluster using your backend via Ember-CSI."
thumbnail = "images/01-post-thumb.jpg"
image = "images/01-post.jpg"
title = "Driver validation"
slug = "validation"
author = "Gorka Eguileor"
draft = false
hidesidebar = true
publishDate=2019-04-10T11:13:00+02:00
+++

The Ember-CSI team is frequently asked about the supported backends and how to test Ember-CSI with a specific one.  In some cases the answer is straightforward, in other cases it's considerably more complex, so we thought it would be a good idea to write an article with all this knowledge, including a step by step guide on how we can validate that a backend works with Ember-CSI.

For the final validation we will be using [Ember-CSI's Kubernetes example] to deploy a 3 nodes Kubernetes cluster with 1 infrastructure node a 2 workload nodes.

### Supported drivers

The Ember-CSI team has tested the plugin with multiple backends, such as:

- LVM (iSCSI)
- Ceph (RBD)
- Dell EMC XtremIO (iSCSI)
- Kaminario K2 (iSCSI)
- QNAP TS-831X (iSCSI)
- NetApp (iSCSI)

Other people have confirmed compatibility of the storage driver library used by Ember-CSI with additional backends, such as:

- NetApp SolidFire (iSCSI)
- Dell EMC VMAX (iSCSI)
- Synology DS916+

So if you are looking to test Ember-CSI with any of these backends, then you are in luck, as you should be able to skip most of the steps described in this guide and, with some small changes to set your backend configuration, you'll be able to try out Ember-CSI.

You may be asking yourselves, what happens if my backend is not in any of these two lists?  How can you claim that there are over 80 storage drivers supported with such a small list?

To answer these, and hopefully other questions you may have, we will go over some Ember-CSI implementation details to explain how it supports so many different backends from different vendors.

We can get the full list of available drivers as a JSON list from the Ember-CSI container itself:

```shell
$ docker run -it --rm embercsi/ember-csi:master ember-list-drivers
[
    "ACCESSIscsi",
    "DPLFC",
    "DPLISCSI",
    "DSWARE",
    "Disco",
    "DrbdManageDrbd",
    "DrbdManageIscsi",
    "EMCCoprHDFC",
    "EMCCoprHDISCSI",
    "EMCCoprHDScaleIO",
    "FJDXFC",
    "FJDXISCSI",
    "FibreChannelVolume",
    "FlashSystemFC",
    "FlashSystemISCSI",
    "GPFS",
    "GPFSNFS",
    "GPFSRemote",
    "HGST",
    "HPE3PARFC",
    "HPE3PARISCSI",
    "HPELeftHandISCSI",
    "HPMSAFC",
    "HPMSAISCSI",
    "HuaweiFC",
    "HuaweiISCSI",
    "HyperScale",
    "IBMStorage",
    "ISCSIVolume",
    "InStorageMCSFC",
    "InStorageMCSISCSI",
    "KaminarioISCSI",
    "LVMVolume",
    "LenovoFC",
    "LenovoISCSI",
    "MStorageFC",
    "MStorageISCSI",
    "NetAppCmodeFibreChannel",
    "NetAppCmodeISCSI",
    "NetAppCmodeNfs",
    "NetAppEseriesFibreChannel",
    "NetAppEseriesISCSI",
    "NexentaEdgeISCSI",
    "NexentaISCSI",
    "NexentaNfs",
    "Nfs",
    "NimbleFC",
    "NimbleISCSI",
    "PSSeriesISCSI",
    "PureFC",
    "PureISCSI",
    "QnapISCSI",
    "Quobyte",
    "RBD",
    "SCFC",
    "SCISCSI",
    "ScaleIO",
    "Sheepdog",
    "SolidFire",
    "StorPool",
    "StorwizeSVCFC",
    "StorwizeSVCISCSI",
    "SynoISCSI",
    "Tintri",
    "Unity",
    "VMAXFC",
    "VMAXISCSI",
    "VMwareVStorageObject",
    "VMwareVcVmdk",
    "VNX",
    "VZStorage",
    "VeritasCNFS",
    "WindowsISCSI",
    "WindowsSmbfs",
    "XtremIOFC",
    "XtremIOISCSI",
    "ZFSSAISCSI",
    "ZFSSANFS",
    "ZadaraVPSAISCSI"
]
```

### Implementation details

Ember-CSI leverages two different projects to manage all the different storage backends.  One project called [Cinder] for the low level storage drivers, and another project called [cinderlib] to provide an object oriented abstraction on top of the drivers as well as a plugin mechanism to store the metadata of the different resources (volume, snapshots, attachments, etc.).

The [Cinder] project is much more than just a group of storage drivers, it is the Block Storage service within the [OpenStack] cloud operating system.  As such, its drivers were not expected to be used outside of the [Cinder] itself, so they were tightly coupled to the Cinder-volume service itself.

Here is where the [cinderlib] project comes in.  It resolves the existing issues around using the [Cinder] drivers outside of [OpenStack] and provides an object oriented abstraction of these drivers in a single library that can be used from any Python program.

There were many issues that [cinderlib] had to solve, some of which were driver specific, and that's why unless we have access to the hardware, it is not currently possible to guarantee that a driver works with [cinderlib], even if the driver is in the [Cinder] repository.  The library may require additional changes to work, or the driver may have a bug that doesn't affect [Cinder] but it does [cinderlib].  The [cinderlib] project is now part of [OpenStack] and is in the process of adding its functional tests to the existing vendor specific CIs in the [Cinder] project itself.  Once this is done, we will be able to easily confirm that Ember-CSI works with those backends, since any driver that works with [cinderlib] will work with Ember-CSI (provided external dependencies are present, more on this later).

Knowing that [cinderlib] compatibility of our backend is the key for Ember-CSI to support a storage backend, we propose a cautious approach to validating drivers that have not yet been tested.  It starts by testing the compatibility with [cinderlib] itself first, and for that we'll need to first define our driver's configuration.

### Driver configuration parameters

There are 2 ways to come up with the storage driver configuration to test [cinderlib] compatibility:

1. Automatically from an existing `cinder.conf` file.
2. Manually from [Cinder]'s or the vendor's documentation.

#### Automatically

If we have a valid `cinder.conf` file for our storage backend, we can use the [cinderlib] tool called `cinder_cfg_to_cinderlib_code.py` to generate Python code with the proper [cinderlib] `Backend` initialization.

Here's an example of running the tool with an LVM backend:

```shell
$ cat cinder.conf
[DEFAULT]
enabled_backends = lvm

[lvm]
volume_backend_name = lvm
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = lioadm

$ cp cinder.conf /tmp/cinder.conf

$ docker run -it --rm -v /tmp/cinder.conf:/etc/cinder/cinder.conf:ro embercsi/ember-csi:master python -m cinderlib.cmd.cinder_cfg_to_python
import cinderlib as cl

lvm = cl.Backend(target_protocol="iscsi", volume_driver="cinder.volume.drivers.lvm.LVMVolumeDriver", volume_backend_name="lvm", volume_group="cinder-volumes", target_helper="lioadm")

$ rm /tmp/cinder.conf
```

In the `docker run` output we can see the Python code that initializes our LVM backend, and in the call to the `Backend` class we have the [cinderlib] configuration that will allow us to control our backend.

With this we can now proceed to verify our backend driver's compatibility with [cinderlib].

This conversion tool supports `cinder.conf` files with multiple backends.  When there are multiple backends defined in the `enabled_backends` section we will see multiple `Backend` instances being assigned to Python variables.

#### Manually

If we don't have a `cinder.conf` file we can use to extract the configuration parameters we will have to rely on [Cinder's driver configuration reference](https://docs.openstack.org/cinder/rocky/configuration/block-storage/volume-drivers.html) to manually create the parameters.

For example, if we go to the [Ceph RADOS Block Device (RBD)](https://docs.openstack.org/cinder/rocky/configuration/block-storage/drivers/ceph-rbd-volume-driver.html) we can see it has a [Driver options section](https://docs.openstack.org/cinder/rocky/configuration/block-storage/drivers/ceph-rbd-volume-driver.html#driver-options).

From this section we can see we have the following configuration options:

- rados_connect_timeout
- rados_connection_interval
- rados_connection_retries
- rbd_ceph_conf
- rbd_cluster_name
- rbd_exclusive_cinder_pool
- rbd_flatten_volume_from_snapshot
- rbd_keyring_conf
- rbd_max_clone_depth
- rbd_pool
- ~~rbd_secret_uuid~~
- rbd_store_chunk_size
- rbd_user
- ~~replication_connect_timeout~~
- report_dynamic_total_capacity

Since [cinderlib] doesn't support replication we can ignore `replication_connect_timeout`, and since the `rbd_secret_uuid` is only useful for the [OpenStack] compute service we can ignore it too.

We'll assume most configuration options have reasonable defaults, which is a reasonable assumption, and focus only on the parameters that will depend on our specific backend: `rbd_ceph_conf`, `rbd_cluster_name`, `rbd_keyring_conf`, `rbd_pool`, and `rbd_user`.

Which would leave us with something like the following (it will be different for each deployment):

- `rbd_user = admin`
- `rbd_pool = rbd`
- `rbd_ceph_conf = /etc/ceph/ceph.conf`
- `rbd_keyring_conf = /etc/ceph/ceph.client.admin.keyring`
- `rbd_cluster_name = ceph`

Now, sometimes the documentation is missing things, in this case it does not specify the `volume_driver` parameter or mention the `volume_backend_name`.  That is why it is important to know that most vendors will have more extensive documentation on how to configure [Cinder] on their websites, so it is always a good idea to Google for such documentation.  For example, in this case we would search for "ceph cinder configuration" and one of the first links will be to [the Ceph website](http://docs.ceph.com/docs/mimic/rbd/rbd-openstack/), were we can find a [Cinder specific section](http://docs.ceph.com/docs/mimic/rbd/rbd-openstack/#configuring-cinder) where the missing parameters `volume_driver = cinder.volume.drivers.rbd.RBDDriver` and `volume_backend_name = ceph` are present.  Reminder, the `volume_backend_name` is an arbitrary name we can chose ourselves and must be unique for all the backends that use the same metadata persistence storage.

You could use this information directly in [cinderlib], but we recommend writing this configuration into a small `cinder.conf` file an proceeding with the automated method described above.  The reason for this is that when doing it manually we will have to make sure that we are formatting the parameters correctly, including strings between double quotes `"`, complex elements like list between brackets (`[` and `]`), etc., whereas with the automated process this will be done for us by the conversion tool, which will also do some validation of the options.

To generate the `cinder.conf` file we will use the parameters we have, and add the `enabled_backends` parameter, under the `[DEFAULT]` section, with whatever name we want to use to describe our backend, and then create a section with that name.  The end result would look like this:

```ini
[DEFAULT]
enabled_backends = rbd

[rbd]
volume_backend_name = ceph
volume_driver = cinder.volume.drivers.rbd.RBDDriver
rbd_user = admin`
rbd_pool = rbd
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_keyring_conf = /etc/ceph/ceph.client.admin.keyring
rbd_cluster_name = ceph
```

After writing this into a `cinder.conf` file we run the `cinder-cfg-to-python` tool:

```shell
$ cp cinder.conf /tmp/cinder.conf

$ docker run -it --rm -v /tmp/cinder.conf:/etc/cinder/cinder.conf:ro embercsi/ember-csi:master python -m cinderlib.cmd.cinder_cfg_to_python
import cinderlib as cl

ceph = cl.Backend(rbd_keyring_conf="/etc/ceph/ceph.client.admin.keyring", rbd_ceph_conf="/etc/ceph/ceph.conf", rbd_cluster_name="ceph", volume_backend_name="ceph", volume_driver="cinder.volume.drivers.rbd.RBDDriver", rbd_pool="rbd", rbd_user="admin`")

$ rm /tmp/cinder.conf
```

**For the purpose of validating a driver we recommend not using multipathing until the last step of this guide, where we do a full deployment, so if the output of the configuration includes the line `use_multipath_for_image_xfer=True` then please change it to `False` for the following steps.**

### Driver compatibility

Now that we have the driver configuration we will go ahead and confirm that our driver configuration is valid while checking the driver's compatibility with [cinderlib].

We can do this in two ways, directly on the host or using a container.  Each one of these approaches has its own advantages and disadvantages.  The best approach is probably fail and error, where we first try with the container approach, and if we encounter difficulties we can't figure out we fall back to the host approach to see if it is related to the mounted volumes and/or container privileges or if it's something else.  If we decide to go with the host approach first, it would be a good idea to also try the containerized way afterwards, as this will help us confirm that the way we are running containers is compatible with the driver.

**Our recommendation is to run these commands on a CentOS 7 VM instead of our real host, and use a specific testing pool in you backend to facilitate cleaning things up at the end.  That way we will not pollute our host and we'll also be sure we are not relying on pre-existing packages in our system.**

#### Cinderlib on the host

For the host approach we will have to install:

- [Cinder]
- [cinderlib]
- Storage transport tools
- Driver specific dependencies

We can install [Cinder] in 2 different ways, from [its repository](https://github.com/openstack/cinder) or using RPM packages.

Assuming the host is a CentOS machine we will use the [RDO](https://rdo.org/) RPM packages to install [Cinder] using the latest repository to make sure we have the latest version of the Cinder backend driver and cinderlib code:

```shell
$ curl -o /etc/yum.repos.d/rdo-trunk-runtime-deps.repo https://trunk.rdoproject.org/centos7-master/rdo-trunk-runtime-deps.repo
$ curl -o /etc/yum.repos.d/delorean.repo https://trunk.rdoproject.org/centos7-master/current/delorean.repo
$ sudo yum -y install python-cinderlib
```

Don't be surprised by the number of dependencies pulled by the `python-cinderlib` package.  We are working on decreasing it by splitting the `openstack-cinder` package into a common code package that can be used by [Cinder] and [cinderlib], and having each one of these packages have their independent dependencies.

If our system is not CentOS we can install [Cinder] and [cinderlib] from the repositories to test on the host, though this will not be possible for running it from a container:

**This step is not necessary if we already `yum` installed the RDO package.**

```shell
$ sudo pip install git+https://github.com/openstack/cinder.git
$ sudo pip install git+https://github.com/openstack/cinderlib.git
```

Now we need to install required storage transport tools.  For example, if our backend uses iSCSI as the transport protocol we would do:

```shell
$ sudo yum -y install iscsi-initiator-utils
$ sudo systemctl start iscsid
```

Now, with [Cinder] and [cinderlib] installed, we can check the list of available drivers in our system:

```shell
$ python -c 'import cinderlib as cl; print("\n".join(cl.list_supported_drivers().keys()))'
```

The last step in the preparation of the host is making sure our system has all the external dependencies required by our storage backend driver.  For example Ceph/RBD requires the package `ceph-common`, 3PAR requires the `python-3parclient` PyPi package, Pure `purestorage`, IBM XIV `pyxcli` and `pyOpenSSL`.  The [Cinder] project keeps a [list of PyPi package dependencies by driver](https://github.com/openstack/cinder/blob/master/driver-requirements.txt), and some drivers also describe these dependencies in their [OpenStack documentation](https://docs.openstack.org/cinder/rocky/configuration/block-storage/volume-drivers.html).

For example, if we were using HPE 3PAR we would do:

```shell
$ sudo pip install 'python-3parclient>=4.0,<5.0'
```

**Note:** It is important to take note of the packages and external files we are adding in order to run cinderlib with our backend, as we'll need it for later.

We are now finally ready to manually test the driver compatibility, and we'll use Python's interactive interpreter and the output of the `cinder_cfg_to_python` output to create a volume, attach a volume, create a snapshot, delete a snapshot, detach a volume and, finally, delete the volume.

**Note:** You must use a user to run the tests that has passwordless `sudo` privileges or `root` itself.

Let's have a look at how it looks like for the LVM backend assuming we have already setup the LVM VG beforehand:

```python
$ python
Python 2.7.5 (default, Apr 11 2018, 07:36:10)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-28)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import cinderlib as cl
>>> lvm = cl.Backend(target_protocol="iscsi",
                     volume_driver="cinder.volume.drivers.lvm.LVMVolumeDriver",
                     volume_backend_name="lvm",
                     volume_group="cinder-volumes",
                     target_helper="lioadm")
>>> v = lvm.create_volume(1)
>>> print('Volume size is %s' % v.size)
Volume size is 1
>>> a = v.attach()
>>> print('Path is %s' % a.path)
Path is /dev/sda
>>> s = v.create_snapshot()
>>> s.delete()
>>> v.detach()
>>> v.delete()
```

If everything goes well you'll be able to perform all of the above operations successfully.  If you are not so fortunate and something goes wrong then these are our troubleshooting recommendations:

- Double check the configuration.
- Carefully read returned error in case there is useful information.
- Enable debug logs and see if there is something helpful in them.
- Come to the IRC #openstack-cinder channel on Freenode (you can directly ping geguileo)
- Send an email to the [discuss-openstack mailing list](http://lists.openstack.org/cgi-bin/mailman/listinfo/openstack-discuss) starting the subject with "[cinderlib]"

To enable debug logs we just need to make a call to [cinderlib]'s `setup` right after importing the library with parameters `disable_logs=False` and `debug=True`.  Here's the same Python code as before, now with debugging logs enabled:

```python
$ python
Python 2.7.5 (default, Apr 11 2018, 07:36:10)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-28)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import cinderlib as cl
>>> cl.setup(disable_logs=False, debug=True)
>>> lvm = cl.Backend(target_protocol="iscsi",
                     volume_driver="cinder.volume.drivers.lvm.LVMVolumeDriver",
                     volume_backend_name="lvm",
                     volume_group="cinder-volumes",
                     target_helper="lioadm")
2019-03-01 12:02:30.197 4558 DEBUG cinder.volume.drivers.lvm [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Attempting to initialize LVM driver with the following target_driver: cinder.volume.targets.lio.LioAdm __init__ /usr/lib/python2.7/site-packages/cinder/volume/drivers/lvm.py:103
2019-03-01 12:02:30.204 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): cinder-rtstool verify execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.365 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "cinder-rtstool verify" returned: 0 in 0.161s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.366 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.388 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --version" returned: 0 in 0.022s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.390 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --noheadings -o name cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.418 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --noheadings -o name cinder-volumes" returned: 0 in 0.028s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.419 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.448 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.029s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.449 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.472 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --version" returned: 0 in 0.023s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.474 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo lvchange -a y --yes -K cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.504 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo lvchange -a y --yes -K cinder-volumes/cinder-volumes-pool" returned: 0 in 0.030s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.505 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.529 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --version" returned: 0 in 0.024s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.530 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C pvs --noheadings --unit=g -o vg_name,name,size,free --separator | --nosuffix --ignoreskippedcluster execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.566 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C pvs --noheadings --unit=g -o vg_name,name,size,free --separator | --nosuffix --ignoreskippedcluster" returned: 0 in 0.035s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.567 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.592 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.025s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.594 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.619 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.026s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.620 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.649 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.029s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.650 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.679 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool" returned: 0 in 0.029s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.680 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.700 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --version" returned: 0 in 0.020s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.702 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.730 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.029s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.731 4558 INFO cinder.volume.drivers.lvm [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Enabling LVM thin provisioning by default because a thin pool exists.
2019-03-01 12:02:30.732 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.753 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --version" returned: 0 in 0.021s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.754 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.781 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.027s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.782 4558 DEBUG cinder.volume.drivers.lvm [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Updating volume stats _update_volume_stats /usr/lib/python2.7/site-packages/cinder/volume/drivers/lvm.py:192
2019-03-01 12:02:30.782 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.810 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.028s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.811 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.837 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.026s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.838 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.871 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool" returned: 0 in 0.032s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.872 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Running cmd (subprocess): sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 12:02:30.898 4558 DEBUG oslo_concurrency.processutils [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] CMD "sudo env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.026s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 12:02:30.899 4558 DEBUG cinder.volume.driver [req-6b68953e-0a53-4a8a-9ac8-b4ac49045146 cinderlib cinderlib - - -] Initialized capabilities list: {'driver_version': '3.0.0', 'sparse_copy_volume': True, 'pools': [{'pool_name': 'lvm', 'filter_function': None, 'goodness_function': None, 'total_volumes': 1, 'provisioned_capacity_gb': 0.0, 'multiattach': True, 'thin_provisioning_support': True, 'free_capacity_gb': 20.9, 'location_info': 'LVMVolumeDriver:localhost.localdomain:cinder-volumes:thin:0', 'total_capacity_gb': 20.9, 'thick_provisioning_support': False, 'reserved_percentage': 0, 'QoS_support': False, 'max_over_subscription_ratio': '20.0', 'backend_state': 'up'}], 'shared_targets': False, 'vendor_name': 'Open Source', 'volume_backend_name': 'lvm', 'properties': {'replication_enabled': {'type': 'boolean', 'description': u'Enables replication.', 'title': 'Replication'}, 'qos': {'type': 'boolean', 'description': u'Enables QoS.', 'title': 'QoS'}, 'compression': {'type': 'boolean', 'description': u'Enables compression.', 'title': 'Compression'}, 'thin_provisioning': {'type': 'boolean', 'description': u'Sets thin provisioning.', 'title': 'Thin Provisioning'}}, 'storage_protocol': 'iSCSI'}. init_capabilities /usr/lib/python2.7/site-packages/cinder/volume/driver.py:771
>>>
```

#### Cinderlib on a container

The main differences between running [cinderlib] in a container instead of directly on the host are:

- [Cinder] is already installed
- [cinderlib] is already installed
- Some driver dependencies are already installed, such as Kaminaro's, Pure's, RBD's, IBM's XIV...
- We need Docker installed and running
- We have to mount a good number of directories from the host for the container to work.

We also recommend running the container inside a CentOS VM instead of directly on our host.

First we'll install Docker:

```shell
$ sudo yum install -y docker
$ sudo systemctl start docker
```

Now we need to install required storage transport tools on the host.  For example, if our backend uses iSCSI as the transport protocol we would do:

```shell
$ sudo yum install -y iscsi-initiator-utils
$ sudo systemctl start iscsid
```

On an Ember-CSI container we'll be using an interactive terminal to run Python's interactive interpreter to manually verify that the code generated using `cinder_cfg_to_python.py` works and we can create a volume, attach it, create and delete a snapshot, detach the volume, and finally delete it.

Here is an example of how running the container for an iSCSI backend looks like:

```shell
$ sudo docker run -it --name=cinderlib --privileged --net=host \
> -v /etc/iscsi:/etc/iscsi \
> -v /dev:/dev \
> -v /etc/lvm:/etc/lvm \
> -v /var/lock/lvm:/var/lock/lvm \
> -v /lib/modules:/lib/modules:ro \
> -v /run/udev:/run/udev \
> -v /var/lib/iscsi:/var/lib/iscsi \
> -v /etc/localtime:/etc/localtime:ro \
> embercsi/ember-csi:master \
> /bin/bash
Unable to find image 'embercsi/ember-csi:master' locally
Trying to pull repository docker.io/embercsi/ember-csi ...
latest: Pulling from docker.io/embercsi/ember-csi
a02a4930cb5d: Pull complete
c3f23e23c56d: Pull complete
1383c88742c3: Pull complete
7db1aa6bfbef: Pull complete
687908c02c8e: Pull complete
7933b36934cc: Pull complete
e129bae24b5f: Pull complete
Digest: sha256:bd1dcf87870eea5d3ea89945c41b37cd5b5f9eef226e026aab18db4d5598bc6a
Status: Downloaded newer image for docker.io/embercsi/ember-csi:master
[root@localhost /]#
```

Now we can check that [Cinder] and [cinderlib] are present in the container by listing available drivers:

```shell
[root@localhost /]# python -c 'import cinderlib as cl; print("\n".join(cl.list_supported_drivers().keys()))'
```

Before we can see if the driver works as expected, we have make sure that the container has the external dependencies required by our storage backend driver.  For example Ceph/RBD requires the package `ceph-common`, 3PAR requires the `python-3parclient` PyPi package, Pure `purestorage`, IBM XIV `pyxcli` and `pyOpenSSL`.  The [Cinder] project keeps a [list of PyPi package dependencies by driver](https://github.com/openstack/cinder/blob/master/driver-requirements.txt) and some drivers also describe these dependencies in their [OpenStack documentation](https://docs.openstack.org/cinder/rocky/configuration/block-storage/volume-drivers.html).  The Ember-CSI container already has some dependencies included, so you may not need to install anything.

For example if we were using HPE 3PAR we would do:

```shell
[root@localhost /]# sudo pip install 'python-3parclient>=4.0,<5.0'
```

**Note:** It is important to take note of the packages and external files we are adding in order to run cinderlib with our backend, as we'll need it for later.

Now we are finally ready to manually test the driver compatibility, so let's have a look at how it would look like for the LVM backend and assume this will not be the backend used, as we would need to actually set the LVM VG before hand, change the hosts `/etc/lvm/lvm.conf` and mount additional directories:

```python
[root@localhost /]# python
Python 2.7.5 (default, Oct 30 2018, 23:45:53)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-36)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import cinderlib as cl
>>> lvm = cl.Backend(target_protocol="iscsi",
                     volume_driver="cinder.volume.drivers.lvm.LVMVolumeDriver",
                     volume_backend_name="lvm",
                     volume_group="cinder-volumes",
                     target_helper="lioadm")
>>> v = lvm.create_volume(1)
>>> print('Volume size is %s' % v.size)
Volume size is 1
>>> a = v.attach()
>>> print('Path is %s' % a.path)
Path is /dev/sda
>>> s = v.create_snapshot()
>>> s.delete()
>>> v.detach()
>>> v.delete()
```

If everything goes well you'll be able to perform all of the above operations successfully.  If you are not so fortunate and something goes wrong then these are our recommendations:

- Double check the configuration.
- Carefully read returned error in case there is useful information.
- Enable debug logs and see if there is something helpful in them.
- Try to run these same tests on the host instead of in a container.
- Come to the IRC #openstack-cinder channel on Freenode (you can directly ping geguileo)
- Send an email to the [discuss-openstack mailing list](http://lists.openstack.org/cgi-bin/mailman/listinfo/openstack-discuss) starting the subject with "[cinderlib]"

To enable debug logs we just need to make a call to [cinderlib]'s `setup` right after importing the library:

```python
[root@localhost /]# python
Python 2.7.5 (default, Oct 30 2018, 23:45:53)
[GCC 4.8.5 20150623 (Red Hat 4.8.5-36)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import cinderlib as cl
>>> cl.setup(disable_logs=False, debug=True)
>>> lvm = cl.Backend(target_protocol="iscsi",
...                  volume_driver="cinder.volume.drivers.lvm.LVMVolumeDriver",
...                  volume_backend_name="lvm",
...                  volume_group="cinder-volumes",
...                  target_helper="lioadm")
2019-03-01 13:11:28.609 204 DEBUG cinder.volume.drivers.lvm [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Attempting to initialize LVM driver with the following target_driver: cinder.volume.targets.lio.LioAdm __init__ /usr/lib/python2.7/site-packages/cinder/volume/drivers/lvm.py:103
2019-03-01 13:11:28.615 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): cinder-rtstool verify execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:29.268 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "cinder-rtstool verify" returned: 0 in 0.654s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:29.270 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:29.758 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --version" returned: 0 in 0.488s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:29.759 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --noheadings -o name cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:30.269 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --noheadings -o name cinder-volumes" returned: 0 in 0.510s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:30.270 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:30.764 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.494s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:30.765 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:31.264 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --version" returned: 0 in 0.499s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:31.265 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): lvchange -a y --yes -K cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:31.766 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "lvchange -a y --yes -K cinder-volumes/cinder-volumes-pool" returned: 0 in 0.501s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:31.767 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:32.262 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --version" returned: 0 in 0.495s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:32.263 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C pvs --noheadings --unit=g -o vg_name,name,size,free --separator | --nosuffix --ignoreskippedcluster execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:32.777 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C pvs --noheadings --unit=g -o vg_name,name,size,free --separator | --nosuffix --ignoreskippedcluster" returned: 0 in 0.514s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:32.778 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:33.283 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.505s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:33.284 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:33.792 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.508s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:33.793 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:34.303 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.510s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:34.304 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:34.809 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool" returned: 0 in 0.505s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:34.810 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:35.308 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --version" returned: 0 in 0.498s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:35.308 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:35.826 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.517s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:35.827 204 INFO cinder.volume.drivers.lvm [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Enabling LVM thin provisioning by default because a thin pool exists.
2019-03-01 13:11:35.828 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --version execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:36.343 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --version" returned: 0 in 0.515s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:36.344 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:36.850 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes/cinder-volumes-pool" returned: 0 in 0.506s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:36.852 204 DEBUG cinder.volume.drivers.lvm [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Updating volume stats _update_volume_stats /usr/lib/python2.7/site-packages/cinder/volume/drivers/lvm.py:192
2019-03-01 13:11:36.852 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:37.359 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C vgs --noheadings --unit=g -o name,size,free,lv_count,uuid --separator : --nosuffix cinder-volumes" returned: 0 in 0.507s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:37.360 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:37.870 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.511s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:37.872 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:38.385 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o size,data_percent --separator : --nosuffix /dev/cinder-volumes/cinder-volumes-pool" returned: 0 in 0.513s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:38.387 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Running cmd (subprocess): env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:372
2019-03-01 13:11:38.913 204 DEBUG oslo_concurrency.processutils [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] CMD "env LC_ALL=C lvs --noheadings --unit=g -o vg_name,name,size --nosuffix cinder-volumes" returned: 0 in 0.526s execute /usr/lib/python2.7/site-packages/oslo_concurrency/processutils.py:409
2019-03-01 13:11:38.914 204 DEBUG cinder.volume.driver [req-0d9eed8e-3cf4-4e31-8919-131a3394099c cinderlib cinderlib - - -] Initialized capabilities list: {'driver_version': '3.0.0', 'sparse_copy_volume': True, 'pools': [{'pool_name': 'lvm', 'filter_function': None, 'goodness_function': None, 'total_volumes': 1, 'provisioned_capacity_gb': 0.0, 'multiattach': True, 'thin_provisioning_support': True, 'free_capacity_gb': 20.9, 'location_info': 'LVMVolumeDriver:localhost.localdomain:cinder-volumes:thin:0', 'total_capacity_gb': 20.9, 'thick_provisioning_support': False, 'reserved_percentage': 0, 'QoS_support': False, 'max_over_subscription_ratio': '20.0', 'backend_state': 'up'}], 'shared_targets': False, 'vendor_name': 'Open Source', 'volume_backend_name': 'lvm', 'properties': {'replication_enabled': {'type': 'boolean', 'description': u'Enables replication.', 'title': 'Replication'}, 'qos': {'type': 'boolean', 'description': u'Enables QoS.', 'title': 'QoS'}, 'compression': {'type': 'boolean', 'description': u'Enables compression.', 'title': 'Compression'}, 'thin_provisioning': {'type': 'boolean', 'description': u'Sets thin provisioning.', 'title': 'Thin Provisioning'}}, 'storage_protocol': 'iSCSI'}. init_capabilities /usr/lib/python2.7/site-packages/cinder/volume/driver.py:771
>>>
```

### Getting the Ember-CSI demo

Congratulations!  If you have reached this point it means that your backend is compatible with [cinderlib], and therefore with Ember-CSI as well.  The rest of the process should not be a problem.

For this part of the process it's easier to run it on our own host, since you probably already have all dependencies installed and we'll be creating 3 VMs anyway.  You can still run it inside a VM, as long as you have properly enabled nested virtualization.

To run the example we'll need `git`, `ansible`, `qemu-kvm`, `libvirt`, `vagrant` and `vagrant-libvirt`.  Which you can get installed on Fedora with:

```shell
$ sudo dnf -y install git qemu-kvm libvirt vagrant vagrant-libvirt ansible
$ sudo systemctl start libvirtd
```

For CentOS it is a little bit more complicated, but still reasonable:

```shell
$ sudo dnf -y install epel-release
$ sudo yum -y install qemu-kvm libvirt ansible gcc libvirt-devel
$ sudo yum -y install https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.rpm
$ sudo vagrant plugin install vagrant-libvirt
$ sudo systemctl start libvirtd
```

And now that we have the example requirements we proceed to download the Ember-CSI repository to have the example:

```shell
$ git clone git@github.com:embercsi/ember-csi.git
$ cd ember-csi/examples/k8s_v1.13-CSI_v1.0
```

### Setting Ember-CSI's configuration

The configuration required by Ember-CSI is the same as the one we used for [cinderlib], just on a different format.  For [cinderlib] we used Python types, and for Ember-CSI we must use a JSON string.  The fastest way to get the right string is to serialize the configuration that is currently being used in the [cinderlib] `Backend` instance in our Python interpreter.

It would look like this in our LVM example where the backend is called `lvm`:

```python
>>> import json
>>> json.dumps(lvm._driver_cfg, separators=(',', ':'))
'{"target_protocol":"iscsi","volume_driver":"cinder.volume.drivers.lvm.LVMVolumeDriver","volume_backend_name":"lvm","volume_group":"cinder-volumes","target_helper":"lioadm"}'
>>>
```

Now we copy that string, since it'll be the one we use for Ember-CSI, because even though Ember-CSI supports a simpler configuration and we could replace `"volume_driver":"cinder.volume.drivers.lvm.LVMVolumeDriver"` with `"driver":"LVMVolume"`, and `"volume_backend_name":"lvm"` with `"name":"lvm"` leaving us with:

```python
 `'{"target_protocol":"iscsi","driver":"LVMVolume","name":"lvm","volume_group":"cinder-volumes","target_helper":"lioadm"}'`
```

In our case there is no need to do this, since Ember-CSI also accepts the exact same configuration as [cinderlib], and it is more convenient for us that we have a [cinderlib] configuration already as a JSON string to use what we have.

With that configuration we replace the `ember_lvm_config` section in the `global_vars.yml` file.


### Ember-CSI image

Now that we have been able to use [cinderlib] to access our storage backend we know that we can use it in Ember-CSI, and we have all the information we need to use our storage in Kubernetes using Ember-CSI, as we have:

- Driver configuration
- List of external dependencies we had to install to make [cinderlib] work

But we need to determine if the standard [Ember-CSI image] supports our storage backend off the bat, or if we need to make some adjustments to it.

As we mentioned before Ember-CSI includes dependencies for some drivers and there are also many drivers that don't have external dependencies, so how can we tell if we can use the image as it is?

As one would expect, you can use the image as it is if you didn't have to install any dependencies, and if you had to install some packages you just have to check if they are already available in the image looking at the [Dockerfile] or manually exploring the image itself (`docker run -it --rm embercsi/ember-csi:master /bin/bash`).

If you have been fortunate enough to have the dependencies, you can skip to the [next section](#testing-in-a-container), if you haven't you'll have to create your custom image to include those dependencies, but don't worry, it's pretty easy.

#### Building a custom image

To build a custom image we will create a `Dockerfile.custom` file, base our image on the `embercsi/ember-csi:master` image, and add the commands we run before to install our dependencies.

Here's how it would look like for the HPE 3PAR driver that only needs to install the `python-3parclient` Python library:

```shell
$ cat Dockerfile.custom
FROM embercsi/ember-csi:master
RUN pip install 'python-3parclient>=4.0,<5.0'
```

Some backends also need additional configuration files, for example Ceph, that requires credential files.  In those cases we can either include those files in our custom image adding the appropriate `COPY` command to the Dockerfile, or replace the `roles/master/files/system-files.tar` file (the contents must be from the root directory).  We recommend using recommend including the files in the custom image as it is simpler. You don't have to worry about real deployments, because in those cases we would use secrets and the `X_CSI_SYSTEM_FILES` Ember-CSI parameter.

And now we build the image and tag it as `ember-csi:custom`:

```shell
$ docker build -t ember-csi:custom -f Dockerfile.custom .
Sending build context to Docker daemon 1.382 MB
Step 1/2 : FROM embercsi/ember-csi:master
 ---> 308aca736db3
Step 2/2 : RUN pip install 'python-3parclient>=4.0,<5.0'
 ---> Running in fe53bc3f2ba6
Collecting python-3parclient<5.0,>=4.0
  Downloading https://files.pythonhosted.org/packages/2e/53/7de45eb87bdb6599f32d78cac5b50cb3493d35fef6d5082749ac412bc9f5/python-3parclient-4.2.9.tar.gz (118kB)
Requirement already satisfied (use --upgrade to upgrade): paramiko in /usr/lib/python2.7/site-packages (from python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): eventlet in /usr/lib/python2.7/site-packages (from python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): requests in /usr/lib/python2.7/site-packages (from python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): cryptography>=1.5 in /usr/lib64/python2.7/site-packages (from paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): pynacl>=1.0.1 in /usr/lib64/python2.7/site-packages (from paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): pyasn1>=0.1.7 in /usr/lib/python2.7/site-packages (from paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): bcrypt>=3.1.3 in /usr/lib64/python2.7/site-packages (from paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): monotonic>=1.4 in /usr/lib/python2.7/site-packages (from eventlet->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): six>=1.10.0 in /usr/lib/python2.7/site-packages (from eventlet->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): dnspython>=1.15.0 in /usr/lib/python2.7/site-packages (from eventlet->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): greenlet>=0.3 in /usr/lib64/python2.7/site-packages (from eventlet->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): enum34; python_version < "3.4" in /usr/lib/python2.7/site-packages (from eventlet->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): urllib3<1.25,>=1.21.1 in /usr/lib/python2.7/site-packages (from requests->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): chardet<3.1.0,>=3.0.2 in /usr/lib/python2.7/site-packages (from requests->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): idna<2.9,>=2.5 in /usr/lib/python2.7/site-packages (from requests->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): certifi>=2017.4.17 in /usr/lib/python2.7/site-packages (from requests->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): asn1crypto>=0.21.0 in /usr/lib/python2.7/site-packages (from cryptography>=1.5->paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): cffi!=1.11.3,>=1.8 in /usr/lib64/python2.7/site-packages (from cryptography>=1.5->paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): ipaddress; python_version < "3" in /usr/lib/python2.7/site-packages (from cryptography>=1.5->paramiko->python-3parclient<5.0,>=4.0)
Requirement already satisfied (use --upgrade to upgrade): pycparser in /usr/lib/python2.7/site-packages (from cffi!=1.11.3,>=1.8->cryptography>=1.5->paramiko->python-3parclient<5.0,>=4.0)
Installing collected packages: python-3parclient
  Running setup.py install for python-3parclient: started
    Running setup.py install for python-3parclient: finished with status 'done'
Successfully installed python-3parclient-4.2.9
You are using pip version 8.1.2, however version 19.0.3 is available.
You should consider upgrading via the 'pip install --upgrade pip' command.
 ---> 0859f46d0c44
Removing intermediate container fe53bc3f2ba6
Successfully built 0859f46d0c44
```

With this we now have a custom Ember-CSI image that includes the necessary dependencies for our storage backend.

#### Testing the image

This step is not strictly necessary, but it is a nice one for those who want to do a sanity check on the image they've just built.

To check our image we'll run the Ember-CSI container locally and use the [Container Storage Client], csc for shorts, to request a couple of basic operations on Ember-CSI.

First we run the Ember-CSI container on port 50051 using the configuration JSON string we generated earlier (we assume it's stored in `CINDERLIB_CONFIG`) and confirm that the service is able to start and initialize the driver:

```shell
$ docker run --name=ember -d \
> -p 50051:50051 \
> -e CSI_MODE=controller  \
> -e X_CSI_SPEC_VERSION=v1 \
> -e X_CSI_PERSISTENCE_CONFIG='{"storage":"memory"}' \
> -e X_CSI_BACKEND_CONFIG=$CINDERLIB_CONFIG \
> ember-csi:custom
74e5eacc721cdb381215f4f5a7ce62746c6cc818a0da21695e49e1f78d5e613a

$ docker logs ember
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Ember CSI v0.0.2 with 30 workers (CSI spec: v1.0.0, cinderlib: v0.3.10.dev10, cinder: v13.1.0.dev926)
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Persistence module: MemoryPersistence
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Running as controller with backend KaminarioISCSIDriver v1.4
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Plugin name: ember-csi.io
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Supported filesystems: minix, cramfs, btrfs, ext4, ext3, xfs, ext2
2019-04-05 13:44:20 default INFO ember_csi.ember_csi [-] Now serving on [::]:50051...
```

Now we will issue 3 simple commands:

- Get the plugin info: To confirm CSC is communicating with the Ember-CSI plugin via gRPC.
- Create a volume: To confirm that Ember-CSI can communicate with out storage backend.
- Delete the volume: To clean up

With this basic sanity check we'll be able to confirm that Ember-CSI not only starts successfully, but it is also able to connect to our storage backend.

The UUID value we assign to `vol_id` for the delete operation is the first value returned by the volume creation operation.

```shell
$ docker run --network=host --rm -it embercsi/csc identity plugin-info -e tcp://127.0.0.1:50051
"ember-csi.io"  "0.0.2" "cinder-driver"="KaminarioISCSIDriver"  "cinder-driver-supported"="True"        "cinder-driver-version"="1.4"   "cinder-version"="13.1.0.dev926"        "cinderlib-version"="0.3.10.dev10"     "mode"="controller"     "persistence"="MemoryPersistence"

$ docker run --network=host --rm -it embercsi/csc controller create-volume --cap SINGLE_NODE_WRITER,block --req-bytes 2147483648 disk -e tcp://127.0.0.1:50051
"d2382978-fbdc-4abd-8049-a7a5bbb8c0d5"  2147483648

$ vol_id=d2382978-fbdc-4abd-8049-a7a5bbb8c0d5

$ docker run --network=host --rm -it embercsi/csc controller delete-volume $vol_id -e tcp://127.0.0.1:50051
d2382978-fbdc-4abd-8049-a7a5bbb8c0d5
```

Now we can stop the `ember` container:

```shell
$ docker rm -f ember
```

#### Making the image available

Now that we have built and tested the image, we have to make it available for the VMs that will be running the Kubernetes cluster.  We can do this 2 ways:

- Publishing it to a public registry
- Publishing to our own local registry

Both ways are valid and it will only depend on your own preferences which one you want to use, unless you have added configuration files that have sensitive data, in which case you must use the local registry in order to keep this information confidential.

To publish to a public registry we just retag the image and push it.  For example if our Docker Hub user was called `cooluser` we would do:

```shell
$ docker tag ember-csi:custom cooluser/ember-csi:custom
$ docker push cooluser/ember-csi:custom
```

And if we want to publish it to a local registry we can use the `registry` container and our local IP, for example if it were `192.168.1.7` it would be like this:

```shell
$ docker run -d -p 5000:5000 --name registry registry:2
$ docker tag ember-csi:custom 192.168.1.7:5000/ember-csi:custom
$ docker push 192.168.1.7:5000/ember-csi:custom
```

With this, our custom image can now be consumed by the example.

#### Using the custom image

We must make some changes to the example in order to uses this custom image on the deployment.

Edit file `global_vars.yml` and replace `ember_image` with our custom image.

From:

```
ember_image: embercsi/ember-csi:master
```

To:

```
ember_image: cooluser/ember-csi:custom
```

And if we are using a local registry we must also replace `ember_insecure_registry`.  In the example we mentioned earlier this would result in the following:

```
ember_image: 192.168.1.7:5000/ember-csi:custom
ember_insecure_registry: 192.168.1.7:5000
```

And now our own image will be used when we run the example and we are ready to deploy a full Kubernetes cluster that uses our storage backend.

### Deploying Kubernetes

At this point we have prepared our system to run the Kubernetes + Ember-CSI example, we have verified that our storage works with cinderlib, set our backend configuration for the example, and we know which Ember-CSI container image we must use and have set it in the example, so all that's left to do is actually run the example and confirm that everything works fine in a real Kubernetes deployment.

To run the example we have a simple bash script called `up.sh` in the `examples/k8s_v1.13-CSI_v1.0` directory where we had modified the `global_vars.yml` file.  This script creates the 3 VMs using vagrant, and then provisions them using Ansible to deploy Kubernetes 1.13, then creates an LVM VG, then deploys 2 Ember-CSI plugins, one using the LVM VG, and another with a toy Ceph cluster, finally it will create the storage classes for the volumes and snapshots.

It will take a while to run, so must be patient:

```shell
$ ./up.sh
Bringing machine 'master' up with 'libvirt' provider...
Bringing machine 'node0' up with 'libvirt' provider...
Bringing machine 'node1' up with 'libvirt' provider...
==> master: Checking if box 'centos/7' is up to date...
==> node1: Checking if box 'centos/7' is up to date...
==> node0: Checking if box 'centos/7' is up to date...


[ . . . ]


PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [node0]
ok: [node1]
ok: [master]

TASK [common : update] *********************************************************
changed: [node0]
changed: [master]
changed: [node1]

TASK [wait_for] ****************************************************************
ok: [master -> localhost]

TASK [Create CRD for the CSIDriverRegistry feature] ****************************
changed: [master]

TASK [Create CRD for the CSINodeInfo feature] **********************************
changed: [master]

TASK [wait_for] ****************************************************************
ok: [master -> localhost]

TASK [Set CSI LVM controller] **************************************************
changed: [master]

TASK [wait_for] ****************************************************************
ok: [master -> localhost]

TASK [Start CSI LVM nodes] *****************************************************
changed: [master]

TASK [Create LVM Storage Class] ************************************************
changed: [master]

TASK [wait_for] ****************************************************************
ok: [master -> localhost]

TASK [Create LVM Snapshot Storage Class] ***************************************
changed: [master]
changed: [master]

TASK [Set CSI Ceph controller] *************************************************
changed: [master]

TASK [Start CSI Ceph nodes] ****************************************************
changed: [master]

TASK [Create Ceph Storage Class] ***********************************************
changed: [master]

TASK [Create Ceph Snapshot Storage Class] **************************************
changed: [master]

TASK [wait_for] ****************************************************************
ok: [master -> localhost]

TASK [Change Ceph default features] ********************************************
changed: [master]

PLAY RECAP *********************************************************************
master                     : ok=69   changed=57   unreachable=0    failed=0
node0                      : ok=22   changed=20   unreachable=0    failed=0
node1                      : ok=22   changed=20   unreachable=0    failed=0
```

Now we go into the infrastructure `master` node to check our deployment:

```shell
$ vagrant ssh master


[vagrant@master ~]$ kubectl get pod csi-controller-0 csi-rbd-0
NAME               READY   STATUS    RESTARTS   AGE
csi-controller-0   6/6     Running   0          8m50s
NAME               READY   STATUS    RESTARTS   AGE
csi-rbd-0          7/7     Running   1          4m12s


Check the logs of the CSI *controller* to see that its running as expected:

```shell
[vagrant@master ~]$ kubectl logs csi-controller-0 -c csi-driver
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Ember CSI v0.0.2 with 30 workers (CSI spec: v1.0.0, cinderlib: v0.3.10.dev4, cinder: v13.1.0.dev902)
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Persistence module: CRDPersistence
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Running as controller with backend LVMVolumeDriver v3.0.0
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Supported filesystems: cramfs, minix, btrfs, ext2, ext3, ext4, xfs
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Now serving on unix:///csi-data/csi.sock...
2019-02-14 14:17:03 default INFO ember_csi.common [req-15807873-3e8a-4107-b41a-6bd63ebdccb8] => GRPC GetPluginInfo
2019-02-14 14:17:03 default INFO ember_csi.common [req-15807873-3e8a-4107-b41a-6bd63ebdccb8] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:17:03 default INFO ember_csi.common [req-b0ab521b-fd7a-41f6-a03e-3328ebe3a6da] => GRPC Probe
2019-02-14 14:17:03 default INFO ember_csi.common [req-b0ab521b-fd7a-41f6-a03e-3328ebe3a6da] <= GRPC Probe served in 0s
2019-02-14 14:17:03 default INFO ember_csi.common [req-500d03fb-40d6-4eca-8188-07d2b2d6905c] => GRPC ControllerGetCapabilities
2019-02-14 14:17:03 default INFO ember_csi.common [req-500d03fb-40d6-4eca-8188-07d2b2d6905c] <= GRPC ControllerGetCapabilities served in 0s
2019-02-14 14:17:04 default INFO ember_csi.common [req-965509cc-2053-4257-afa9-d8d4ea3eeaf1] => GRPC GetPluginInfo
2019-02-14 14:17:04 default INFO ember_csi.common [req-965509cc-2053-4257-afa9-d8d4ea3eeaf1] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:17:04 default INFO ember_csi.common [req-214deb9d-aa3d-44d4-8cb4-7ebadaabfffc] => GRPC Probe
2019-02-14 14:17:04 default INFO ember_csi.common [req-214deb9d-aa3d-44d4-8cb4-7ebadaabfffc] <= GRPC Probe served in 0s
2019-02-14 14:17:04 default INFO ember_csi.common [req-ef6256e9-4445-481a-b3e9-cdfa0e09a41a] => GRPC GetPluginInfo
2019-02-14 14:17:04 default INFO ember_csi.common [req-ef6256e9-4445-481a-b3e9-cdfa0e09a41a] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:17:04 default INFO ember_csi.common [req-3ecc4201-423f-4d98-b0c3-4dfedcc111ea] => GRPC GetPluginCapabilities
2019-02-14 14:17:04 default INFO ember_csi.common [req-3ecc4201-423f-4d98-b0c3-4dfedcc111ea] <= GRPC GetPluginCapabilities served in 0s
2019-02-14 14:17:04 default INFO ember_csi.common [req-de7aec08-b728-432d-be69-27a6ed59d668] => GRPC ControllerGetCapabilities
2019-02-14 14:17:04 default INFO ember_csi.common [req-de7aec08-b728-432d-be69-27a6ed59d668] <= GRPC ControllerGetCapabilities served in 0s
2019-02-14 14:19:49 default INFO ember_csi.common [req-cc8dbfe3-7d92-48b6-9fea-b19f4e635fae] => GRPC Probe
2019-02-14 14:19:49 default INFO ember_csi.common [req-cc8dbfe3-7d92-48b6-9fea-b19f4e635fae] <= GRPC Probe served in 0s
2019-02-14 14:21:19 default INFO ember_csi.common [req-6838a1e3-a7d5-4689-a71f-399a21930788] => GRPC Probe
2019-02-14 14:21:19 default INFO ember_csi.common [req-6838a1e3-a7d5-4689-a71f-399a21930788] <= GRPC Probe served in 0s
2019-02-14 14:22:49 default INFO ember_csi.common [req-212bb19e-3e0a-46ce-9a66-32eaca2c15e4] => GRPC Probe
2019-02-14 14:22:49 default INFO ember_csi.common [req-212bb19e-3e0a-46ce-9a66-32eaca2c15e4] <= GRPC Probe served in 0s
2019-02-14 14:24:19 default INFO ember_csi.common [req-cbb20af4-5eb6-4e1a-a8ea-0132022f8c48] => GRPC Probe
2019-02-14 14:24:19 default INFO ember_csi.common [req-cbb20af4-5eb6-4e1a-a8ea-0132022f8c48] <= GRPC Probe served in 0s


[vagrant@master ~]$ kubectl logs csi-rbd-0 -c csi-driver
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Ember CSI v0.0.2 with 30 workers (CSI spec: v1.0.0, cinderlib: v0.3.10.dev4, cinder: v13.1.0.dev902)
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Persistence module: CRDPersistence
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Running as controller with backend RBDDriver v1.2.0
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Debugging feature is ENABLED with ember_csi.rpdb and OFF. Toggle it with SIGUSR1.
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Supported filesystems: cramfs, minix, btrfs, ext2, ext3, ext4, xfs
2019-02-14 14:21:15 rbd INFO ember_csi.ember_csi [-] Now serving on unix:///csi-data/csi.sock...
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-f261da91-6b20-48a8-9a5c-26cd16b6ab13] => GRPC GetPluginInfo
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-f261da91-6b20-48a8-9a5c-26cd16b6ab13] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-503b6596-f408-4b91-94be-63557ef1ffa8] => GRPC GetPluginInfo
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-503b6596-f408-4b91-94be-63557ef1ffa8] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-4664c4d5-407e-4e78-91d2-ad2fef3c8176] => GRPC Probe
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-4664c4d5-407e-4e78-91d2-ad2fef3c8176] <= GRPC Probe served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-4fd5961f-884d-4029-936b-08e98bee41d9] => GRPC ControllerGetCapabilities
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-4fd5961f-884d-4029-936b-08e98bee41d9] <= GRPC ControllerGetCapabilities served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-fb6fbddf-e930-45f3-a476-d1a3212c7cfa] => GRPC Probe
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-fb6fbddf-e930-45f3-a476-d1a3212c7cfa] <= GRPC Probe served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-3f079fea-f519-401e-b3ff-c0355abf4176] => GRPC GetPluginInfo
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-3f079fea-f519-401e-b3ff-c0355abf4176] <= GRPC GetPluginInfo served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-7b0c6db7-e426-460a-beb6-0499becfe3ff] => GRPC GetPluginCapabilities
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-7b0c6db7-e426-460a-beb6-0499becfe3ff] <= GRPC GetPluginCapabilities served in 0s
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-84b46ba5-3b06-4f8d-8295-689795b7a9b9] => GRPC ControllerGetCapabilities
2019-02-14 14:21:16 rbd INFO ember_csi.common [req-84b46ba5-3b06-4f8d-8295-689795b7a9b9] <= GRPC ControllerGetCapabilities served in 0s
2019-02-14 14:24:11 rbd INFO ember_csi.common [req-74bf9abc-80b6-40ca-a032-ff761a389a2d] => GRPC Probe
2019-02-14 14:24:11 rbd INFO ember_csi.common [req-74bf9abc-80b6-40ca-a032-ff761a389a2d] <= GRPC Probe served in 0s
2019-02-14 14:25:41 rbd INFO ember_csi.common [req-a85e05d9-3c71-42f6-8c67-48ac7151667b] => GRPC Probe
2019-02-14 14:25:41 rbd INFO ember_csi.common [req-a85e05d9-3c71-42f6-8c67-48ac7151667b] <= GRPC Probe served in 0s
```

Now that we have confirmed that the deployment is working (there is no error on the *controller* logs) we will proceed to test the plugin.  Remember that we set our configuration in `ember_lvm_config`, so we'll have to use the manifests in the `kubeyml/lvm` directory.

First let's test the volume creation functionality:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/lvm/05-pvc.yml
persistentvolumeclaim/csi-pvc created
```

Check the PVC an PVs in Kubernetes:

```shell
[vagrant@master ~]$ kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
csi-pvc   Bound    pvc-7db8685b-3066-11e9-aed5-5254002dbb88   1Gi        RWO            csi-sc         9s


[vagrant@master ~]$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   REASON   AGE
pvc-7db8685b-3066-11e9-aed5-5254002dbb88   1Gi        RWO            Delete           Bound    default/csi-pvc   csi-sc                  14s
```

Now that the volume has been created we will try to create a pod that uses this volume:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/lvm/06-app.yml
pod/my-csi-app created
```

Tail the CSI *controller* plugin logs to see that the plugin exports the volume:

```shell
[vagrant@master ~]$ kubectl logs csi-controller-0 -fc csi-driver
2019-02-14 14:17:03 default INFO ember_csi.ember_csi [-] Ember CSI v0.0.2 with 30 workers (CSI spec: v1.0.0, cinderlib: v0.3.10.dev4, cinder: v13.1.0.dev902)


[ . . .]

2019-02-14 14:52:49 default INFO ember_csi.common [req-d135903b-f89a-4030-a085-5aa0ba3be2be] => GRPC Probe
2019-02-14 14:52:49 default INFO ember_csi.common [req-d135903b-f89a-4030-a085-5aa0ba3be2be] <= GRPC Probe served in 0s
2019-02-14 14:53:29 default INFO ember_csi.common [req-b5388936-239c-4285-896b-29a9e764caa7] => GRPC ControllerPublishVolume 540c5a37-ce98-4b47-83f7-10c54a4777b9
2019-02-14 14:53:31 default INFO ember_csi.common [req-b5388936-239c-4285-896b-29a9e764caa7] <= GRPC ControllerPublishVolume served in 2s
^C
```

Tail the CSI *node* plugin logs to see that the plugin actually attaches the volume to the container:

```shell
[vagrant@master ~]$ kubectl logs csi-node-qf4ld -fc csi-driver
2019-02-14 14:18:46 INFO ember_csi.ember_csi [-] Ember CSI v0.0.2 with 30 workers (CSI spec: v1.0.0, cinderlib: v0.3.10.dev4, cinder: v13.1.0.dev902)

[ . . . ]

2019-02-14 14:53:44 default INFO ember_csi.common [req-c9ed9f88-920a-432c-9bb3-d8562d21fadf] => GRPC Probe
2019-02-14 14:53:44 default INFO ember_csi.common [req-c9ed9f88-920a-432c-9bb3-d8562d21fadf] <= GRPC Probe served in 0s
2019-02-14 14:53:45 default INFO ember_csi.common [req-030e7f15-8f75-49d4-8cc6-3e7ec84698a3] => GRPC NodeGetCapabilities
2019-02-14 14:53:45 default INFO ember_csi.common [req-030e7f15-8f75-49d4-8cc6-3e7ec84698a3] <= GRPC NodeGetCapabilities served in 0s
2019-02-14 14:53:45 default INFO ember_csi.common [req-62b267b9-fcf7-48d1-a450-97519952af1c] => GRPC NodeStageVolume 540c5a37-ce98-4b47-83f7-10c54a4777b9
2019-02-14 14:53:47 default WARNING os_brick.initiator.connectors.iscsi [req-62b267b9-fcf7-48d1-a450-97519952af1c] iscsiadm stderr output when getting sessions: iscsiadm: No active sessions.

2019-02-14 14:53:50 default INFO ember_csi.common [req-62b267b9-fcf7-48d1-a450-97519952af1c] <= GRPC NodeStageVolume served in 5s
2019-02-14 14:53:50 default INFO ember_csi.common [req-8414718e-6f5a-4eed-84f0-29cbfca3657e] => GRPC NodeGetCapabilities
2019-02-14 14:53:50 default INFO ember_csi.common [req-8414718e-6f5a-4eed-84f0-29cbfca3657e] <= GRPC NodeGetCapabilities served in 0s
2019-02-14 14:53:50 default INFO ember_csi.common [req-ce8f5d78-b07b-45d0-9c4e-8c89defd5223] => GRPC NodePublishVolume 540c5a37-ce98-4b47-83f7-10c54a4777b9
2019-02-14 14:53:50 default INFO ember_csi.common [req-ce8f5d78-b07b-45d0-9c4e-8c89defd5223] <= GRPC NodePublishVolume served in 0s
2019-02-14 14:55:05 default INFO ember_csi.common [req-ba73aa46-6bb9-4b27-974a-aa2fa160b8ff] => GRPC Probe
2019-02-14 14:55:05 default INFO ember_csi.common [req-ba73aa46-6bb9-4b27-974a-aa2fa160b8ff] <= GRPC Probe served in 0s
^C
```

Check that the pod has been successfully created:

```shell
[vagrant@master ~]$ kubectl get pod my-csi-app
NAME         READY   STATUS    RESTARTS   AGE
my-csi-app   1/1     Running   0          3m16s
```

Let's now test the snapshot creation:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/lvm/07-snapshot.yml
volumesnapshot.snapshot.storage.k8s.io/csi-snap created


[vagrant@master ~]$ kubectl describe VolumeSnapshot
Name:         csi-snap
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  snapshot.storage.k8s.io/v1alpha1
Kind:         VolumeSnapshot
Metadata:
  Creation Timestamp:  2019-02-14T15:00:35Z
  Finalizers:
    snapshot.storage.kubernetes.io/volumesnapshot-protection
  Generation:        5
  Resource Version:  4723
  Self Link:         /apis/snapshot.storage.k8s.io/v1alpha1/namespaces/default/volumesnapshots/csi-snap
  UID:               488d1760-3069-11e9-aed5-5254002dbb88
Spec:
  Snapshot Class Name:    csi-snap
  Snapshot Content Name:  snapcontent-488d1760-3069-11e9-aed5-5254002dbb88
  Source:
    API Group:  <nil>
    Kind:       PersistentVolumeClaim
    Name:       csi-pvc
Status:
  Creation Time:  2019-02-14T15:00:35Z
  Ready To Use:   true
  Restore Size:   <nil>
Events:           <none>
```

Now create a volume from that snapshot:

```shell
[vagrant@master ~]$ kubectl create -f kubeyml/lvm/08-restore-snapshot.yml
persistentvolumeclaim/vol-from-snap created


[vagrant@master ~]$ kubectl get vol
NAME                                   AGE
540c5a37-ce98-4b47-83f7-10c54a4777b9   21m
faa72ced-43ef-45ac-9bfe-5781e15f75da   6s
```

We can now test the detach operation which is triggered when we destroy the container:

```shell
[vagrant@master ~]$ kubectl delete -f kubeyml/lvm/06-app.yml
pod "my-csi-app" deleted

[vagrant@master ~]$ kubectl get VolumeAttachment
No resources found.

[vagrant@master ~]$ kubectl get conn
No resources found.
```

And finally the deletion of resources, volumes and snapshot:

```shell
[vagrant@master ~]$ kubectl delete -f kubeyml/lvm/08-restore-snapshot.yml
[vagrant@master ~]$ kubectl delete -f kubeyml/lvm/07-snapshot.yml
[vagrant@master ~]$ kubectl delete -f kubeyml/lvm/05-pvc.yml

[vagrant@master ~]$ kubectl get pvc
No resources found.

[vagrant@master ~]$ kubectl get VolumeSnapshot
No resources found.
```

Hopefully everything went great and you were able to run all the above commands and validate your backend, but if you run into trouble, here are our troubleshooting recommendations:

- Double check the configuration.
- Carefully read returned error in case there is useful information.
- Enable debug logs and check `csi-driver` container logs in `csi-controller-0` and `csi-node-*`.
- Come to the [#ember-csi IRC channel on Freenode] and ask for assistance (you can directly ping geguileo).
- You can [create an issue] on the project's GitHub's repository.

We can enable debug logs by setting `ember_debug_logs` to `true` in the `global_vars.yml` file, bringing the deployment down with `./down.sh`, redeploying,

### Final notes

We understand that going through all these steps to validate a driver is a very inconvenient process, and we are working towards simplifying it by adding cinderlib functional tests to Cinder vendor CI jobs and adding documentation with configuration examples of the different backends that have been validated.

If you run into issues while going through any of the steps you can come by the [#ember-csi IRC channel on Freenode] and we'll be happy to assist you.  If you prefer, you can also [create an issue] on the project's GitHub's repository.

We would love to hear from you if you were able to successfully go through this process using a different backend.  Having the configuration you used, with sensitive data masked, and any additional dependencies would be really useful for the project and other users.  You can report this information on the [#ember-csi IRC channel on Freenode], [create an issue] providing your configuration and the `Dockerfile.custom` file contents asking us to update the project's docs and Docker files, or submit a PR with the changes to the docs and the `Dockerfile` and `Dockerfile-release` files.

Bringing down the deployment is as easy as running the `./down.sh` script.

[Cinder]: https://docs.openstack.org/cinder
[cinderlib]: https://docs.openstack.org/cinderlib
[OpenStack]: https://www.openstack.org
[PyPi]: https://pypi.org/project/cinderlib
[Ember-CSI Image]: https://hub.docker.com/r/embercsi/ember-csi
[Dockerfile]: https://github.com/embercsi/ember-csi/blob/master/Dockerfile#L34-L37
[Ember-CSI's Kubernetes example]: https://github.com/embercsi/ember-csi/tree/master/examples/k8s_v1.13-CSI_v1.0
[Container Storage Client]: https://github.com/rexray/gocsi/tree/master/csc
[#ember-csi IRC channel on Freenode]: https://kiwiirc.com/client/irc.freenode.net/ember-csi
[create an issue]: https://github.com/embercsi/ember-csi/issues/new
