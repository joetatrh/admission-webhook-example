#!/bin/bash

echo deleting all demo-webhook resources
oc delete MutatingWebhookConfiguration,ValidatingWebhookConfiguration -l demo=demo-webhook
oc delete project demo-webhook
rm -rf ~/demo-webhook

echo re-creating project demo-webhook
oc new-project demo-webhook
oc label namespace demo-webhook demo=demo-webhook --overwrite
