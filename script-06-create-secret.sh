#!/bin/bash

echo creating signed cert demo-webhook
./deployment/webhook-create-signed-cert.sh --service demo-webhook --namespace demo-webhook --secret demo-webhook-certs
oc label secret demo-webhook-certs demo=demo-webhook --overwrite -n demo-webhook
