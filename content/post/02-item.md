+++
description = "What are the differences between Cinder-CSI and Ember-CSI?  When should I use one or the other? Do they support the same drivers? These are the most common questions when looking at connecting Cinder supported storage to K8s/OpenShift, and this short article answers these and other related questions."
thumbnail = "images/02-post-thumb.jpg"
image = "images/02-post.jpg"
title = "Cinder-CSI vs Ember-CSI"
slug = "cinder_csi-ember_csi"
author = "Gorka Eguileor"
draft = false
hidesidebar = true
publishDate=2020-06-17T17:05:00+02:00
+++

Once people see that Ember-CSI uses the Cinder drivers, they immediately wonder what's the difference between the two CSI plugins, but there is no document that answers that question.  They can dig into the documentations of both projects to understand their architectures and come up with the answer, but it's somewhat painful.

In this article we aim to answer the most common questions that will come up when looking into Cinder supported drivers and how to connect them to Kubernetes and OpenShift.

### Cinder-CSI

To understand the Cinder-CSI plugin the first thing we need to understand is what is a Cloud Provider.

In general, a Cloud Provider, or Cloud Service Provider, is a company that provides IT services in the cloud, such as Infrastructure as a Service (IaaS), Software as a Service (SaaS) or Platform as a Service (PaaS), to businesses or individuals.

Some examples of Cloud Providers are IBM Cloud, Amazon Web Services (AWS), Microsoft Azure, Alibaba Cloud, etc.

Now, when we talk about Cloud Providers within the Kubernetes/OpenShift context, we are referring to the integration points between the container platform and the cloud providers that provides the underlying infrastructure used by the container cluster.  In other words, the piece of software that allows the container platform to talk to the underlying infrastructure where it has been deployed or were it is being deployed.

Some of these [Kubernetes/OpenShift Cloud Providers](https://kubernetes.io/docs/concepts/cluster-administration/cloud-providers) are tied to a specific company, like AWS is specific to Amazon, whereas others are OpenSource and can have different companies, or ourselves, providing the service, like OpenStack and oVirt.

And here is where we get to the part that we care about, because Cinder-CSI is a plugin that implements the [CSI spec][1]
 to enable dynamic provisioning and managing of PVs and PVCs in Kubernetes/OpenShift using an existing Cinder service when the container orchestrator is running inside OpenStack.

This means that we must have an OpenStack deployment and have our Kubernetes/OpenShift cluster running inside VMs provided by Nova (the OpenStack compute service) to be able to use Cinder-CSI.

We cannot use Cinder-CSI if Cinder is running as a stand-alone service or if our Kubernetes/OpenShift cluster is deployed side-by-side of our OpenStack deployment.

### Ember-CSI

Ember-CSI is a plugin that also implements the [CSI spec][1] and also uses the Cinder drivers, but it uses them directly instead of going through the Cinder API.

This means that Ember-CSI doesn't really run Cinder (Volume, API, and Scheduler services) or its required services (RabbitMQ, MariaDB) to talk to the storage arrays, it uses the Cinder driver code as if it were the Cinder Volume service itself, but instead of providing a RabbitMQ RPC system that is finally exposed via REST-API to the user, it provides a gRPC interface implementing the [CSI spec][1].

This makes the Ember-CSI plugin agnostic to the underlying Cloud Provider, and it can work with any of the existing Cloud Providers as well as on baremetal.  The requirement is that the controller pod, which is usually run on master nodes, has access to the storage management network (some drivers also require access to the storage data network), and the node pods, which run on compute nodes, must have access to the storage data network.

### Supported drivers

When it comes to storage drivers supported by these two CSI plugins, there are important differences that we must take into consideration.

On one hand we have Cinder-CSI, which uses the Cinder service itself, and therefore supports all the storage solutions supported by Cinder, regardless of whether the connection to the volumes is done by at the host level (iSCSI, FC) or by QEMU-KVM (RBD).

On the other hand, Ember-CSI currently has more limitations, and doesn't support all the Cinder drivers and some have some limitations.  For example NFS drivers are not supported and the RBD volumes cannot have all the Ceph features enabled at the moment (we use krbd to do the attachments).

### When to use them

The main factor when deciding whether to use Cinder-CSI or Ember-CSI is where we are deploying our Kubernetes/OpenShift cluster.

If it's going to be running on top of OpenStack, then we'll most likely want to use Cinder-CSI, but if we are running it on anything other than OpenStack, then we can't use Cinder-CSI, so we'll have to go with Ember-CSI.

There may be special cases where even though we are deploying our container orchestrator on top of OpenStack we sill prefer to use Ember-CSI.  For example if we want to use different arrays for OpenShift and OpenStack because the storage arrays are managed by different teams.

### Deployment

Now that you know the differences between these two CSI plugins, how can you test them?

#### Cinder-CSI

I have never deployed Cinder-CSI, so I cannot tell what's the best approach to use it.

In my head using [DevStack](https://docs.openstack.org/devstack/latest) with the [Cloud Provider OpenStack DevStack plugin](https://github.com/kubernetes/cloud-provider-openstack/tree/master/devstack) and then manually deploying [the manifests](https://github.com/kubernetes/cloud-provider-openstack/tree/master/manifests) should be the most straightforward approach and require the fewer resources.

Unfortunately, as far as I know, the plugin doesn't work correctly with CentOS/Fedora, maybe trying with Ubuntu will yield better results.

In light of these issues, probably running DevStack and then following [Kubernetes' article from February](https://kubernetes.io/blog/2020/02/07/deploying-external-openstack-cloud-provider-with-kubeadm/) will be the best option.

#### Ember-CSI

For Ember-CSI the recommended installation tool is the Ember-CSI operator that is [is available in the Kubernetes operator catalog](https://operatorhub.io/operator/ember-csi-operator) as well as the OpenShift embedded catalog.

![Ember-CSI in OpenShift Catalog](/images/02-post-catalog.png)

Installing the Kubernetes/OpenShift cluster is not part of the operator's responsibility, and we'll have to do that ourselves, for example using [Code Ready Containers (CRC)](https://developers.redhat.com/products/codeready-containers/overview).  We'll soon write a short article explaining how easy it is to get a working setup with CRC and Ember-CSI.

The main reason why it was decided to go with an Operator driven deployment instead of Helm Charts is the complexity of configuring the drivers.  Each driver has very different configuration options, and we have to know which options are needed for each driver.  In this situation a visual interface using a form is definitely a more intuitive and user friendly approach.

![Ember-CSI operator form](/images/02-post-driver-cfg.png)

This solution still supports automated deployments using YAML manifests to instruct the operator to do an Ember-CSI deployment.

### Summary

These two CSI plugins are aimed to completely different scenarios, and it's not about which one performs better or uses fewer resources, it's mostly about your Kubernetes/OpenShift deployment.

If you run Kubernetes/OpenShift on top of OpenStack, then use Cinder-CSI, otherwise use Ember-CSI.


[1]: https://github.com/container-storage-interface/spec
