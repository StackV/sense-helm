#!/bin/bash

helm template support . -s templates/postgres-volume.yaml -f ./values.yaml -f ./override-nautilus.yaml --set postgres.generatePVC=true | kubectl apply -f -
