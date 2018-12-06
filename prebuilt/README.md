# reference container image

In this directory, please find a prebuilt container image:

```
demo-admission-webhook.docker_save.tar.bz2
```

To load this into a container registry:

```
wget https://raw.githubusercontent.com/joetatrh/openshift-admission-controller-webhook-demo/master/prebuilt/demo-admission-webhook.docker_save.tar.bz2

bunzip2 demo-admission-webhook.docker_save.tar.bz2

docker load < demo-admission-webhook.docker_save.tar
```
