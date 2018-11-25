#!/bin/bash

. govars

echo downloading go binary
curl https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz | tar -xvz -C ${GOPATH} -f -

echo downloading dep
curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
