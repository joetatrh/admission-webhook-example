#!/bin/bash

. govars

echo building webhook code
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o demo-admission-webhook
