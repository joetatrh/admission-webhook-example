# About this repo

This is a demonstration of OpenShift Container Platform's [admission controller webhooks](https://docs.openshift.com/container-platform/3.11/architecture/additional_concepts/dynamic_admission_controllers.html#architecture-additional-concepts-dynamic-admission-webhooks).

For every `service` and `deployment` created, this admission webhook replaces the object's labels with a known set (`component`, `instance`, `managed-by`, `name`, `part-of`, & `version`).

## Motivation

Although there exist several tutorials on _Kubernetes_ admission controller webhooks, there are few written specifically for **OpenShift**.

_This_ demo:
* Works out-of-the-box on OpenShift
  * You don't need to customize any examples from upstream Kubernetes or any other k8s distribution
* Covers the OpenShift implementation-specific config for enabling admission controller webhooks

## Tech Preview

As of OpenShift Container Platform 3.11, admission controller webhooks are still in Tech Preview status .

Until the feature achieves GA status, implementation details are subject to change, admission controller webhooks remain unsupported, and the feature could be dropped entirely in a future release.

## Acknowledgements

* This demo is forked from a Kubernetes-specific demo by Banzai Cloud:  
[Banzai Cloud: In-depth introduction to Kubernetes admission webhooks](https://banzaicloud.com/blog/k8s-admission-webhooks/) , with a [corresponding github repo](https://github.com/banzaicloud/admission-webhook-example).
* The Banzai Cloud article is based on an article by Morven Cao:  
[Morven Cao: Diving into Kubernetes MutatingAdmissionWebhook](https://medium.com/ibm-cloud/diving-into-kubernetes-mutatingadmissionwebhook-6ef3c5695f74), which also has a [corresponding github repo](https://github.com/morvencao/kube-mutating-webhook-tutorial).
* Since 1.9, the upstream Kubernetes ships with proof-of-concept code for this feature:  
https://github.com/kubernetes/kubernetes/tree/release-1.9/test/images/webhook

# Environment

`openshift-admission-controller-webhook-demo` has been tested on:
* OpenShift Container Platform `3.11.43`
  * on which your account has the `clusterrole` `cluster-admin`
  * where you can push container images to the OCP integrated registry
* with nodes
  * running Red Hat Enterprise Linux `7.5`
  * subscribed to the `rhel-7-server-extras-rpms` repository
  * on which you can become the `root` user and make changes at will

# Prerequisites

## Initial setup with `oc` client

In the coming steps-- even before we start creating objects inside the cluster-- we'll need to be logged into the OpenShift client.

Let's get that out of the way now.

### Log in

Log in to OpenShift:

```
oc login
```

... and ensure that your account has been assigned the `cluster-admin` `clusterrolebinding`.

If `oc auth` confirms that you can do any verb on any resource, then you're ready to go:

```
$ oc auth can-i '*' '*'
yes
```

#### Optional: Delete any API objects from a previous demo

If you've already started this demo once before, then delete any admission webhook configurations that might have been created in a previous run:

```
oc delete MutatingWebhookConfiguration,ValidatingWebhookConfiguration -l demo=demo-webhook
```

... and delete any `demo-webhook` project that already exists:

```
oc delete project demo-webhook
```

##### Script: Reset state from previous attempt

ALTERNATE: Rather than cleaning up a previous run by hand, you can use the below script.

This reset script removes **all** state (instantiated API objects and files in ~/demo-webhook) and recreates the `demo-webhook` project:

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-00-reset.sh
```

## Create the `demo-webhook` project

A project for the demo webhook must exist ahead of time, even before we try to create any objects inside it.

(We're going to start by pushing an image into the integrated registry, and we want this image to appear beneath the `demo-webhook` project.)

```
oc new-project demo-webhook
oc label namespace demo-webhook demo=demo-webhook --overwrite
```

## Identify a build host

Choose a host on which to perform this demo.

The host needn't be a member of any OpenShift cluster.  There are modest requirements to be able to build `go` apps from source and to assemble container images.

Any server with connectivity to the cluster-- and the ability to download from github and google-- will do.

We assume that a RHEL 7 server named `bastion` is available for this role.

## Install packaged dependencies

On the `bastion` host, install certain dependencies, including `buildah` (a replacement for `docker build` commands), `podman` (for `docker push`), and `skopeo` (to inspect metadata of remote images).

```
sudo yum -y install buildah podman skopeo atomic-openshift-clients git openssl
```

## Create directories and download this repo

We can't just clone this repo and put it anywhere we like.

We'll be building this demo (not just pulling binaries from somewhere), and because it's written in `go`, we'll need to arrange for a number of files to be placed exactly where `go` expects to find them.  This includes the contents of this repository.

On the `bastion` host, download the contents of this repository to the proper location:

```
mkdir -p ~/demo-webhook/src/github.com/joetatrh
cd ~/demo-webhook/src/github.com/joetatrh
git clone https://github.com/joetatrh/openshift-admission-controller-webhook-demo.git
```

### Restarting from a partial attempt

Because we'll be storing everything associated with this demo beneath `~/demo-webhook`, you can recover quickly if you need to start from scratch.

Do `rm -rf ~/demo-webhook` (and delete the `demo-webhook` project and other API objects) and you're back in business.

## Install `go` build dependencies

We need a couple of `go` binaries to build this demo.

Run the below script to install `dep` (a go dependency manager) and a newer version of `go` than that which is packaged for RHEL 7.

Both of these files are placed below `~/demo-webhook`.

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-01-go-binaries.sh
```

### Optional: Confirm that the new binaries exist

The newly-downloaded binaries should appear beneath `~/demo-webhook`.

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ . govars
$ which go dep
~/demo-webhook/go/bin/go
~/demo-webhook/go/bin/dep
$
```

## Satisfy build dependencies

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-02-go-deps.sh
```

# Build and push the demo admission webhook

In a later step, we'll create a webhook configuration that tells OpenShift to submit certain API objects to a running web server.

Said web server (the "admission webhook") will be running inside the OpenShift cluster itself.

This means that we need to compile that web server, package it in a container image, and make it available for use just like any other OpenShift-native application.

## Build the admission webhook from source

Build the demo admission webhook from source.

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-03-build-webhook-code.sh
```

### Optional: confirm that the webhook was built

When the webhook is built, you'll be left with a regular executable.

```
$ ls -lh demo-admission-webhook
-rwxrwxr-x. 1 jteagno-redhat.com jteagno-redhat.com 23M Nov 24 01:01 demo-admission-webhook
```

## Assemble the admission webhook into a container image

Build a container image from the just-compiled admission webhook.

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-04-build-webhook-image.sh
```

### Optional: confirm that the container image was built

If you'd like, feel free to verify that the new container image has been built.

```
$ sudo buildah images localhost/demo-admission-webhook:latest
IMAGE ID      IMAGE NAME                               CREATED AT          SIZE
2def0d38171e  localhost/demo-admission-webhook:latest  Nov 24, 2018 01:37  237 MB
```

## Push the container image to the OCP integrated image registry

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-05-push-image-to-registry.sh
```

### Optional: confirm that the image has been pushed to the registry

The `skopeo` utility can fetch metadata about your new image from the registry to which it was just pushed.

```
$ . ocpvars
$ skopeo inspect --tls-verify=false docker://${DOCKER_REGISTRY_ROUTE}/demo-webhook/demo-admission-webhook:latest
{
    "Name": "docker-registry-default.ocp.example.com/demo-webhook/demo-admission-webhook",
    ...
}
```

# Enable the Mutating and Validating AdmissionWebhook plugins

## Version check: OCP 3.11

This document was tested against OpenShift Container Platform `3.11.43`.

If you run into issues on OCP 3.10 or an earlier version of 3.11, see the below bug:

https://bugzilla.redhat.com/show_bug.cgi?id=1635918

You may need to work around a bug by adding `kubeConfigFile: /dev/null` into the configuration of your AdmissionWebhook plugins in your master config.

## Initial state: confirm that the AdmissionWebhooks are not enabled

Check the logs on each of the masters.

Before making any changes, the masters should confirm that the `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` admission plugins are not enabled.

(Recall that starting in OCP 3.10, you can read master logs with `/usr/local/bin/master-logs`.)

```
master1# /usr/local/bin/master-logs api api 2>&1 | grep "AdmissionWebhook is not enabled"

I1108 14:47:34.900987  1 register.go:151] Admission plugin MutatingAdmissionWebhook is not enabled.  It will not be started.
I1108 14:47:34.901358  1 register.go:151] Admission plugin ValidatingAdmissionWebhook is not enabled.  It will not be started.
```

## Add admission webhooks to master pluginConfigs

On **each** of the masters, modify the `/etc/origin/master/master-config.yaml` config file.

Add configuration for the `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` plugins.  The top of the `master-config.yaml` file should look like this:

```
# cat /etc/origin/master/master-config.yaml
admissionConfig:
  pluginConfig:
    MutatingAdmissionWebhook:
      configuration:
        apiVersion: v1
        disable: false
        kind: DefaultAdmissionConfig
    ValidatingAdmissionWebhook:
      configuration:
        apiVersion: v1
        disable: false
        kind: DefaultAdmissionConfig
    BuildDefaults:
     ... 
    BuildOverrides:
     ... 
    openshift.io/ImagePolicy:
     ... 
