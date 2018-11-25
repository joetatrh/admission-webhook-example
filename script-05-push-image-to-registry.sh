#!/bin/bash

. govars
. ocpvars

echo logging in to OCP-internal container registry
sudo podman login -u openshift -p ${OC_TOKEN} ${DOCKER_REGISTRY_ROUTE} --tls-verify=false

echo pushing image to OCP-internal container registry
sudo buildah push --tls-verify=false \
  ${DOCKER_REGISTRY_ROUTE}/demo-webhook/demo-admission-webhook:latest \
  docker://${DOCKER_REGISTRY_ROUTE}/demo-webhook/demo-admission-webhook:latest
