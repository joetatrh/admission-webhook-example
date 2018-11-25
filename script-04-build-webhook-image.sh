#!/bin/bash

. ocpvars

echo building webhook container image
sudo buildah build-using-dockerfile -t ${DOCKER_REGISTRY_ROUTE}/demo-webhook/demo-admission-webhook .