...
```

### Note on `master-config.yaml`

NOTE: In `master-config.yaml`, specify the configurations for the Mutating and Validating AdmissionWebhook plugins *_exactly_* as they appear above.

Notably, do _not_ include any other fields, such as a `location` field.

## Restart each master

After applying changes to `master-config.yaml`, restart the master API processes on **each** master.

```
/usr/local/bin/master-restart api
```

## Validate that the AdmissionWebhooks are enabled

Inspect the logs messages from each master.

You should now receive active confirmation that the new plugins are enabled.

__Do not proceed until you receive confirmation that admission webhooks are enabled.__

```
master1# /usr/local/bin/master-logs api api 2>&1 | grep -E "admission (plugin|controller).+AdmissionWebhook"

I1108 15:39:32.861200       1 plugins.go:84] Registered admission plugin "ValidatingAdmissionWebhook"
I1108 15:39:32.861207       1 plugins.go:84] Registered admission plugin "MutatingAdmissionWebhook"
I1108 15:39:33.736876       1 plugins.go:158] Loaded 1 mutating admission controller(s) successfully in the following order: MutatingAdmissionWebhook.
I1108 15:39:33.737481       1 plugins.go:161] Loaded 1 validating admission controller(s) successfully in the following order: ValidatingAdmissionWebhook.
```

### Validate that the admissionregistration API is enabled

```
$ oc api-versions | grep ^admissionregistration
admissionregistration.k8s.io/v1beta1
```

# Create the admission-webhook service

## Create the `demo-webhook` project

The `demo-webhook` project should already exist.  (In a previous step, we built a container image and pushed it into this project's space.)

If necessary, create the project to hold the webhook:

```
oc new-project demo-webhook
```

## Label the `demo-webhook` namespace

Apply the below `demo-webhook` label to the `demo-webhook` namespace.

The webhook configuration appearing in a future step only triggers on namespaces matching this label.

```
oc label namespace demo-webhook demo=demo-webhook --overwrite
```

### Optional: Confirm that the namespace has been labeled

```
$ oc get namespace -l demo=demo-webhook -o name
namespace/demo-webhook
```

## Create the service implementing the webhook server

### Create a secret required by the webhook server

Communication with the webhook needs to be encrypted.  For the purposes of this demo, put the OpenShift internal CA into a secret:

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-06-create-secret.sh
```

