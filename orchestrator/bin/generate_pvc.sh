#!/bin/bash

helm template stackv . -s templates/mysql-volume.yaml -f ./values.yaml -f ./override-nautilus.yaml --set mysql.generatePVC=true | kubectl apply -f -
