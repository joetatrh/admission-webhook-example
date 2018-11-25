#!/bin/bash

. ocpvars

oc process \
  -p DOCKER_REGISTRY_SERVICE="${DOCKER_REGISTRY_SERVICE}" \
  -p CA_BUNDLE="${CA_BUNDLE}" \
  -f openshift-template-demo-webhook.yaml |
oc -n demo-webhook create -f -