#### Optional: Confirm that the webhook secret exists

```
$ oc get secret -l demo=demo-webhook -o name
secret/demo-webhook-certs
$
```

### Create the objects that comprise the webhook

The webhook is composed of several objects: a deployment of the webhook binary, a service, and a webhook configuration telling OpenShift how and when to connect to the webhook.

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
./script-07-create-webhook.sh
```

#### Optional: Confirm that the webhook objects exist

```
$ oc -n demo-webhook get all -l demo=demo-webhook -o name
pod/demo-webhook-deployment-5c78d86f8c-bmlrf
service/demo-webhook-svc
deployment.apps/demo-webhook-deployment
replicaset.apps/demo-webhook-deployment-5c78d86f8c
$
```

#### The webhook config

The `MutatingWebhookConfiguration` is shown below; it's the most important part of setting up a webhook.

This configuration tells OpenShift under what circumstances it needs to submit objects to an admission webhook (the `rules`), and where to find and how to communicate with the webhook (`webhooks.clientConfig`), which happens to be a plain HTTP server.

```
apiVersion: admissionregistration.k8s.io/v1beta1
kind: MutatingWebhookConfiguration
metadata:
  labels:
    app: demo-webhook
    demo: demo-webhook
  name: demo-webhook-cfg
webhooks:
- clientConfig:
    caBundle: LS0tL...
    service:
      name: demo-webhook-svc
      namespace: demo-webhook
      path: /mutate
  failurePolicy: Ignore
  name: mutating-admission-demo-webhook.example.com
  namespaceSelector:
    matchLabels:
      demo: demo-webhook
  rules:
  - apiGroups:
    - apps
    - ""
    apiVersions:
    - v1
    operations:
    - CREATE
    resources:
    - deployments
    - services
