#!/bin/bash

. govars

echo getting go dependencies
go get -d ./...

echo ensuring go dependencies
dep ensure -v