```

# Test the mutating admission webhook

## Create a resource and inspect labels

### Inspect definition of new service

View the contents of the file `labeltest-demo-service-1.yaml`.

The only labels defined inside this object are `app` and `demo`.  And yet, when we instantiate this object in the cluster, the mutating webhook will add a set of labels to it.

```
$ cat labeltest-demo-service-1.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: labeltest-demo-service-1
    demo: demo-webhook
  name: labeltest-demo-service-1
spec:
  ...
$ 
```

### Create the new service

```
cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
oc create -f labeltest-demo-service-1.yaml
```

### Examine the labels on the newly-created service

Look at the labels on the newly-created service.  The webhook is working!

The new object carries a completely different set of labels from what the YAML file was supposed to create; these new labels were put in place by the mutating admission webhook.

```
$ oc -n demo-webhook get service labeltest-demo-service-1 --template='{{range $k, $v := .metadata.labels}}{{$k}}{{"\n"}}{{end}}'
app.kubernetes.io/component
app.kubernetes.io/instance
app.kubernetes.io/managed-by
app.kubernetes.io/name
app.kubernetes.io/part-of
app.kubernetes.io/version
$ 
```

## Disable webhook and inspect labels on another new resource

### Disable the webhook

Time to test.  We remove the configuration that causes our new webhook to be called and make sure that the labels on new services are not modified.

```
$ # save a copy of the webhook config for a later step
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ oc get MutatingWebhookConfiguration demo-webhook-cfg -o yaml > demo-webhook-cfg.yaml

$ oc delete MutatingWebhookConfiguration demo-webhook-cfg
mutatingwebhookconfiguration.admissionregistration.k8s.io "demo-webhook-cfg" deleted
$
```

### Create another service while the webhook is disabled

Before we create another service, notice that the service defined inside the file carries the same two labels as last time, `app` and `demo`.

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ cat labeltest-demo-service-2.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: labeltest-demo-service-2
    demo: demo-webhook
  name: labeltest-demo-service-2
spec:
  ...
$ 
```

Success!  When the webhook configuration is absent, the service is not mutated.  Its labels are not changed.

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ oc create -f labeltest-demo-service-2.yaml
service/labeltest-demo-service-2 created
$ 

$ oc -n demo-webhook get service labeltest-demo-service-2 --template='{{range $k, $v := .metadata.labels}}{{$k}}{{"\n"}}{{end}}'
app
demo
$
```

## Re-enable webhook and confirm labels reappear

### Recreate the webhook configuration

To re-activate the webhook, recreate the webhook configuration that we saved in an earlier step.

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ oc create -f demo-webhook-cfg.yaml
mutatingwebhookconfiguration.admissionregistration.k8s.io/demo-webhook-cfg created
$
```

### Create another service

We'll create one last service.  As before, this service's definition specifies only two labels, `app` and `demo`.

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ cat labeltest-demo-service-3.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: labeltest-demo-service-3
    demo: demo-webhook
  name: labeltest-demo-service-3
spec:
  ...
$ 
```

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ oc -n demo-webhook create -f labeltest-demo-service-3.yaml
service/labeltest-demo-service-3 created
```

### Validate that new labels appear on instantiated service

```
$ cd ~/demo-webhook/src/github.com/joetatrh/openshift-admission-controller-webhook-demo/
$ oc -n demo-webhook get service labeltest-demo-service-3 -o yaml --export
apiVersion: v1
kind: Service
metadata:
  ...
  labels:
    app.kubernetes.io/component: not_available
    app.kubernetes.io/instance: not_available
    app.kubernetes.io/managed-by: not_available
    app.kubernetes.io/name: not_available
    app.kubernetes.io/part-of: not_available
    app.kubernetes.io/version: not_available
...
```
